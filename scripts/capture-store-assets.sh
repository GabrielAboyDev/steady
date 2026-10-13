#!/usr/bin/env bash
#
# Captures the App Store listing's raw material from the shipping build:
# screenshots at each size Apple asks for, and a screen recording of a
# scripted demo to cut the app preview from.
#
# Most of it is Steady running as a real system keyboard inside Messages,
# because that is where the app is actually used — the container app only
# contributes its settings screen. That means the simulator needs the keyboard
# enabled system-wide, and the Simulator app open: a custom keyboard never
# appears while the simulator thinks a hardware keyboard is attached.
#
#   scripts/capture-store-assets.sh                      # both sizes
#   scripts/capture-store-assets.sh "iPhone 17 Pro Max"  # just one
#
# Output: store/raw/<device>/*.png and store/raw/<device>/preview.mov
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
RUNNER_ID="com.gabrielaboy.steady.uitests.xctrunner"

# 6.9" iPhone (1320x2868) and 13" iPad (2064x2752) are the two sizes App Store
# Connect requires for an app that ships on both; every other size is derived
# from them.
DEVICES=("iPhone 17 Pro Max" "iPad Pro 13-inch (M5)")
if [ $# -gt 0 ]; then DEVICES=("$@"); fi

udid_for() {
  xcrun simctl list devices available --json \
    | python3 -c "
import json, sys
name = sys.argv[1]
devices = json.load(sys.stdin)['devices']
for runtime, entries in devices.items():
    if 'iOS' not in runtime:
        continue
    for device in entries:
        if device.get('isAvailable') and device['name'] == name:
            print(device['udid'])
            sys.exit()
sys.exit('no available simulator named %r' % name)
" "$1"
}

for device in "${DEVICES[@]}"; do
  udid="$(udid_for "$device")"
  slug="$(echo "$device" | tr ' ' '-' | tr -d '()')"
  out="$ROOT/store/raw/$slug"
  echo "==> $device ($udid)"

  rm -rf "$out"
  mkdir -p "$out"

  # Enables the keyboard system-wide and turns the hardware keyboard off.
  # Boots the device as a side effect.
  scripts/enable-keyboard-in-simulator.sh "$udid" >/dev/null

  # The hardware-keyboard preference is read by the Simulator app, so it has
  # to be running or no software keyboard ever appears in a host app.
  open -a Simulator --args -CurrentDeviceUDID "$udid"
  sleep 8

  # The listing's status bar, not whatever the simulator felt like showing.
  # The clock matches the host's, so it agrees with the timestamps Messages
  # stamps on the bubbles in the same frames.
  xcrun simctl status_bar "$udid" override \
    --time "$(date +%-I:%M)" \
    --batteryState discharging --batteryLevel 100 \
    --cellularMode active --cellularBars 4 \
    --wifiMode active --wifiBars 3 \
    --operatorName ""

  xcodebuild build-for-testing \
    -project Steady.xcodeproj \
    -scheme Steady \
    -destination "platform=iOS Simulator,id=$udid" \
    -derivedDataPath build/DerivedData \
    -quiet

  # The test writes into the runner's own container; bring whatever it managed
  # to write back out, including the diagnostics a failed run leaves behind.
  collect() {
    container="$(xcrun simctl get_app_container "$udid" "$RUNNER_ID" data 2>/dev/null)" || return 0
    cp "$container/Documents/StoreCapture/"* "$out/" 2>/dev/null || true
  }

  run_test() {
    TEST_RUNNER_STEADY_CAPTURE=1 xcodebuild test-without-building \
      -project Steady.xcodeproj \
      -scheme Steady \
      -destination "platform=iOS Simulator,id=$udid" \
      -derivedDataPath build/DerivedData \
      -resultBundlePath "$out/$2.xcresult" \
      -only-testing:"SteadyUITests/$1" \
      >"$out/$2.log" 2>&1 \
      || {
        collect
        echo "    $1 failed — see $out/$2.log"
        grep -E "error:" "$out/$2.log" | head -5
        exit 1
      }
  }

  echo "    screenshots — keyboard in Messages"
  rm -rf "$out/messages.xcresult"
  run_test StoreMessagesCaptureTests/testCaptureTextingScreenshots messages
  collect

  echo "    screenshots — settings"
  rm -rf "$out/screenshots.xcresult"
  run_test StoreCaptureTests/testCaptureScreenshots screenshots
  collect

  echo "    preview recording"
  rm -rf "$out/preview.xcresult"
  xcrun simctl io "$udid" recordVideo --codec h264 --force "$out/preview.mov" &
  recorder=$!
  # simctl only finalises the file on SIGINT, so make sure it always gets one.
  trap 'kill -INT "$recorder" 2>/dev/null || true' EXIT
  sleep 2
  run_test StoreMessagesCaptureTests/testPerformTextingPreviewTake preview
  sleep 1
  kill -INT "$recorder" 2>/dev/null || true
  wait "$recorder" 2>/dev/null || true
  trap - EXIT

  python3 - "$out" <<'PY'
import glob, os, subprocess, sys
out = sys.argv[1]
for path in sorted(glob.glob(os.path.join(out, "*.png"))):
    size = subprocess.run(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", path],
        capture_output=True, text=True).stdout.split()
    print("   ", os.path.basename(path), size[-3], "x", size[-1])
PY
  ls -lh "$out/preview.mov" 2>/dev/null | awk '{print "    preview.mov", $5}'
done

echo
echo "Raw capture done. Compose the listing with: scripts/build-store-assets.py"
