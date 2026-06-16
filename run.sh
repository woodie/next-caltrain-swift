#!/bin/bash

# Schedule endpoint resolution, highest priority first:
#   1. local.env (gitignored) — per-developer override, e.g. to point at a local
#      hang/instant-fail test server. Never committed.
#   2. schedule-endpoint.env (committed) — the real production URL. If the schedule
#      data ever moves to a new home, edit and commit this file directly.
# See docs/CLAUDE.md "Schedule data pipeline".
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/schedule-endpoint.env" ]; then
  source "$SCRIPT_DIR/schedule-endpoint.env"
fi
if [ -f "$SCRIPT_DIR/local.env" ]; then
  source "$SCRIPT_DIR/local.env"
fi
if [ -n "$SCHEDULE_URL" ]; then
  export SIMCTL_CHILD_SCHEDULE_URL="$SCHEDULE_URL"
  echo "Using schedule endpoint: $SCHEDULE_URL"
fi

DEVICE=""
LOG=false
FRESH=false

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
    -f|--fresh)
      FRESH=true
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

if [ "$FRESH" = true ]; then
  # Full wipe: removes the app's entire data container (cache, UserDefaults).
  xcrun simctl uninstall "$TARGET" com.netpress.NextCaltrain
else
  # Default: force a cold relaunch but keep existing app data (cache, UserDefaults)
  # intact, the same way Android's run.sh defaults to force-stop+start instead of
  # `pm clear`. Without this, `simctl launch` on an already-running instance can
  # just re-foreground it without re-running the startup/loadSchedule() sequence.
  xcrun simctl terminate "$TARGET" com.netpress.NextCaltrain 2>/dev/null
fi
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
