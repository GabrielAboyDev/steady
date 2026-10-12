#!/bin/bash
# Enables the Steady keyboard system-wide on a simulator, the way a user would
# in Settings › General › Keyboard › Keyboards › Add New Keyboard.
#
# Needed because a keyboard extension can only be exercised in a host app once
# it's enabled, and the Settings path can't be scripted. Also turns off the
# hardware keyboard (otherwise no software keyboard appears) and suppresses the
# system keyboard's one-time slide-to-type tutorial.
#
# Usage: scripts/enable-keyboard-in-simulator.sh [device-udid]
set -euo pipefail

KEYBOARD_ID="com.gabrielaboy.steady.keyboard"
DEVICE="${1:-$(xcrun simctl list devices booted -j | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; print(next(x["udid"] for v in d.values() for x in v))')}"

echo "Device: $DEVICE"
xcrun simctl shutdown "$DEVICE" 2>/dev/null || true
sleep 2

PREFS="$HOME/Library/Developer/CoreSimulator/Devices/$DEVICE/data/Library/Preferences/.GlobalPreferences.plist"

if ! /usr/libexec/PlistBuddy -c "Print :AppleKeyboards" "$PREFS" | grep -q "$KEYBOARD_ID"; then
  /usr/libexec/PlistBuddy -c "Add :AppleKeyboards: string $KEYBOARD_ID" "$PREFS"
  echo "Enabled $KEYBOARD_ID"
else
  echo "$KEYBOARD_ID already enabled"
fi

for key in DidShowContinuousPathIntroduction KeyboardDidShowProductivityTutorial \
           DidShowGestureKeyboardIntroduction KeyboardDidShowGestureKeyboardIntroduction; do
  /usr/libexec/PlistBuddy -c "Delete :$key" "$PREFS" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :$key bool true" "$PREFS"
done
echo "Suppressed system keyboard intro screens"

SIMPREFS="$HOME/Library/Preferences/com.apple.iphonesimulator.plist"
/usr/libexec/PlistBuddy -c "Delete :DevicePreferences:$DEVICE:ConnectHardwareKeyboard" "$SIMPREFS" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :DevicePreferences:$DEVICE:ConnectHardwareKeyboard bool false" "$SIMPREFS"
echo "Disabled hardware keyboard"

xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" >/dev/null
echo "Booted. Steady is now available via the globe key."
