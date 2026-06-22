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

# xcpretty's --test format is labeled "RSpec style" in its own docs, but in
# practice it silently degrades to bare dot-progress output on current Xcode
# versions — xcpretty is unmaintained and apparently can't parse newer
# xcodebuild test-output formats. xcbeautify is actively maintained and
# reliably prints full per-test names, so it's preferred here even though its
# rendering isn't a true nested tree either. xcpretty is just a fallback in
# case xcbeautify isn't installed.
#
# Quick flattens every describe()/context()/it() into one comma-joined string
# per test, so xcbeautify's (and xcpretty's) per-test line repeats the full
# chain every time. tools/test_formatter.py turns that flat stream back
# into an indented tree by deduping each line's shared prefix against the
# previous one — see the script's docstring for the full rationale, including
# why failing-test lines are deliberately left un-deduped.
FORMAT_TREE="$(dirname "$0")/tools/test_formatter.py"

if command -v xcbeautify &> /dev/null; then
  xcodebuild test \
    -scheme NextCaltrain \
    -destination "$DESTINATION" \
    -enableCodeCoverage NO \
    | xcbeautify \
    | "$FORMAT_TREE"
elif command -v xcpretty &> /dev/null; then
  xcodebuild test \
    -scheme NextCaltrain \
    -destination "$DESTINATION" \
    -enableCodeCoverage NO \
    | xcpretty --test \
    | "$FORMAT_TREE"
else
  xcodebuild test \
    -scheme NextCaltrain \
    -destination "$DESTINATION" \
    -enableCodeCoverage NO \
    2>/dev/null \
    | grep -E "Test Suite '(GoodTimes|CaltrainService|TripViewModel|All tests|NextCaltrainTests)|error:|\*\* TEST"
fi
