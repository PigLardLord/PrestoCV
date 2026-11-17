#!/bin/bash
# Makes the App Store screenshots of every locale of docs/release/store-listing.md: captures six screens per language
# of the app on simulators, then puts each caption of the listing above its screenshot, at the store size.
#
#   Tools/Release/store-screenshots.sh --output <dir> [--devices iphone,ipad] [--languages en,de,es,fr,it,pt]
#                                      [--ios <version>] [--simulator-prefix <name>] [--compose-only] [--listing <file>]
#
# Runs on a Mac with Xcode 27 or later. Devices:
#   iphone      iPhone 6.9-inch, on an iPhone 17 Pro Max: 1320 x 2868
#   iphone-6.3  iPhone 6.3-inch, on an iPhone 17 Pro: 1206 x 2622 (not in the default: only if App Store Connect asks for it)
#   ipad        iPad 13-inch, on an iPad Pro 13-inch (M5): 2064 x 2752
#
# For each device it uses the simulator "<prefix> <device>" (default prefix "PrestoCV store"), made on the first run
# with the newest iOS runtime or the one --ios names. The tool erases the simulators it uses, so the prefix must start
# with "PrestoCV store": that name is reserved to it, and no other simulator may carry it. It builds the
# StoreScreenshots test plan, which holds only StoreScreenshotsUITests, once. Then, for each language, it erases the
# simulator, so that no choice of the last language is left, and boots it in that language and region, so that the
# system's own screens (the share sheet) and the clock speak it too: the status bar at 9:41 on a fixed date (09:41 where the region
# writes it so; the iPad's bar shows the date too, which the simulator writes in English, so the composer writes it again in
# the language), full battery and full signal, the light appearance, and a keyboard without autocorrection, spell check
# or predictions, which would change or underline the description the test types. It runs the language's test, handing
# it the app's texts in that language from the string catalog (the test does not read the source tree), and exports the
# screenshots the test attached.
#
# Output in <dir>:
#   captures/<device>/<language>/NN.png   the six screenshots as the simulator took them
#   <locale>/<device>/NN.png              the screenshots to upload, with their captions
#   contact-sheet-<device>.png            every locale of a device at a glance
# --compose-only skips the capture and composes the captures already in <dir>, which must be the six of every device and
# language asked for (it prints when they were taken). --listing takes the captions from another copy of
# docs/release/store-listing.md, such as a change to them that is still under review.
#
# The arguments are checked before anything is taken or erased. A capture run then starts by removing the captures of every
# device and language it was asked for, before the first step that can fail (finding the simulators, the build, the
# preparation of a simulator), so that a run that fails at any step leaves none of them for a later --compose-only to
# accept. The captures of a language are made aside, in <language>.partial, and put in place by a rename once all six
# are copied: a copy that fails leaves no file of the language. A language whose test fails (or attaches fewer than six
# screenshots) keeps none of its captures, the other languages of the device are still run, and then the run ends: the
# second device and the composer are skipped, so that a set with a hole is never composed. A run that is killed leaves the
# same: the captures of the languages it had finished, whole, and none of the language it was in or of those after it.
# The composer replaces the screenshots to upload in the same way, as a whole, and a run of it that is killed while it puts
# them in place leaves a file (.compose-promoting, in <dir>) that makes the next run refuse until it is looked at.
#
# One run at a time: the runs share the simulators and the work folder, so a second one exits with 75 while the first
# lives, and also while a capture of a first one that was killed is still going. Whatever way a run ends (the end, a failure,
# Ctrl-C or a signal), it stops its capture, clears the status bar of the simulator it was using, shuts it down and
# releases the lock. Tools/Release/store-screenshots-selftest.sh tests this on fake tools.
set -euo pipefail
# Job control: a command started with & gets a process group of its own, so that run_child can end it as a whole
set -m

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0" >&2; exit 2; }
refuse() { echo "store-screenshots: $*" >&2; exit 2; }

DEVICE_NAMES="iphone iphone-6.3 ipad"; LANGUAGE_CODES="en de es fr it pt"
# The number of screenshots the test of a language attaches, and the composer puts a caption on each
SCREENSHOTS=6

