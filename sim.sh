#!/bin/bash
# Usage: ./sim.sh [-d DEVICE]                 boot the default simulator and leave it running
#        ./sim.sh run [-d DEVICE] [--fresh] [--log]
#          -d, --device DEVICE   boot/target a simulator matching DEVICE (substring match).
#                                 Overrides the default SIM_DEVICE (see the top of this
#                                 file) for this invocation only.
#          -f, --fresh           full wipe (uninstall) instead of a cold relaunch
#          -l, --log             stream filtered log output after launch (Ctrl-C to stop)
#        ./sim.sh snap [filename]
#          filename   optional output name, saved under ~/Downloads
#                      (default: snap-<timestamp>.png)
#          Targets a connected physical device if one is attached, otherwise falls
#          back to a booted Simulator. Requires:
#            brew install libimobiledevice   (idevice_id, idevicescreenshot — for a real device)
#            Xcode command line tools        (xcrun simctl — for the Simulator)
#        ./sim.sh dark | light
#          switch the Simulator to dark/light mode (Simulator only -- iOS has no
#          public command-line API to toggle Dark Mode on a physical device,
#          switch it manually: Settings > Display & Brightness, or Control Center)
#        ./sim.sh list
#          list installed simulators (name + UDID + booted state), for picking
#          a -d/--device value

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default simulator sim.sh (and build.sh/test.sh) boot/target when no
# -d/--device is given and SIM_DEVICE isn't already set in the calling
# environment (e.g. `SIM_DEVICE="iPhone 17" ./sim.sh`, which still wins over
# the line below). Swap the active line for a commented alternative (or add
# your own) to change it, e.g. after switching to a larger phone for App
# Store screenshots -- see docs/SCREENSHOTS.md. Edit + commit to change it
# for everyone. Kept in sync with build.sh/test.sh; no separate config file.
SIM_DEVICE="${SIM_DEVICE:-iPhone 17 Pro Max}"
# SIM_DEVICE="${SIM_DEVICE:-iPhone SE (3rd generation)}"

# Boots TARGET, first shutting down any other booted simulator. `simctl
# boot` on a second device doesn't replace an already-running one -- it
# boots alongside it, and `open -a Simulator` only brings the app forward,
# with no guarantee the just-booted device's window becomes the visible
# one. Without this, switching to a different device via -d/--device can
# silently no-op from where you're looking (the old window stays in front)
# while a second simulator boots invisibly behind it. Shared by cmd_boot and
# cmd_run's own -d/--device.
boot_exclusive() {
  local target="$1"
  xcrun simctl list devices 2>/dev/null | grep "(Booted)" | grep -v "$target" \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
    | while read -r other; do xcrun simctl shutdown "$other" 2>/dev/null; done
  xcrun simctl boot "$target" 2>/dev/null
  open -a Simulator
}

