#!/usr/bin/env bash
# Prints the UDID of the dedicated test simulator, "PrestoCV CI" (iPhone 17 Pro), after erasing it. It creates the
# simulator when no device matches the exact name, device type and runtime, so it never erases another device.
# The runtime is PRESTOCV_SIM_RUNTIME when set; otherwise iOS 26.5 when the Mac has it, else the newest iOS runtime the Mac
# has, so a freshly installed Mac works with whatever runtime its Xcode brought.
set -euo pipefail
NAME="PrestoCV CI"
TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro"
PREFERRED_RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-26-5"
RUNTIME="${PRESTOCV_SIM_RUNTIME:-$(xcrun simctl list runtimes available -j | python3 -c '
import json, sys
preferred = sys.argv[1]
ios = [r for r in json.load(sys.stdin)["runtimes"] if r.get("platform") == "iOS" and r.get("isAvailable")]
ids = [r["identifier"] for r in ios]
newest = max(ios, key=lambda r: [int(p) for p in r["version"].split(".")])["identifier"] if ios else ""
print(preferred if preferred in ids else newest)' "$PREFERRED_RUNTIME")}"
[ -n "$RUNTIME" ] || { echo "no iOS simulator runtime is installed" >&2; exit 1; }
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