OUTPUT=""; DEVICES="iphone,ipad"; LANGUAGES="en,de,es,fr,it,pt"; IOS=""; PREFIX="PrestoCV store"; COMPOSE_ONLY=0
LISTING="$ROOT/docs/release/store-listing.md"
while [ $# -gt 0 ]; do
    case "$1" in
        --compose-only) COMPOSE_ONLY=1; shift; continue ;;
        --output|--devices|--languages|--ios|--simulator-prefix|--listing) [ $# -ge 2 ] || refuse "$1 needs a value" ;;
        *) usage ;;
    esac
    case "$1" in
        --output) OUTPUT="$2" ;;
        --devices) DEVICES="$2" ;;
        --languages) LANGUAGES="$2" ;;
        --ios) IOS="$2" ;;
        --simulator-prefix) PREFIX="$2" ;;
        --listing) LISTING="$2" ;;
    esac
    shift 2
done
[ -n "$OUTPUT" ] || usage

# Every argument is checked here, before the lock is taken and before a simulator is touched: a mistake must not be found
# by the composer after half an hour of captures. (set -e does not see a command that fails inside a $(...) in a word.)
# check_list <option> <comma-separated value> <the names that are known...>
check_list() {
    local option="$1" value="$2" item known found count=0; shift 2
    for item in ${value//,/ }; do
        found=0
        for known in "$@"; do [ "$item" != "$known" ] || found=1; done
        [ "$found" = 1 ] || refuse "$option: \"$item\" is not one of: $*"
        count=$((count + 1))
    done
    [ "$count" -gt 0 ] || refuse "$option needs at least one of: $*"
}
check_list --languages "$LANGUAGES" $LANGUAGE_CODES
check_list --devices "$DEVICES" $DEVICE_NAMES
if [ -n "$IOS" ]; then
    case "$IOS" in
        *[!0-9.]*|.*|*.|*..*) refuse "--ios: \"$IOS\" is not a version of iOS, such as 27 or 26.5" ;;
    esac
fi
[ -f "$LISTING" ] || refuse "--listing: $LISTING is not a file"
LISTING="$(cd "$(dirname "$LISTING")" && pwd)/$(basename "$LISTING")"
# The simulators are erased by name: only a name reserved to this tool may be erased
RESERVED="PrestoCV store"
case "$PREFIX" in
    "$RESERVED"|"$RESERVED "*) ;;
    *) refuse "--simulator-prefix must start with \"$RESERVED\": the tool erases the simulators it uses, so that name is reserved to it" ;;
esac
mkdir -p "$OUTPUT"; OUTPUT="$(cd "$OUTPUT" && pwd)"
WORK="${TMPDIR:-/tmp}/prestocv-store-screenshots"; mkdir -p "$WORK"

# One run at a time. The lock is a folder, which only one process can make. It holds the pid of the run (pid) and, while a
# capture is going, the pid of that capture (child), which is the leader of its process group. The lock of a run that ended
# without a chance to clean up (a kill) is taken over, unless its capture is still going: that capture is still using the
# simulator, and the new run would erase it from under it. The takeover is one run at a time too: the folder $LOCK.takeover is made by
# the first run that gets there, and removed once it holds the lock.
LOCK="$WORK/lock"
alive() { kill -0 "$1" 2>/dev/null; }
group_alive() { kill -0 "$1" 2>/dev/null || kill -0 -- "-$1" 2>/dev/null; }
took_first() { echo "store-screenshots: another run took the lock first" >&2; exit 75; }
if mkdir "$LOCK" 2>/dev/null; then
    echo $$ > "$LOCK/pid"
