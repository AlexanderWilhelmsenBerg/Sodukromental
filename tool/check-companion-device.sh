#!/usr/bin/env bash
set -euo pipefail

device="${1:?Pass an Android emulator serial}"
shift
if [[ "$device" != emulator-* ]]; then
  echo 'The companion permission fixture requires a disposable emulator.' >&2
  exit 2
fi

target=org.sodukromental.debug
activity="$target/org.sodukromental.MainActivity"
android() { adb -s "$device" "$@"; }
android shell pm path "$target" | grep -q '^package:'
sdk=$(android shell getprop ro.build.version.sdk | tr -d '\r')
android shell appops set "$target" SYSTEM_ALERT_WINDOW allow
if (( sdk >= 33 )); then
  android shell pm grant "$target" android.permission.POST_NOTIFICATIONS
fi

artifacts="${SODU_DEVICE_ARTIFACTS:-android-diagnostics/companion}"
mkdir -p "$artifacts"

cleanup() {
  local code=$?
  if [[ -n "${fixture_pid:-}" ]]; then kill "$fixture_pid" 2>/dev/null || true; fi
  if (( code != 0 )); then
    if [[ -f "$artifacts/companion-device.log" ]]; then tail -45 "$artifacts/companion-device.log"; fi
    android logcat -d > "$artifacts/logcat.txt" || true
    android exec-out screencap -p > "$artifacts/failure.png" || true
  fi
  android shell appops set "$target" SYSTEM_ALERT_WINDOW default || true
  if (( sdk >= 33 )); then
    android shell pm revoke "$target" android.permission.POST_NOTIFICATIONS || true
  fi
}
trap cleanup EXIT

run_test() {
  flutter test --no-pub -d "$device" integration_test/companion_device_test.dart \
    --dart-define=SODU_RUN_OVERLAY_DEVICE=true "$@"
}

if [[ "${1:-}" != '--lifecycle' ]]; then
  run_test
  exit
fi

# Full lifecycle checks use the test's real native service. No release code
# receives these fixture flags or the emulator's preconfigured grants.
logs="$artifacts/companion-device.log"
# The integration-test binding forwards debugPrint to the host test reporter.
# These stage messages do not go to logcat on a hosted Android emulator.
run_test --dart-define=SODU_OVERLAY_EXTERNAL=true --reporter expanded > "$logs" 2>&1 &
fixture_pid=$!

stage() {
  local marker="SODU_COMPANION_READY: $1"
  for (( attempt = 0; attempt < 300; attempt++ )); do
    if grep -Fq "$marker" "$logs"; then return; fi
    if ! kill -0 "$fixture_pid" 2>/dev/null; then
      wait "$fixture_pid"
      echo "The device test exited before $marker." >&2
      return 1
    fi
    sleep 1
  done
  echo "Timed out waiting for $marker." >&2
  return 1
}

stage launcher-and-notification
android shell input keyevent KEYCODE_HOME
sleep 2
capture_overlay() {
  local view=$1
  for (( attempt = 0; attempt < 10; attempt++ )); do
    android shell dumpsys window windows > "$artifacts/$view-window.txt"
    if awk '
      /Window #[0-9]+ Window\{/ { companion = /Sodukromental companion/ }
      companion && /ty=(APPLICATION_OVERLAY|2038)/ { overlay = 1 }
      companion && /isOnScreen=true/ { visible = 1 }
      END { exit !(overlay && visible) }
    ' "$artifacts/$view-window.txt"; then
      android exec-out screencap -p > "$artifacts/$view.png"
      return
    fi
    sleep 1
  done
  echo "Android did not show the companion over $view." >&2
  return 1
}
capture_overlay launcher
for category in APP_CALCULATOR APP_CONTACTS; do
  component=$(android shell cmd package resolve-activity --brief -a android.intent.action.MAIN \
    -c "android.intent.category.$category" | tr -d '\r' | tail -1)
  if [[ "$component" == */* ]]; then break; fi
done
[[ "$component" == */* ]]
if (( sdk >= 33 )); then
  # Keep the fixture on the other app's ordinary surface. Android deliberately
  # hides overlays above first-launch permission dialogs.
  android shell pm grant "${component%%/*}" android.permission.POST_NOTIFICATIONS 2>/dev/null || true
fi
android shell am start -W -a android.intent.action.MAIN -n "$component"
capture_overlay other-app
android shell input keyevent KEYCODE_HOME
android shell dumpsys notification > "$artifacts/notification.txt"
grep -F 'companion_roaming' "$artifacts/notification.txt"
android shell cmd statusbar expand-notifications
sleep 2
capture_shade() {
  android shell uiautomator dump /data/local/tmp/companion-shade.xml
  android exec-out cat /data/local/tmp/companion-shade.xml > "$1"
}

notification_point() {
  python3 - "$1" "$2" <<'PY'
import re
import sys
from xml.etree import ElementTree

path, action = sys.argv[1:]
root = ElementTree.parse(path).getroot()

def labels(node):
    return (node.get('text', '').strip().casefold(),
            node.get('content-desc', '').strip().casefold())

def show_point(node):
    match = re.fullmatch(r'\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', node.get('bounds', ''))
    if not match:
        return False
    x1, y1, x2, y2 = map(int, match.groups())
    if x2 <= x1 or y2 <= y1:
        return False
    print((x1 + x2) // 2, (y1 + y2) // 2)
    return True

if action == 'stop':
    for node in root.iter('node'):
        if 'stop roaming' in labels(node) and show_point(node):
            sys.exit(0)
else:
    parents = {child: parent for parent in root.iter() for child in parent}
    for title in root.iter('node'):
        if not any(label.endswith(' is roaming') for label in labels(title)):
            continue
        ancestor = parents.get(title)
        while ancestor is not None:
            if ancestor.get('resource-id', '').endswith('/notification_stack_scroller'):
                break
            for node in ancestor.iter('node'):
                resource = node.get('resource-id', '').rsplit('/', 1)[-1]
                accessible_expand = any(label == 'expand' or label.startswith('expand notification')
                                        for label in labels(node))
                if (resource == 'expand_button' or accessible_expand) and show_point(node):
                    sys.exit(0)
            ancestor = parents.get(ancestor)

sys.exit(1)
PY
}

shade="$artifacts/notification-shade.xml"
capture_shade "$shade"
if ! stop_point="$(notification_point "$shade" stop)"; then
  if ! expand_point="$(notification_point "$shade" expand)"; then
    echo 'The companion notification has no visible Stop roaming or Expand action.' >&2
    exit 1
  fi
  read -r expand_x expand_y <<< "$expand_point"
  android shell input tap "$expand_x" "$expand_y"
  sleep 2
  shade="$artifacts/notification-shade-expanded.xml"
  capture_shade "$shade"
  if ! stop_point="$(notification_point "$shade" stop)"; then
    echo 'Stop roaming was not visible after expanding the companion notification.' >&2
    exit 1
  fi
fi
read -r stop_x stop_y <<< "$stop_point"
android shell input tap "$stop_x" "$stop_y"
android shell cmd statusbar collapse
android shell am start -W --activity-single-top -n "$activity"

stage lock
android shell input keyevent KEYCODE_SLEEP
sleep 2
android shell input keyevent KEYCODE_WAKEUP
android shell wm dismiss-keyguard
android shell am start -W --activity-single-top -n "$activity"

stage revoke
android shell appops set "$target" SYSTEM_ALERT_WINDOW deny
wait "$fixture_pid"
fixture_pid=''
