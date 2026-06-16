#!/bin/bash
set -e

# If the simulator isn't running yet: open -a Simulator

xcodegen generate

if command -v xcbeautify &> /dev/null; then
  xcodebuild test \
    -scheme NextCaltrain \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    | xcbeautify
elif command -v xcpretty &> /dev/null; then
  xcodebuild test \
    -scheme NextCaltrain \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    | xcpretty --test
else
  xcodebuild test \
    -scheme NextCaltrain \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    2>/dev/null \
    | grep -E "Test Suite '(GoodTimes|CaltrainService|TripViewModel|All tests|NextCaltrainTests)|error:|\*\* TEST"
fi
