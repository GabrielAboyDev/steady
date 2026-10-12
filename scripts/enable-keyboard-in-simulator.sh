#!/bin/bash
# Enables the Steady keyboard system-wide on a simulator, the way a user would
# in Settings › General › Keyboard › Keyboards › Add New Keyboard.
#
# Needed because a keyboard extension can only be exercised in a host app once
# it's enabled, and that Settings path can't be scripted. Also turns off the
# hardware keyboard (otherwise no software keyboard ever appears) and suppresses
# the system keyboard's one-time slide-to-type tutorial, which blocks the screen.
#
# Usage: scripts/enable-keyboard-in-simulator.sh [device-udid]
set -euo pipefail

KEYBOARD_ID="com.gabrielaboy.steady.keyboard"
DEVICE="${1:-$(xcrun simctl list devices booted -j | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; print(next(x["udid"] for v in d.values() for x in v))')}"

echo "Device: $DEVICE"

# Boot once before touching preferences. A simulator that has never run writes
# its own defaults on first boot, which would otherwise clobber our edit and
# leave the keyboard silently disabled.
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" >/dev/null

# Now edit with the device down, so cfprefsd can't overwrite what we write.
xcrun simctl shutdown "$DEVICE" 2>/dev/null || true
sleep 2

PREFS="$HOME/Library/Developer/CoreSimulator/Devices/$DEVICE/data/Library/Preferences/.GlobalPreferences.plist"
if [ ! -f "$PREFS" ]; then
  echo "error: no preferences at $PREFS" >&2
  exit 1
fi

if ! /usr/libexec/PlistBuddy -c "Print :AppleKeyboards" "$PREFS" | grep -q "$KEYBOARD_ID"; then
  /usr/libexec/PlistBuddy -c "Add :AppleKeyboards: string $KEYBOARD_ID" "$PREFS"
  echo "Added $KEYBOARD_ID to the keyboard list"
else
  echo "$KEYBOARD_ID already in the keyboard list"
fi

for key in DidShowContinuousPathIntroduction KeyboardDidShowProductivityTutorial \
           DidShowGestureKeyboardIntroduction KeyboardDidShowGestureKeyboardIntroduction; do
  /usr/libexec/PlistBuddy -c "Delete :$key" "$PREFS" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :$key bool true" "$PREFS"
done
echo "Suppressed system keyboard intro screens"

# This one is a host preference owned by Simulator.app, so it has to go through
# `defaults` rather than editing the plist: cfprefsd caches the file and will
# happily overwrite a direct edit, leaving the hardware keyboard connected and
# no software keyboard ever appearing.
defaults write com.apple.iphonesimulator DevicePreferences -dict-add "$DEVICE" \
  '{ConnectHardwareKeyboard = 0;}'
echo "Disabled hardware keyboard"

xcrun simctl boot "$DEVICE"
xcrun simctl bootstatus "$DEVICE" >/dev/null

# Confirm it actually stuck. Without this the script can report success while
# the first boot quietly reverts the keyboard list, and the extension test then
# skips itself instead of failing — a green build that verified nothing.
if xcrun simctl spawn "$DEVICE" defaults read .GlobalPreferences AppleKeyboards 2>/dev/null | grep -q "$KEYBOARD_ID"; then
  echo "Verified: Steady is enabled. Reach it with the globe key."
else
  echo "error: $KEYBOARD_ID is not in the enabled keyboard list after boot" >&2
  xcrun simctl spawn "$DEVICE" defaults read .GlobalPreferences AppleKeyboards >&2 || true
  exit 1
fi
