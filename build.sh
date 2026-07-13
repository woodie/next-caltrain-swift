#!/bin/bash
set -e

# See sim.sh for the full SIM_DEVICE resolution order (sim-device.env, then
# local.env). Kept in sync with sim.sh/test.sh so all three always target the
# same simulator by default.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/sim-device.env" ] && source "$SCRIPT_DIR/sim-device.env"
[ -f "$SCRIPT_DIR/local.env" ] && source "$SCRIPT_DIR/local.env"

xcodegen
xcodebuild -project NextCaltrain.xcodeproj -scheme NextCaltrain \
  -destination "platform=iOS Simulator,name=$SIM_DEVICE" \
  build 2>&1 | grep "error:" || true

# Requires a booted simulator: open -a Simulator
xcrun simctl uninstall booted com.netpress.NextCaltrain
 
