#!/bin/bash
# Makes the App Store screenshots of every locale of docs/release/store-listing.md: captures six screens per language
# of the app on simulators, then puts each caption of the listing above its screenshot, at the store size.
#
#   Tools/Release/store-screenshots.sh --output <dir> [--devices iphone-6.3,iphone,ipad] [--languages en,de,es,fr,it,pt]
#                                      [--ios <version>] [--simulator-prefix <name>] [--compose-only] [--listing <file>]
#
# Runs on a Mac with Xcode 27 or later. Devices:
#   iphone      iPhone 6.9-inch, on an iPhone 17 Pro Max: 1320 x 2868
#   iphone-6.3  iPhone 6.3-inch, on an iPhone 17 Pro: 1206 x 2622
#   ipad        iPad 13-inch, on an iPad Pro 13-inch (M5): 2064 x 2752
#
# For each device it uses the simulator "<prefix> <device>" (default prefix "PrestoCV store"), made on the first run
# with the newest iOS runtime or the one --ios names. It builds the StoreScreenshots test plan, which holds only
# StoreScreenshotsUITests, once. Then, for each language, it erases the simulator, so that no choice of the last language
# is left, and boots it in that language and region, so that the system's own screens (the share sheet) and the clock
# speak it too: the status bar at 9:41 (09:41 where the region writes it so), full battery and full signal, the light
# appearance, and a keyboard without autocorrection, spell check or predictions, which would change or underline the
# description the test types. It runs the language's test, handing it the app's texts in that language from the string
# catalog (the test does not read the source tree), and exports the screenshots the test attached.
#
# Output in <dir>:
#   captures/<device>/<language>/NN.png   the screenshots as the simulator took them
#   <locale>/<device>/NN.png              the screenshots to upload, with their captions
#   contact-sheet-<device>.png            every locale of a device at a glance
# --compose-only skips the capture and composes the captures already in <dir>. --listing takes the captions from another
# copy of docs/release/store-listing.md, such as a change to them that is still under review.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT=""; DEVICES="iphone-6.3,iphone,ipad"; LANGUAGES="en,de,es,fr,it,pt"; IOS=""; PREFIX="PrestoCV store"; COMPOSE_ONLY=0
LISTING="$ROOT/docs/release/store-listing.md"
while [ $# -gt 0 ]; do
    case "$1" in
        --output) OUTPUT="$2"; shift 2 ;;
        --devices) DEVICES="$2"; shift 2 ;;
        --languages) LANGUAGES="$2"; shift 2 ;;
        --ios) IOS="$2"; shift 2 ;;
        --simulator-prefix) PREFIX="$2"; shift 2 ;;
        --compose-only) COMPOSE_ONLY=1; shift ;;
        --listing) LISTING="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"; shift 2 ;;
        *) sed -n '2,27p' "$0" >&2; exit 2 ;;
    esac
done
[ -n "$OUTPUT" ] || { sed -n '2,27p' "$0" >&2; exit 2; }
mkdir -p "$OUTPUT"; OUTPUT="$(cd "$OUTPUT" && pwd)"
WORK="${TMPDIR:-/tmp}/prestocv-store-screenshots"; mkdir -p "$WORK"

device_type() {
    case "$1" in
        iphone) echo "iPhone 17 Pro Max" ;;
        iphone-6.3) echo "iPhone 17 Pro" ;;
        ipad) echo "iPad Pro 13-inch (M5)" ;;
        *) echo "unknown device $1" >&2; return 1 ;;
    esac
}

# The test of a language, and the region the simulator is set to for it (the people's own)
test_method() {
    case "$1" in
        en) echo testEnglish ;; de) echo testGerman ;; es) echo testSpanish ;;
        fr) echo testFrench ;; it) echo testItalian ;; pt) echo testPortuguese ;;
        *) echo "unknown language $1" >&2; return 1 ;;
    esac
}

region() {
    case "$1" in
        en) echo en_US ;; de) echo de_DE ;; es) echo es_ES ;; fr) echo fr_FR ;; it) echo it_IT ;; pt) echo pt_BR ;;
    esac
}

# The UDID of the device's simulator, made if it does not exist yet
simulator() {
    local name="$PREFIX $1${IOS:+ (iOS $IOS)}" type udid runtime
    udid=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
print(next((d["udid"] for runtime in devices.values() for d in runtime if d["name"] == sys.argv[1]), ""))' "$name")
    if [ -z "$udid" ]; then
        type=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
print(next(t["identifier"] for t in json.load(sys.stdin)["devicetypes"] if t["name"] == sys.argv[1]))' "$(device_type "$1")")
        runtime=$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"]
            if r["platform"] == "iOS" and r["isAvailable"] and r["version"].startswith(sys.argv[1])]
print(runtimes[-1]["identifier"])' "$IOS")
        udid=$(xcrun simctl create "$name" "$type" "$runtime")
        echo "made the simulator $name ($udid)" >&2
    fi
    echo "$udid"
}

boot() {
    xcrun simctl boot "$1"
    xcrun simctl bootstatus "$1" -b >/dev/null
}