else
    holder="$(cat "$LOCK/pid" 2>/dev/null || true)"; child="$(cat "$LOCK/child" 2>/dev/null || true)"
    if [ -z "$holder" ] || alive "$holder"; then
        echo "store-screenshots: another run (${holder:-pid not written yet}) is using the simulators and $WORK; wait for it, or remove $LOCK if that run has ended" >&2
        exit 75
    fi
    if [ -n "$child" ] && group_alive "$child"; then
        echo "store-screenshots: the run $holder has ended, but its capture ($child) is still using the simulators; stop it with: kill -- -$child, and run again" >&2
        exit 75
    fi
    if ! mkdir "$LOCK.takeover" 2>/dev/null; then
        echo "store-screenshots: another run is taking the lock over; wait for it, or remove $LOCK.takeover if that run has ended" >&2
        exit 75
    fi
    # Another run may have taken the lock over between the look at it and the folder just made
    if [ "$(cat "$LOCK/pid" 2>/dev/null || true)" != "$holder" ]; then rmdir "$LOCK.takeover"; took_first; fi
    echo "store-screenshots: taking over the lock of the run $holder, which has ended" >&2
    rm -rf "$LOCK"
    if ! mkdir "$LOCK" 2>/dev/null; then rmdir "$LOCK.takeover"; took_first; fi
    echo $$ > "$LOCK/pid"
    rmdir "$LOCK.takeover"
fi

# The simulator the run is using and the capture it is waiting for, put back on every way out: the capture ended with its
# whole group, the status bar cleared, the simulator shut down, the lock released
SIMULATOR=""; CHILD=""
finish() {
    local status=$? waited
    trap - EXIT
    if [ -n "$CHILD" ]; then
        # A process that forks at the very moment of the signal can miss it, so the group is asked again until it has gone
        for waited in $(seq 1 50); do
            kill -TERM -- "-$CHILD" 2>/dev/null || kill -TERM "$CHILD" 2>/dev/null || true
            sleep 0.2
            group_alive "$CHILD" || break
        done
        if group_alive "$CHILD"; then kill -KILL -- "-$CHILD" 2>/dev/null || true; fi
        { wait "$CHILD"; } 2>/dev/null || true
    fi
    if [ -n "$SIMULATOR" ]; then
        xcrun simctl status_bar "$SIMULATOR" clear >/dev/null 2>&1 || true
        xcrun simctl shutdown "$SIMULATOR" >/dev/null 2>&1 || true
    fi
    rm -rf "$LOCK"
    exit "$status"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# run_child <log> <command...>: runs the command in the background, in a group of its own, and waits for it. A trap does
# not run while a command runs in the foreground, so a signal to this script would be answered only when the capture, which
# takes half an hour, had ended; a wait is interrupted by it, and finish then ends the group. The pid of the command goes
# into the lock by the command's own shell, before it execs, so that a run after a kill -9 of this one finds it there.
run_child() {
    local log="$1" status=0; shift
    sh -c 'echo $$ > "$1"; shift; exec "$@"' sh "$LOCK/child" "$@" </dev/null >"$log" 2>&1 &
    CHILD=$!
    wait "$CHILD" || status=$?
    CHILD=""
    rm -f "$LOCK/child"
    return "$status"
}

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
        *) echo "unknown language $1" >&2; return 1 ;;
    esac
}

# The UDID of the device's simulator, made if it does not exist yet. Returns 2 when --ios names a version the Mac has no
# runtime of, and 1 when the Mac cannot make the device.
simulator() {
    local name="$PREFIX $1${IOS:+ (iOS $IOS)}" type udid runtime
    udid=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
print(next((d["udid"] for runtime in devices.values() for d in runtime if d["name"] == sys.argv[1]), ""))' "$name") || return 1
    if [ -z "$udid" ]; then
        type=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
print(next((t["identifier"] for t in json.load(sys.stdin)["devicetypes"] if t["name"] == sys.argv[1]), ""))' "$(device_type "$1")") || return 1
        [ -n "$type" ] || { echo "store-screenshots: this Xcode has no simulator of the type $(device_type "$1")" >&2; return 1; }
        runtime=$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
wanted = sys.argv[1]
runtimes = [r for r in json.load(sys.stdin)["runtimes"]
            if r["platform"] == "iOS" and r["isAvailable"] and (not wanted or r["version"] == wanted or r["version"].startswith(wanted + "."))]
print(runtimes[-1]["identifier"] if runtimes else "")' "$IOS") || return 1
        [ -n "$runtime" ] || { echo "store-screenshots: this Mac has no iOS ${IOS:-simulator} runtime (xcrun simctl list runtimes)" >&2; return 2; }
        udid=$(xcrun simctl create "$name" "$type" "$runtime") || return 1
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
    # The keyboard's first-use intro ("Speed up your typing by sliding your finger across the letters...", with Continue)
    # can cover the keyboard and its Done bar on an erased simulator, and a tap on Done then misses. The keyboard of iOS 26
    # and 27 keeps the flag that it has shown the intro in com.apple.keyboard.preferences (it writes it there itself once
    # it has shown it) and reads it at boot. A flag that did not reach the simulator's disk would let the intro come back,
    # so it is read back after that boot.
    xcrun simctl spawn "$udid" defaults write com.apple.keyboard.preferences DidShowContinuousPathIntroduction -bool YES
    xcrun simctl shutdown "$udid"
    boot "$udid"
    [ "$(xcrun simctl spawn "$udid" defaults read com.apple.keyboard.preferences DidShowContinuousPathIntroduction)" = 1 ] || {
        echo "store-screenshots: the keyboard's first-use intro could not be marked as seen on $udid" >&2
        return 1
    }
    xcrun simctl ui "$udid" appearance light
    xcrun simctl status_bar "$udid" override --time "$(status_bar_time)" --dataNetwork wifi --wifiMode active --wifiBars 3 \
        --cellularMode active --cellularBars 4 --operatorName "" --batteryState charged --batteryLevel 100
}

