#!/usr/bin/env bash
set -euo pipefail

capture_failure() {
  local status=$?
  if (( status != 0 )); then
    mkdir -p android-diagnostics
    adb logcat -d > android-diagnostics/logcat.txt || true
    adb exec-out screencap -p > android-diagnostics/screenshot.png || true
  fi
}
trap capture_failure EXIT

if (( $# == 0 )); then
  flutter test --no-pub -d emulator-5554 integration_test/debug_smoke_test.dart
  # Flutter removes the instrumented package after a device test. Restore its
  # package identity before applying the separate companion fixture's grants.
  adb install -r build/app/outputs/flutter-apk/app-debug.apk
  bash tool/check-companion-device.sh emulator-5554
else
  apk="$1"
  package=org.sodukromental.debug
  component="$package/org.sodukromental.MainActivity"
  adb install -r "$apk"
  adb shell am start -W -n "$component"
  # Give the runtime a moment to surface launch-time failures before checking activity and process.
  sleep 3
  adb shell pidof "$package"
  activity="$(adb shell dumpsys activity activities)"
  grep -E 'topResumedActivity|mResumedActivity' <<< "$activity" | grep -F "$component"
  adb exec-out screencap -p > "$(dirname "$apk")/launched.png"
  if (( $# == 2 )); then
    python3 tool/check-debug-upgrade.py emulator-5554 "$2"
  fi
fi