# An erased simulator in the language, with the status bar, the appearance and the keyboard of the screenshots. The
# settings are written once it has booted, and read when it boots again.
prepare() {
    local udid="$1" language="$2" key
    xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    xcrun simctl erase "$udid"
    boot "$udid"
    xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array "$language"
    xcrun simctl spawn "$udid" defaults write -g AppleLocale "$(region "$language")"
    for key in KeyboardAutocorrection KeyboardCheckSpelling; do
        xcrun simctl spawn "$udid" defaults write com.apple.keyboard.preferences "$key" -bool NO
    done
    for key in KeyboardPrediction KeyboardInlineCompletion; do
        xcrun simctl spawn "$udid" defaults write com.apple.keyboard.predictive "$key" -bool NO
    done
    xcrun simctl spawn "$udid" defaults write com.apple.keyboard.ContinuousPath DidShowContinuousPathIntroduction -bool YES
    xcrun simctl shutdown "$udid"
    boot "$udid"
    xcrun simctl ui "$udid" appearance light
    xcrun simctl status_bar "$udid" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
        --cellularMode active --cellularBars 4 --operatorName "" --batteryState charged --batteryLevel 100
}

# The app's texts in a language, from its string catalog, as the test takes them: a JSON object from key to text, in
# Base64. A key without a text in the language has the source language's.
app_strings() {
    python3 - "$ROOT/PrestoCV/Localizable.xcstrings" "$1" <<'PY'
import base64, json, sys
catalog = json.load(open(sys.argv[1], encoding="utf-8"))
texts = {}
for key, entry in catalog["strings"].items():
    units = entry.get("localizations", {})
    unit = (units.get(sys.argv[2]) or units.get(catalog.get("sourceLanguage", "en")) or {}).get("stringUnit")
    if unit:
        texts[key] = unit["value"]
print(base64.b64encode(json.dumps(texts, ensure_ascii=False).encode("utf-8")).decode("ascii"))
PY
}

# Copies the screenshots of a result bundle, which the test names <language>-NN, to the captures
export_captures() {
    local bundle="$1" device="$2" attachments="$WORK/attachments"
    rm -rf "$attachments"
    xcrun xcresulttool export attachments --path "$bundle" --output-path "$attachments" >/dev/null
    python3 - "$attachments" "$OUTPUT/captures/$device" <<'PY'
import json, re, shutil, sys
from pathlib import Path
source, target = Path(sys.argv[1]), Path(sys.argv[2])
for test in json.loads((source / "manifest.json").read_text()):
    for attachment in test.get("attachments", []):
        match = re.fullmatch(r"([a-z]{2})-(\d{2})_.*", attachment.get("suggestedHumanReadableName", ""))
        if match:
            destination = target / match.group(1) / f"{match.group(2)}.png"
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / attachment["exportedFileName"], destination)
PY
}

capture() {
    local device="$1" udid language bundle log status=0
    local build=(-project "$ROOT/PrestoCV.xcodeproj" -scheme PrestoCV -testPlan StoreScreenshots
        -derivedDataPath "$WORK/DerivedData" -skipMacroValidation -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO)
    udid=$(simulator "$device")
    echo "== $device: building for $(device_type "$device"); log in $WORK/$device-build.log"
    xcodebuild build-for-testing "${build[@]}" -destination "id=$udid" </dev/null >"$WORK/$device-build.log" 2>&1 \
        || { grep -E "error:" "$WORK/$device-build.log" | head -20; return 1; }
    for language in ${LANGUAGES//,/ }; do
        prepare "$udid" "$language"
        bundle="$WORK/$device-$language.xcresult"; log="$WORK/$device-$language.log"
        rm -rf "$bundle"
        TEST_RUNNER_STORE_SCREENSHOT_STRINGS="$(app_strings "$language")" \
        xcodebuild test-without-building "${build[@]}" -destination "id=$udid" -resultBundlePath "$bundle" \
            -parallel-testing-enabled NO -collect-test-diagnostics never \
            "-only-testing:PrestoCVUITests/StoreScreenshotsUITests/$(test_method "$language")" </dev/null >"$log" 2>&1 \
            || status=1
        grep -E "Test Case .*(passed|failed)|error:|recorded an issue" "$log" | grep -v "^$" | tail -5 || true
        [ -d "$bundle" ] && export_captures "$bundle" "$device"
    done
    xcrun simctl status_bar "$udid" clear || true
    xcrun simctl shutdown "$udid" || true
    return "$status"
}

if [ "$COMPOSE_ONLY" -eq 0 ]; then
    for device in ${DEVICES//,/ }; do capture "$device"; done
fi
swiftc -O -swift-version 6 -o "$WORK/compose-store-screenshots" "$ROOT/Tools/Release/compose-store-screenshots.swift"
"$WORK/compose-store-screenshots" "$LISTING" "$OUTPUT/captures" "$OUTPUT" "$DEVICES" "$LANGUAGES"
echo "== screenshots in $OUTPUT"