# Resolves a simulator NAME to its UDID: an exact device name always wins if
# one exists, otherwise falls back to a substring match (case-insensitive
# either way). The exact-match pass matters because "iPhone 17" is also a
# substring of "iPhone 17 Pro"/"iPhone 17 Pro Max"/"iPhone 17e" -- without
# it, asking for the bare "iPhone 17" would resolve to whichever of those
# happens to be listed first instead. grep -F (literal, not regex) avoids
# needing to escape $name; matching "$name (" specifically requires nothing
# but the UDID's opening paren between the name and end of line.
# Shared by cmd_boot and cmd_run's own -d/--device.
resolve_device() {
  local name="$1"
  local list
  list=$(xcrun simctl list devices | grep -v unavailable)

  local udid
  udid=$(echo "$list" | grep -iF "$name (" | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
  if [ -z "$udid" ]; then
    udid=$(echo "$list" | grep -i "$name" | head -1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
  fi
  if [ -z "$udid" ]; then
    echo "No simulator found matching '$name'" >&2
    return 1
  fi
  echo "$udid"
}

# Shared by snap/dark/light -- sets USE_REAL_DEVICE, and enforces that exactly
# one device/simulator combination is unambiguous: a physical device wins if
# exactly one is attached, otherwise the booted Simulator is used. More than
# one physical device is ambiguous (no simctl-style "pick one" flag here), so
# that's an error rather than a guess.
detect_target() {
  REAL_DEVICE_COUNT=$(idevice_id -l 2>/dev/null | wc -l | tr -d ' ')
  SIM_BOOTED_COUNT=$(xcrun simctl list devices 2>/dev/null | grep -c "(Booted)")

  if [ "$REAL_DEVICE_COUNT" -eq 0 ] && [ "$SIM_BOOTED_COUNT" -eq 0 ]; then
    echo "No physical device attached and no booted simulator found — boot one first: ./sim.sh"
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
}

cmd_boot() {
  local device="$SIM_DEVICE"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--device)
        device="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  local target
  target=$(resolve_device "$device") || exit 1
  boot_exclusive "$target"
}

cmd_run() {
  # Schedule endpoint resolution, highest priority first:
  #   1. local.env (gitignored) — per-developer override, e.g. to point at a local
  #      hang/instant-fail test server. Never committed. Sourced after
  #      config.properties so it takes precedence.
  #   2. config.properties (committed) — the real production URL. If the schedule
  #      data ever moves to a new home, edit and commit this file directly.
  # See docs/COWORK.md "Schedule data pipeline".
  if [ -f "$SCRIPT_DIR/config.properties" ]; then
    source "$SCRIPT_DIR/config.properties"
  fi
  if [ -f "$SCRIPT_DIR/local.env" ]; then
    source "$SCRIPT_DIR/local.env"
  fi
  if [ -n "$SCHEDULE_URL" ]; then
    export SIMCTL_CHILD_SCHEDULE_URL="$SCHEDULE_URL"
    echo "Using schedule endpoint: $SCHEDULE_URL"
  fi

  local DEVICE=""
  local LOG=false
  local FRESH=false

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

  local TARGET
  if [ -n "$DEVICE" ]; then
    TARGET=$(resolve_device "$DEVICE") || exit 1
    boot_exclusive "$TARGET"
    xcrun simctl bootstatus "$TARGET" -b
  else
    if [ "$(xcrun simctl list devices 2>/dev/null | grep -c "(Booted)")" -eq 0 ]; then
      echo "No simulator booted — boot one first: ./sim.sh"
      exit 1
    fi
    TARGET="booted"
  fi

  if [ "$FRESH" = true ]; then
    # Full wipe: removes the app's entire data container (cache, UserDefaults).
    xcrun simctl uninstall "$TARGET" com.netpress.NextCaltrain
  else
    # Default: force a cold relaunch but keep existing app data (cache, UserDefaults)
    # intact, the same way Android's sim.sh run defaults to force-stop+start instead
    # of `pm clear`. Without this, `simctl launch` on an already-running instance can
    # just re-foreground it without re-running the startup/loadSchedule() sequence.
    xcrun simctl terminate "$TARGET" com.netpress.NextCaltrain 2>/dev/null
  fi
  # A bare glob here isn't guaranteed to pick the build .sh just produced — if more
  # than one NextCaltrain-* DerivedData folder exists (easy to end up with, since
  # xcodegen regenerates the project), glob expansion has no notion of "newest" and
  # can silently install a stale .app. `ls -t` picks the most recently built one.
  local APP_PATH
  APP_PATH=$(ls -dt ~/Library/Developer/Xcode/DerivedData/NextCaltrain-*/Build/Products/Debug-iphonesimulator/NextCaltrain.app 2>/dev/null | head -1)
  xcrun simctl install "$TARGET" "$APP_PATH"
  xcrun simctl launch "$TARGET" com.netpress.NextCaltrain

  if [ "$LOG" = true ]; then
     xcrun simctl spawn "$TARGET" log stream \
      --level debug \
      --style compact \
      --predicate 'composedMessage CONTAINS "[GoodTimes]" OR composedMessage CONTAINS "[TripViewModel]" OR composedMessage CONTAINS "[Schedule]" OR composedMessage CONTAINS "[TripList]"'
  fi
}

cmd_snap() {
  local DEST_DIR=~/Downloads
  local NAME="$1"
  detect_target

  if [ -z "$NAME" ]; then
    NAME="snap-$(date +%Y%m%d-%H%M%S).png"
  fi
  local OUT="$DEST_DIR/$NAME"

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
}

cmd_mode() {
  local MODE="$1"
  detect_target

  if [ "$USE_REAL_DEVICE" -eq 1 ]; then
    echo "Dark/light mode can't be switched via command line on a physical device."
    echo "Switch manually: Settings > Display & Brightness, or Control Center (long-press the brightness slider)."
    exit 1
  fi

  xcrun simctl ui booted appearance "$MODE"
  echo "Switched simulator to $MODE mode"
}

cmd_list() {
  # Filtered to "available iPhone" -- the unfiltered list also includes
  # every watchOS/tvOS/visionOS pairing and unavailable runtimes, which
  # buries the handful of iPhone simulators actually relevant here.
  xcrun simctl list devices available iPhone
  echo
  echo "Boot one of these: ./sim.sh -d \"<name or unique substring>\""
}

case "${1:-}" in
  run)
    shift
    cmd_run "$@"
    ;;
  snap)
    cmd_snap "$2"
    ;;
  dark|light)
    cmd_mode "$1"
    ;;
  list)
    cmd_list
    ;;
  ""|-d|--device)
    cmd_boot "$@"
    ;;
  *)
    echo "Usage: $0 [[-d DEVICE] | run [--fresh] [--log] [-d DEVICE] | snap [filename] | dark | light | list]" >&2
    exit 1
    ;;
esac