# The clock of the status bar: simctl reads an ISO 8601 date-time (with fractional seconds) in the Mac's time zone, so the
# offset is the Mac's on that day. A bare "9:41" leaves the real date on the iPad's bar, so a capture would carry the day it
# was made. The date is fixed, and 9:41 is the local time of it. With it the iPad's bar writes the date in English, with
# another weekday, in every language: the composer paints it over with the same day, its statusBarDay, as the iPad writes
# it in the capture's language (the self-test checks that the two days agree).
status_bar_time() {
    python3 -c 'import datetime
offset = datetime.datetime(2007, 1, 9, 9, 41).astimezone().strftime("%z")
print("2007-01-09T09:41:00.000%s:%s" % (offset[:3], offset[3:]))'
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

# Copies the screenshots of a result bundle, which the test names <language>-NN, to the captures of the language, if it
# attached all of them. A language with fewer keeps none of them: a set with a hole is not one to compose. The copy is made
# in <language>.partial and renamed once it is whole, so that a copy that fails (or is cut short) leaves no file that a
# --compose-only would take for a capture. (It is called in a list with ||, where set -e does not apply: every step is checked.)
export_captures() {
    local bundle="$1" device="$2" language="$3" attachments="$WORK/attachments"
    local target="$OUTPUT/captures/$device/$language"
    rm -rf "$attachments" "$target.partial"
    xcrun xcresulttool export attachments --path "$bundle" --output-path "$attachments" >/dev/null || return 1
    python3 - "$attachments" "$target.partial" "$language" "$SCREENSHOTS" <<'PY' || { rm -rf "$target.partial"; return 1; }
import json, re, shutil, sys
from pathlib import Path
source, target, language, expected = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], int(sys.argv[4])
found = {}
for test in json.loads((source / "manifest.json").read_text()):
    for attachment in test.get("attachments", []):
        match = re.fullmatch(r"([a-z]{2})-(\d{2})_.*", attachment.get("suggestedHumanReadableName", ""))
        if match and match.group(1) == language:
            found[int(match.group(2))] = source / attachment["exportedFileName"]
if sorted(found) != list(range(1, expected + 1)):
    print(f"store-screenshots: the {language} test attached {len(found)} of the {expected} screenshots; none of them is kept",
          file=sys.stderr)
    sys.exit(1)
target.mkdir(parents=True, exist_ok=True)
for number, file in found.items():
    shutil.copyfile(file, target / f"{number:02d}.png")
PY
    rm -rf "$target"
    mv "$target.partial" "$target" || { rm -rf "$target.partial"; return 1; }
}

