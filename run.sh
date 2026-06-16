#!/bin/bash

DEVICE=""
LOG=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--device)
      DEVICE="$2"
      shift 2
      ;;
    -l|--log)
      LOG=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ -n "$DEVICE" ]; then
  TARGET=$(xcrun simctl list devices | grep -i "$DEVICE" | grep -v unavailable | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
  if [ -z "$TARGET" ]; then
    echo "No simulator found matching '$DEVICE'"
    exit 1
  fi
  xcrun simctl boot "$TARGET" 2>/dev/null
  open -a Simulator
  xcrun simctl bootstatus "$TARGET" -b
else
  TARGET="booted"
fi

xcrun simctl uninstall "$TARGET" com.netpress.NextCaltrain
# A bare glob here isn't guaranteed to pick the build .sh just produced — if more
# than one NextCaltrain-* DerivedData folder exists (easy to end up with, since
# xcodegen regenerates the project), glob expansion has no notion of "newest" and
# can silently install a stale .app. `ls -t` picks the most recently built one.
APP_PATH=$(ls -dt ~/Library/Developer/Xcode/DerivedData/NextCaltrain-*/Build/Products/Debug-iphonesimulator/NextCaltrain.app 2>/dev/null | head -1)
xcrun simctl install "$TARGET" "$APP_PATH"
xcrun simctl launch "$TARGET" com.netpress.NextCaltrain

if [ "$LOG" = true ]; then
   xcrun simctl spawn "$TARGET" log stream \
    --level debug \
    --style compact \
    --predicate 'composedMessage CONTAINS "[GoodTimes]" OR composedMessage CONTAINS "[TripViewModel]" OR composedMessage CONTAINS "[Schedule]" OR composedMessage CONTAINS "[TripList]"'
fi
