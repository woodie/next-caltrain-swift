#!/bin/bash
# Usage: ./snap.sh [filename]
#   filename   optional output name, saved under ~/Downloads (default: snap-<timestamp>.png)
# Usage: ./snap.sh -dark | -light
#   -dark      switch device to dark mode and exit (no screenshot)
#   -light     switch device to light mode and exit (no screenshot)
#
# Targets a connected physical iOS device if one is attached, otherwise falls
# back to a booted Simulator. Requires:
#   brew install libimobiledevice   (idevice_id, idevicescreenshot — for a real device)
#   Xcode command line tools        (xcrun simctl — for the Simulator)
#
# Note: -dark/-light only works against the Simulator. iOS has no public
# command-line API to toggle Dark Mode on a physical device — switch it
# manually (Settings > Display & Brightness, or Control Center).

DEST_DIR=~/Downloads

NAME="$1"

REAL_DEVICE_COUNT=$(idevice_id -l 2>/dev/null | wc -l | tr -d ' ')
SIM_BOOTED_COUNT=$(xcrun simctl list devices 2>/dev/null | grep -c "(Booted)")

if [ "$REAL_DEVICE_COUNT" -eq 0 ] && [ "$SIM_BOOTED_COUNT" -eq 0 ]; then
  echo "No physical device attached and no booted simulator found."
  exit 1
elif [ "$REAL_DEVICE_COUNT" -gt 1 ]; then
  echo "More than one physical device attached — disconnect one or target a specific UDID:"
  idevice_id -l
  exit 1
fi

USE_REAL_DEVICE=0
if [ "$REAL_DEVICE_COUNT" -eq 1 ]; then
  USE_REAL_DEVICE=1
fi

if [ "$NAME" = "-dark" ] || [ "$NAME" = "-light" ]; then
  MODE="dark"
  [ "$NAME" = "-light" ] && MODE="light"

  if [ "$USE_REAL_DEVICE" -eq 1 ]; then
    echo "Dark/light mode can't be switched via command line on a physical device."
    echo "Switch manually: Settings > Display & Brightness, or Control Center (long-press the brightness slider)."
    exit 1
  fi

  xcrun simctl ui booted appearance "$MODE"
  echo "Switched simulator to $MODE mode"
  exit 0
fi

if [ -z "$NAME" ]; then
  NAME="snap-$(date +%Y%m%d-%H%M%S).png"
fi
OUT="$DEST_DIR/$NAME"

if [ "$USE_REAL_DEVICE" -eq 1 ]; then
  idevicescreenshot "$OUT" >/dev/null
else
  xcrun simctl io booted screenshot "$OUT"
fi

if [ -s "$OUT" ]; then
  echo "Saved screenshot to $OUT"
else
  echo "Screenshot failed (empty file) — is the screen on and unlocked?"
  rm -f "$OUT"
  exit 1
fi
