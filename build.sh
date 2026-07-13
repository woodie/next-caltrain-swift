#!/bin/bash
set -e

# Default simulator -- see sim.sh for the full explanation. Kept in sync
# with sim.sh/test.sh so all three always target the same simulator by
# default.
SIM_DEVICE="${SIM_DEVICE:-iPhone 17 Pro Max}"
# SIM_DEVICE="${SIM_DEVICE:-iPhone SE (3rd generation)}"

xcodegen
xcodebuild -project NextCaltrain.xcodeproj -scheme NextCaltrain \
  -destination "platform=iOS Simulator,name=$SIM_DEVICE" \
  build 2>&1 | grep "error:" || true

# Requires a booted simulator: open -a Simulator
xcrun simctl uninstall booted com.netpress.NextCaltrain
 