capture() {
    local device="$1" udid language bundle log strings status=0
    local build=(-project "$ROOT/PrestoCV.xcodeproj" -scheme PrestoCV -testPlan StoreScreenshots
        -derivedDataPath "$WORK/DerivedData" -skipMacroValidation -skipPackagePluginValidation CODE_SIGNING_ALLOWED=NO)
    udid=$(simulator "$device") || return $?
    SIMULATOR="$udid"
    echo "== $device: building for $(device_type "$device"); log in $WORK/$device-build.log"
    run_child "$WORK/$device-build.log" xcodebuild build-for-testing "${build[@]}" -destination "id=$udid" \
        || { grep -E "error:" "$WORK/$device-build.log" | head -20; return 1; }
    for language in ${LANGUAGES//,/ }; do
        prepare "$udid" "$language"
        bundle="$WORK/$device-$language.xcresult"; log="$WORK/$device-$language.log"
        # The result bundle of an earlier run: xcodebuild does not write over one. (The captures of the language were
        # removed when the run began.)
        rm -rf "$bundle"
        strings=$(app_strings "$language")
        if TEST_RUNNER_STORE_SCREENSHOT_STRINGS="$strings" run_child "$log" \
            xcodebuild test-without-building "${build[@]}" -destination "id=$udid" -resultBundlePath "$bundle" \
            -parallel-testing-enabled NO -collect-test-diagnostics never \
            "-only-testing:PrestoCVUITests/StoreScreenshotsUITests/$(test_method "$language")"; then
            export_captures "$bundle" "$device" "$language" || status=1
        else
            echo "store-screenshots: the $language test failed on $device; none of its screenshots is kept" >&2
            status=1
        fi
        grep -E "Test Case .*(passed|failed)|error:|recorded an issue" "$log" | grep -v "^$" | tail -5 || true
    done
    xcrun simctl status_bar "$udid" clear || true
    xcrun simctl shutdown "$udid" || true
    SIMULATOR=""
    return "$status"
}

# The composer takes the captures it finds, so that a run that did not get to the end must not leave a set to compose. It
# is given only the six captures of every device and language asked for, and the date they were taken.
check_captures() {
    python3 - "$OUTPUT/captures" "$DEVICES" "$LANGUAGES" "$SCREENSHOTS" <<'PY'
import sys, time
from pathlib import Path
root, devices, languages, count = Path(sys.argv[1]), sys.argv[2].split(","), sys.argv[3].split(","), int(sys.argv[4])
missing, times = [], []
for device in devices:
    for language in languages:
        for number in range(1, count + 1):
            file = root / device / language / f"{number:02d}.png"
            if file.is_file() and file.stat().st_size > 0:
                times.append(file.stat().st_mtime)
            else:
                missing.append(f"{device}/{language}/{number:02d}.png")
if missing:
    shown = ", ".join(missing[:12]) + (f" and {len(missing) - 12} more" if len(missing) > 12 else "")
    print(f"store-screenshots: the {count} captures of every device and language are needed in {root}, and these are missing: {shown}",
          file=sys.stderr)
    sys.exit(1)
stamp = lambda seconds: time.strftime("%Y-%m-%d %H:%M", time.localtime(seconds))
print(f"== composing the captures taken {stamp(min(times))}" + (f" to {stamp(max(times))}" if stamp(min(times)) != stamp(max(times)) else ""))
PY
}

# The captures a capture run will replace, removed before the first step that can fail: a run that fails on its way (a Mac
# that cannot make a simulator, a build that fails, a simulator that cannot be prepared) must not leave the captures of an
# earlier run for a later --compose-only to take for its own. Only the devices and languages asked for are touched.
clear_captures() {
    local device language
    for device in ${DEVICES//,/ }; do
        for language in ${LANGUAGES//,/ }; do
            rm -rf "$OUTPUT/captures/$device/$language" "$OUTPUT/captures/$device/$language.partial"
        done
    done
}

if [ "$COMPOSE_ONLY" -eq 0 ]; then
    clear_captures
    # Every simulator is found or made before the first one is erased: a Mac that cannot make the last one finds out now
    for device in ${DEVICES//,/ }; do simulator "$device" >/dev/null || exit $?; done
    for device in ${DEVICES//,/ }; do capture "$device"; done
fi
check_captures
swiftc -O -swift-version 6 -o "$WORK/compose-store-screenshots" "$ROOT/Tools/Release/compose-store-screenshots.swift"
"$WORK/compose-store-screenshots" "$LISTING" "$OUTPUT/captures" "$OUTPUT" "$DEVICES" "$LANGUAGES"
echo "== screenshots in $OUTPUT"
