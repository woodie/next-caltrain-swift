#!/bin/bash
set -e

xcodegen generate

# See sim.sh for the full SIM_DEVICE resolution order (sim-device.env, then
# local.env). Kept in sync with sim.sh/build.sh so all three always target
# the same simulator by default.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/sim-device.env" ] && source "$SCRIPT_DIR/sim-device.env"
[ -f "$SCRIPT_DIR/local.env" ] && source "$SCRIPT_DIR/local.env"

# Reuse whatever simulator is already booted instead of letting xcodebuild
# resolve a destination by name. This used to target a different device name
# here than build.sh/sim.sh used, which meant xcodebuild always booted a
# second, different simulator even when one was already running. If nothing
# is booted, fall back to booting $SIM_DEVICE to match build.sh/sim.sh.
BOOTED_UDID=$(xcrun simctl list devices booted 2>/dev/null | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)

if [ -n "$BOOTED_UDID" ]; then
  DESTINATION="platform=iOS Simulator,id=$BOOTED_UDID"
else
  echo "No booted simulator found; booting $SIM_DEVICE."
  DESTINATION="platform=iOS Simulator,name=$SIM_DEVICE"
fi

# Quick flattens every describe()/context()/it() into one comma-joined
# string per test -- XCTest only ever sees one flat Case per it(), never a
# nested Suite (see docs/COWORK.md's "Test output formatting" for why).
# xctidy reads xcodebuild's raw output directly and reconstructs the tree
# by comma-disambiguating against the real describe/context/it literals in
# Tests/*.swift. See https://github.com/woodie/xctidy.
if ! command -v xctidy &> /dev/null; then
  echo "error: xctidy not found on PATH -- clone github.com/woodie/xctidy and run 'make install'" >&2
  exit 1
fi

# A bare word with no leading dash (e.g. `./test.sh GoodTimesSpec`) is
# treated as a spec filter and translated into XCTest's -only-testing flag.
# A ".swift" path (e.g. shell-completed from Tests/GoodTimesSpec.swift) has
# its directory and extension stripped down to the bare class name first, so
# tab-completion works. After that: a name containing a "/" is used as-is
# (already Target/Class or Target/Class/method); a bare class name is
# wrapped as NextCaltrainTests/<name>. Everything else (any dash-prefixed
# flag, e.g. -only-testing:... directly, or none at all) is forwarded
# unchanged.
#
#   ./test.sh GoodTimesSpec
#   ./test.sh Tests/GoodTimesSpec.swift
#   ./test.sh NextCaltrainTests/GoodTimesSpec/testSomeItBlock
ARGS=("$@")
if [ "$#" -gt 0 ] && [[ "$1" != -* ]]; then
  ARG="$1"
  [[ "$ARG" == *.swift ]] && ARG="$(basename "$ARG" .swift)"
  case "$ARG" in
    */*) FILTER="-only-testing:$ARG" ;;
    *)   FILTER="-only-testing:NextCaltrainTests/$ARG" ;;
  esac
  ARGS=("$FILTER" "${@:2}")
fi

xcodebuild test \
  -scheme NextCaltrain \
  -destination "$DESTINATION" \
  -enableCodeCoverage NO \
  "${ARGS[@]}" \
  | xctidy -fs "$(dirname "$0")/Tests"
