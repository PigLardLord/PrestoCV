#!/usr/bin/env bash
# Prints the UDID of the dedicated test simulator, "PrestoCV CI" (iPhone 17 Pro, iOS 26.5), after erasing it. It creates
# the simulator when no device matches the exact name, device type and runtime, so it never erases another device.
set -euo pipefail
NAME="PrestoCV CI"
TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-26-5"
UDID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name, kind, runtime = sys.argv[1:4]
devices = json.load(sys.stdin)["devices"].get(runtime, [])
matches = [d["udid"] for d in devices if d["name"] == name and d.get("deviceTypeIdentifier") == kind]
print(matches[0] if matches else "")' "$NAME" "$TYPE" "$RUNTIME")"
if [ -z "$UDID" ]; then
  UDID="$(xcrun simctl create "$NAME" "$TYPE" "$RUNTIME")"
fi
xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
xcrun simctl erase "$UDID" >&2
echo "$UDID"
