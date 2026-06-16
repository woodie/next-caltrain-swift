#!/bin/bash
set -e
xcodegen
xcodebuild -project NextCaltrain.xcodeproj -scheme NextCaltrain \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep "error:" || true

# Requires a booted simulator: open -a Simulator
xcrun simctl uninstall booted com.netpress.NextCaltrain
 
