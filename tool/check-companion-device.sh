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
  android shell dumpsys window windows > "$artifacts/$view-window.txt"
  grep -A 25 'Sodukromental companion' "$artifacts/$view-window.txt" |
    grep -E 'APPLICATION_OVERLAY|ty=2038'
  android exec-out screencap -p > "$artifacts/$view.png"
}
capture_overlay launcher
for category in APP_CALCULATOR APP_CONTACTS; do
  component=$(android shell cmd package resolve-activity --brief -a android.intent.action.MAIN \
    -c "android.intent.category.$category" | tr -d '\r' | tail -1)
  if [[ "$component" == */* ]]; then break; fi
done
[[ "$component" == */* ]]
android shell am start -W -a android.intent.action.MAIN -n "$component"
capture_overlay other-app
android shell input keyevent KEYCODE_HOME
android shell dumpsys notification > "$artifacts/notification.txt"
grep -F 'companion_roaming' "$artifacts/notification.txt"
android shell cmd statusbar expand-notifications
sleep 2
android shell uiautomator dump /data/local/tmp/companion-shade.xml
android exec-out cat /data/local/tmp/companion-shade.xml > "$artifacts/notification-shade.xml"
read -r stop_x stop_y < <(python3 - "$artifacts/notification-shade.xml" <<'PY'
import re
import sys
from xml.etree import ElementTree

for node in ElementTree.parse(sys.argv[1]).iter('node'):
    if 'Stop roaming' in (node.get('text'), node.get('content-desc')):
        x1, y1, x2, y2 = map(int, re.findall(r'\d+', node.get('bounds', '')))
        print((x1 + x2) // 2, (y1 + y2) // 2)
        break
else:
    raise SystemExit('Stop roaming was not visible in the Android notification shade.')
PY
)
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
