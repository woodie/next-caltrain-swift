#!/bin/bash
set -e

xcodegen generate

# Reuse whatever simulator is already booted instead of letting xcodebuild
# resolve a destination by name. This used to target "iPhone 17" here while
# build.sh/run.sh target "iPhone 17 Pro" — a mismatch that meant xcodebuild
# always booted a second, different simulator even when one was already
# running. If nothing is booted, fall back to booting "iPhone 17 Pro" to
# match build.sh's default.
BOOTED_UDID=$(xcrun simctl list devices booted 2>/dev/null | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)

if [ -n "$BOOTED_UDID" ]; then
  DESTINATION="platform=iOS Simulator,id=$BOOTED_UDID"
else
  echo "No booted simulator found; booting iPhone 17 Pro."
  DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"
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
# A name containing a "/" is used as-is (already Target/Class or
# Target/Class/method); a bare class name is wrapped as
# NextCaltrainTests/<name>. Everything else (any dash-prefixed flag, e.g.
# -only-testing:... directly, or none at all) is forwarded unchanged.
#
#   ./test.sh GoodTimesSpec
#   ./test.sh NextCaltrainTests/GoodTimesSpec/testSomeItBlock
ARGS=("$@")
if [ "$#" -gt 0 ] && [[ "$1" != -* ]]; then
  case "$1" in
    */*) FILTER="-only-testing:$1" ;;
    *)   FILTER="-only-testing:NextCaltrainTests/$1" ;;
  esac
  ARGS=("$FILTER" "${@:2}")
fi

xcodebuild test \
  -scheme NextCaltrain \
  -destination "$DESTINATION" \
  -enableCodeCoverage NO \
  "${ARGS[@]}" \
  | xctidy -fs "$(dirname "$0")/Tests"
