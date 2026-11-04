#!/usr/bin/env bash
# Self-test of store-screenshots.sh. It runs the script with fake xcrun, xcodebuild and swiftc, which only record what they
# are asked to do, so that no simulator is touched. The script erases the simulators it uses, and must:
#   - erase only simulators whose name is reserved to it ("PrestoCV store ..."),
#   - check its arguments before it takes the lock or touches a simulator,
#   - refuse to run while another run holds the simulators and the work folder, and take over the lock of a run that ended,
#     unless the capture of that run is still going,
#   - put the simulator back (status bar cleared, shut down) and release the lock on every way out: the end, a failure
#     and a signal, which stops the capture at once,
#   - leave no capture of an earlier run to be composed: a capture run starts by removing the captures it will replace,
#     so a run that fails at any step (the arguments' runtime, the build, the simulator, the test, the export) leaves none
#     of its languages, and --compose-only composes only a complete set; the captures of a language are put in place
#     whole, by a rename, so that a copy that fails leaves no file of that language; and a run that is killed (no chance to
#     clean up) leaves the captures of the languages it had finished, and none of the language it was in or of those after
#     it, so that a --compose-only accepts only a language that is whole,
#   - make a simulator that is not there yet on the newest iOS runtime that runs its device type, and refuse an --ios whose
#     runtime does not run it,
#   - run its tests where Xcode enforces their time allowance: the plan turns test timeouts on.
#
#   Tools/Release/store-screenshots-selftest.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/store-screenshots.sh"
T="$(mktemp -d)"
LIVE=""
cleanup() { [ -z "$LIVE" ] || kill "$LIVE" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT
pass=0; fail=0

BIN="$T/bin"; LOG="$T/calls.log"; COMPOSED="$T/composed.log"; DEVICES="$T/devices.json"; RUNTIMES="$T/runtimes.json"
mkdir -p "$BIN" "$T/tmp"
mkfifo "$T/block" "$T/ready"
export PATH="$BIN:$PATH" TMPDIR="$T/tmp" FAKE_LOG="$LOG" FAKE_COMPOSED="$COMPOSED" FAKE_DEVICES="$DEVICES" FAKE_BLOCK="$T/block"
export FAKE_RUNTIMES="$RUNTIMES"
LOCK="$TMPDIR/prestocv-store-screenshots/lock"
OUT_DIR="$T/out"

# The tools the script calls. xcrun records every call; the others make what the script reads from them.
cat > "$BIN/xcrun" <<'FAKE'
#!/usr/bin/env bash
echo "xcrun $*" >> "$FAKE_LOG"
case "$1 $2" in
    "simctl list")
        case "$3" in
            devices) cat "$FAKE_DEVICES" ;;
            devicetypes) echo '{"devicetypes":[{"name":"iPhone 17 Pro Max","identifier":"type-iphone"},{"name":"iPad Pro 13-inch (M5)","identifier":"type-ipad"}]}' ;;
            runtimes) cat "$FAKE_RUNTIMES" ;;
        esac ;;
    "simctl create")
        # simctl makes a device only on a runtime that lists its type: simctl create <name> <type> <runtime>
        python3 -c '
import json, sys
runtime = next(r for r in json.load(open(sys.argv[1]))["runtimes"] if r["identifier"] == sys.argv[3])
sys.exit(0 if any(t["identifier"] == sys.argv[2] for t in runtime["supportedDeviceTypes"]) else 1)' "$FAKE_RUNTIMES" "$4" "$5" \
            || { echo "An error was encountered processing the command (domain=com.apple.CoreSimulator.SimError, code=403): Incompatible device" >&2; exit 1; }
        echo NEW-UDID ;;
    "simctl erase") [ "${FAKE_FAIL_ON:-}" != erase ] || exit 1 ;;
    "xcresulttool export")
        # The screenshots the test attached: six, or FAKE_ATTACHMENTS of them, named <language>-NN as the test names them
        while [ $# -gt 0 ]; do
            case "$1" in --path) bundle="$2" ;; --output-path) out="$2" ;; esac
            shift
        done
        mkdir -p "$out"; language="$(cat "$bundle/language")"; entries=""
        for number in $(seq 1 "${FAKE_ATTACHMENTS:-6}"); do
            file="$(printf '%s-%02d.png' "$language" "$number")"; echo "png of $file" > "$out/$file"
            entries="$entries${entries:+,}{\"suggestedHumanReadableName\":\"$(printf '%s-%02d' "$language" "$number")_0_ABC.png\",\"exportedFileName\":\"$file\"}"
        done
        # FAKE_LOSE_FILE=N: the manifest names the Nth screenshot but its file is not there, so the copy fails half way
        [ -z "${FAKE_LOSE_FILE:-}" ] || rm -f "$out/$(printf '%s-%02d.png' "$language" "$FAKE_LOSE_FILE")"
        echo "[{\"attachments\":[$entries]}]" > "$out/manifest.json" ;;
esac
exit 0
FAKE
cat > "$BIN/xcodebuild" <<'FAKE'
#!/usr/bin/env bash
case " $* " in
    *" build-for-testing "*) [ "${FAKE_FAIL_ON:-}" != build ] || { echo "error: the build failed" >&2; exit 1; } ;;
    *" test-without-building "*)
        # The test needs the app's texts in its environment
        [ -n "${TEST_RUNNER_STORE_SCREENSHOT_STRINGS:-}" ] || { echo "no TEST_RUNNER_STORE_SCREENSHOT_STRINGS" >&2; exit 3; }
        language=""
        for argument in "$@"; do
            case "$argument" in
                -only-testing:*/testEnglish) language=en ;; -only-testing:*/testGerman) language=de ;;
            esac
        done
        while [ $# -gt 0 ]; do [ "$1" != -resultBundlePath ] || { mkdir -p "$2"; echo "$language" > "$2/language"; }; shift; done
        echo $$ > "${FAKE_CHILD_PID:-/dev/null}"
        # A signal reaches the script while the test runs: the test goes on for 5 s unless the script stops it. The test
        # misses the first TERM to its group, as a process does that forks at that very moment (it did on a Mac), so
        # that the script has to ask again
        [ "${FAKE_SIGNAL:-}" != term ] || { trap 'trap - TERM' TERM; kill -TERM "$PPID"; sleep 5; sleep 5; }
        # A test that is still running when the script is killed
        [ "${FAKE_HANG:-}" != 1 ] || { echo started > "$FAKE_READY"; read -t 60 <> "$FAKE_BLOCK"; }
        # The same, in the test of one language (FAKE_HANG_ON=de): the tests of the languages before it have ended
        [ -z "${FAKE_HANG_ON:-}" ] || [ "$FAKE_HANG_ON" != "$language" ] || { echo started > "$FAKE_READY"; read -t 60 <> "$FAKE_BLOCK"; }
        [ "${FAKE_FAIL_ON:-}" != test ] || exit 1 ;;
esac
exit 0
FAKE
# The composer the script builds: it only records that it ran, and with what
cat > "$BIN/swiftc" <<'FAKE'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do
    [ "$1" != -o ] || { printf '#!/bin/sh\necho "compose $*" >> "$FAKE_COMPOSED"\nexit 0\n' > "$2"; chmod +x "$2"; }
    shift
done
FAKE
chmod +x "$BIN/xcrun" "$BIN/xcodebuild" "$BIN/swiftc"

# The simulators the Mac has: the ones of the tool, and one of someone else's
write_devices() {
    printf '{"devices":{"runtime-27":[{"name":"PrestoCV store iphone","udid":"OWN-UDID"},{"name":"PrestoCV store ipad","udid":"OWN-IPAD-UDID"},{"name":"MyTests iphone","udid":"THEIR-UDID"}]}}' > "$DEVICES"
}
# runtime <identifier> <version> <device type>...: an available iOS runtime that runs those device types, as simctl lists it
runtime() {
    local identifier="$1" version="$2" types="" type; shift 2
    for type in "$@"; do types="$types${types:+,}{\"name\":\"$type\",\"identifier\":\"type-$type\"}"; done
    printf '{"platform":"iOS","isAvailable":true,"version":"%s","identifier":"%s","supportedDeviceTypes":[%s]}' \
        "$version" "$identifier" "$types"
}
# The runtimes the Mac has: one, that runs both devices
printf '{"runtimes":[%s]}' "$(runtime runtime-27 27.0 iphone ipad)" > "$RUNTIMES"

# run <environment assignments>... -- <arguments of the script>...; sets OUT, RC and TOOK (seconds), and LOG holds the calls to xcrun
run() {
    local env=()
    while [ "$1" != -- ]; do env+=("$1"); shift; done; shift
    : > "$LOG"; : > "$COMPOSED"; write_devices
    local began=$SECONDS
    OUT="$(env ${env[@]+"${env[@]}"} "$SCRIPT" --output "$OUT_DIR" --devices iphone --languages en "$@" 2>&1 < /dev/null)"; RC=$?
    TOOK=$((SECONDS - began))
}

# expect <name> <description of what failed> <test command...>
expect() {
    local name="$1" what="$2"; shift 2
    if "$@"; then pass=$((pass+1)); echo "ok   $name"; return; fi
    fail=$((fail+1)); echo "FAIL $name: $what"; sed 's/^/     /' <<< "$OUT"; sed 's/^/     calls: /' "$LOG"
}
called() { grep -qxF "xcrun $1" "$LOG"; }
not_called() { ! grep -qF "$1" "$LOG"; }
# The last two calls of a run that put the simulator back
put_back() { [ "$(tail -n 2 "$LOG")" = "$(printf 'xcrun simctl status_bar %s clear\nxcrun simctl shutdown %s' "$1" "$1")" ]; }
no_lock() { [ ! -e "$LOCK" ] && [ ! -e "$LOCK.takeover" ]; }
no_calls() { [ ! -s "$LOG" ]; }
composed() { [ -s "$COMPOSED" ]; }
not_composed() { [ ! -s "$COMPOSED" ]; }
says() { grep -qF -- "$1" <<< "$OUT"; }
# The captures of a language on a device, as the composer reads them
captures() { ls "$OUT_DIR/captures/$1/$2" 2>/dev/null | tr '\n' ' '; }
six="01.png 02.png 03.png 04.png 05.png 06.png "
# No half-made set of captures is left next to the sets: the copy of a language is made aside and renamed
no_partial() { [ -z "$(find "$OUT_DIR/captures" -name '*.partial' 2>/dev/null)" ]; }
# put_captures <device> <language> <count>: the captures of an earlier run
put_captures() {
    local dir="$OUT_DIR/captures/$1/$2" number
    mkdir -p "$dir"
    for number in $(seq 1 "$3"); do echo "old capture" > "$dir/$(printf '%02d' "$number").png"; done
}
# No capture of an earlier run (put_captures) is left, in any language
no_old_capture() { ! grep -rqF "old capture" "$OUT_DIR/captures" 2>/dev/null; }
# The process of a test that was left running is gone
gone() { ! kill -0 "$(cat "$1" 2>/dev/null)" 2>/dev/null; }

# 1. A run to the end erases its own simulator, puts it back, leaves no lock, and composes the six captures it took
rm -rf "$OUT_DIR"
run -- --simulator-prefix "PrestoCV store"
expect "a run to the end" "exit $RC" [ "$RC" = 0 ]
expect "  erases its own simulator" "no erase of OWN-UDID" called "simctl erase OWN-UDID"
expect "  puts it back" "the last calls are not the clearing of the status bar and the shutdown" put_back OWN-UDID
expect "  leaves no lock" "$LOCK is left" no_lock
expect "  exports the six screenshots" "the captures are: $(captures iphone en)" [ "$(captures iphone en)" = "$six" ]
expect "  leaves no half-made set" "a .partial is left" no_partial
expect "  composes them" "the composer did not run" composed
# simctl takes an ISO 8601 date-time with fractional seconds and reads it in the simulator's time zone, so that the offset must
# be the one of the Mac on that day: a date makes the iPad's bar the same in every capture, and 09:41 is the local time of it.
# The day is the one the composer writes again in each language (statusBarDay), so the two must agree.
COMPOSER="$HERE/compose-store-screenshots.swift"
DAY="$(sed -n 's/^let statusBarDay = "\([0-9-]*\)"$/\1/p' "$COMPOSER")"
expect "  the composer names the day of the status bar" "no statusBarDay in $COMPOSER" [ -n "$DAY" ]
fixed_clock() { grep -qE "^xcrun simctl status_bar OWN-UDID override --time ${DAY}T09:41:00\.000[+-][0-9]{2}:[0-9]{2} " "$LOG"; }
expect "  sets the clock to the composer's day at 9:41 local time" "the override has no ISO date-time at 09:41 on ${DAY:-?}" fixed_clock

# 2. The name of the simulators is reserved to the tool: another name is refused before anything is erased
run -- --simulator-prefix "MyTests"
expect "a prefix that is not reserved" "exit $RC, want 2" [ "$RC" = 2 ]
expect "  erases nothing" "something was erased" not_called "simctl erase"
expect "  says why" "no mention of the reserved name" says "PrestoCV store"
run -- --simulator-prefix "PrestoCV storefront"
expect "a prefix that only starts like the reserved name" "exit $RC, want 2" [ "$RC" = 2 ]

# 3. A run that holds the simulators and the work folder is not disturbed by another
sleep 60 & LIVE=$!
mkdir -p "$LOCK"; echo "$LIVE" > "$LOCK/pid"
run -- --simulator-prefix "PrestoCV store"
expect "a lock held by a run that is alive" "exit $RC, want 75" [ "$RC" = 75 ]
expect "  touches no simulator" "xcrun was called" no_calls
expect "  keeps the lock" "the lock of the other run is gone" [ -d "$LOCK" ]
kill "$LIVE" 2>/dev/null; { wait "$LIVE"; } 2>/dev/null; LIVE=""

# 4. The lock of a run that ended (killed without a chance to clean up) is taken over
( exit 0 ) & ended=$!; wait "$ended"
rm -rf "$LOCK"; mkdir -p "$LOCK"; echo "$ended" > "$LOCK/pid"
run -- --simulator-prefix "PrestoCV store"
expect "a lock left by a run that ended" "exit $RC" [ "$RC" = 0 ]
expect "  is released at the end" "$LOCK is left" no_lock

# 5. A failure on the way (the erase fails) still puts the simulator back and releases the lock
run FAKE_FAIL_ON=erase -- --simulator-prefix "PrestoCV store"
expect "a failure while the simulator is prepared" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  puts the simulator back" "the last calls are not the clearing of the status bar and the shutdown" put_back OWN-UDID
expect "  leaves no lock" "$LOCK is left" no_lock

# 6. A signal (the fake test run terminates the script, as an interrupted run would be) does the same, and stops the test
#    that is running at once: the fake test goes on for 5 s, and a script that waits for it to end has not stopped it
rm -f "$T/child.pid"
run FAKE_SIGNAL=term FAKE_CHILD_PID="$T/child.pid" -- --simulator-prefix "PrestoCV store"
expect "a signal during the test run" "exit $RC, want 143" [ "$RC" = 143 ]
expect "  puts the simulator back" "the last calls are not the clearing of the status bar and the shutdown" put_back OWN-UDID
expect "  leaves no lock" "$LOCK is left" no_lock
expect "  does not wait for the test to end" "the run took $TOOK s, and the test takes 5" [ "$TOOK" -lt 4 ]
expect "  stops the test" "the test $(cat "$T/child.pid" 2>/dev/null) is still running" gone "$T/child.pid"

# 7. The arguments are checked first: before the lock is taken, and before any simulator is touched
check_refused() {
    local name="$1" message="$2"; shift 2
    rm -rf "$LOCK"; run -- "$@"
    expect "$name" "exit $RC, want 2" [ "$RC" = 2 ]
    expect "  says why" "no mention of $message" says "$message"
    expect "  touches no simulator" "xcrun was called" no_calls
    expect "  takes no lock" "$LOCK is left" no_lock
}
check_refused "a listing that does not exist" "no-such-listing.md" --listing "$T/no-such-listing.md"
check_refused "  also to compose only" "no-such-listing.md" --compose-only --listing "$T/no-such-listing.md"
check_refused "a language that is not known" "xx" --languages en,xx
check_refused "no language at all" "languages" --languages ""
check_refused "a device that is not known" "tablet" --devices iphone,tablet
check_refused "a version of iOS that is not a number" "abc" --ios abc
check_refused "a missing value" "--output" --output
rm -rf "$LOCK"; run -- --ios 26
expect "an iOS that has no runtime on the Mac" "exit $RC, want 2" [ "$RC" = 2 ]
expect "  says why" "no mention of the version" says "iOS 26"
expect "  erases nothing" "something was erased" not_called "simctl erase"
expect "  leaves no lock" "$LOCK is left" no_lock
# A bad argument is refused as such while another run holds the lock, not turned away with the 75 of the lock
sleep 60 & LIVE=$!
rm -rf "$LOCK"; mkdir -p "$LOCK"; echo "$LIVE" > "$LOCK/pid"
run -- --languages xx
expect "a bad argument while another run holds the lock" "exit $RC, want 2" [ "$RC" = 2 ]
kill "$LIVE" 2>/dev/null; { wait "$LIVE"; } 2>/dev/null; LIVE=""; rm -rf "$LOCK"

# 8. A test that fails leaves no capture of an earlier run to be composed, exports none of its own, and ends the run:
#    the second device and the composer are skipped
rm -rf "$OUT_DIR"; put_captures iphone en 6
run FAKE_FAIL_ON=test -- --devices iphone,ipad
expect "a test that fails" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  leaves no capture of that language" "the captures are: $(captures iphone en)" [ -z "$(captures iphone en)" ]
expect "  does not compose" "the composer ran" not_composed
expect "  skips the second device" "the iPad was used" not_called "OWN-IPAD-UDID"
expect "  puts the simulator back" "the last calls are not the clearing of the status bar and the shutdown" put_back OWN-UDID
expect "  leaves no lock" "$LOCK is left" no_lock

# 9. A test that attached fewer than the six screenshots fails the run, and keeps none of them
rm -rf "$OUT_DIR"
run FAKE_ATTACHMENTS=5 -- --simulator-prefix "PrestoCV store"
expect "a test that attached five screenshots" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  says how many" "no mention of 5 of the 6" says "5 of the 6"
expect "  keeps none" "the captures are: $(captures iphone en)" [ -z "$(captures iphone en)" ]
expect "  leaves no half-made set" "a .partial is left" no_partial
expect "  does not compose" "the composer ran" not_composed
# The sixth screenshot is named by the result bundle but cannot be copied: the five before it are not kept
rm -rf "$OUT_DIR"; put_captures iphone en 6
run FAKE_LOSE_FILE=6 -- --simulator-prefix "PrestoCV store"
expect "a screenshot that cannot be copied" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  keeps none of the language's captures" "the captures are: $(captures iphone en)" [ -z "$(captures iphone en)" ]
expect "  leaves no half-made set" "a .partial is left" no_partial
expect "  does not compose" "the composer ran" not_composed
expect "  puts the simulator back" "the last calls are not the clearing of the status bar and the shutdown" put_back OWN-UDID

# 10. --compose-only composes a complete set of captures, and only that
rm -rf "$OUT_DIR"; put_captures iphone en 5
run -- --compose-only
expect "captures with the sixth missing" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  names the missing capture" "no mention of iphone/en/06.png" says "iphone/en/06.png"
expect "  does not compose" "the composer ran" not_composed
expect "  touches no simulator" "xcrun was called" no_calls
expect "  leaves no lock" "$LOCK is left" no_lock
put_captures iphone en 6
run -- --compose-only
expect "a complete set of captures" "exit $RC" [ "$RC" = 0 ]
expect "  composes them" "the composer did not run" composed
expect "  touches no simulator" "xcrun was called" no_calls
expect "  leaves no lock" "$LOCK is left" no_lock
# A language or a device that was not captured is asked for, and refused
run -- --compose-only --languages de
expect "a language without captures" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  does not compose" "the composer ran" not_composed
run -- --compose-only --devices iphone,ipad
expect "a device without captures" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  does not compose" "the composer ran" not_composed

# 11. After the script is killed (no chance to clean up) its capture keeps running, and the next run must not take the
#     simulator from it: the lock is taken over only when no capture of the dead run is left
rm -rf "$LOCK" "$OUT_DIR" "$T/child.pid"; write_devices
exec 7<>"$T/ready"
FAKE_HANG=1 FAKE_READY="$T/ready" FAKE_CHILD_PID="$T/child.pid" "$SCRIPT" --output "$OUT_DIR" --devices iphone --languages en \
    > /dev/null 2>&1 < /dev/null &
killed=$!
read -t 60 -u 7 started   # the capture has started
kill -9 "$killed"; { wait "$killed"; } 2>/dev/null
child="$(cat "$T/child.pid" 2>/dev/null)"
run -- --simulator-prefix "PrestoCV store"
expect "a capture of a run that was killed" "exit $RC, want 75" [ "$RC" = 75 ]
expect "  says that it is still running" "no mention of the capture $child" says "$child"
expect "  touches no simulator" "xcrun was called" no_calls
expect "  keeps the lock" "the lock is gone" [ -d "$LOCK" ]
kill "$child" 2>/dev/null
exec 7>&-
# The same lock, once the capture has ended too, is taken over
( exit 0 ) & ended=$!; wait "$ended"
echo "$ended" > "$LOCK/pid"; echo "$ended" > "$LOCK/child"
run -- --simulator-prefix "PrestoCV store"
expect "a lock whose capture has ended too" "exit $RC" [ "$RC" = 0 ]
expect "  is released at the end" "$LOCK is left" no_lock
# A takeover that is going on is not joined by a second one
mkdir -p "$LOCK" "$LOCK.takeover"; echo "$ended" > "$LOCK/pid"
run -- --simulator-prefix "PrestoCV store"
expect "a lock that another run is taking over" "exit $RC, want 75" [ "$RC" = 75 ]
expect "  touches no simulator" "xcrun was called" no_calls
rm -rf "$LOCK" "$LOCK.takeover"

# 12. A run that fails before its test has run (no runtime for --ios, the build, the preparation of the simulator) must not
#     leave the captures of an earlier run either: the run removes the captures it will replace before the first step that
#     can fail, and a --compose-only after it refuses. The captures of a language the run was not asked for are not its own.
failed_early() {
    local name="$1"; shift
    rm -rf "$OUT_DIR"; put_captures iphone en 6; put_captures iphone de 6
    run "$@"
    expect "$name" "exit $RC, want a failure" [ "$RC" != 0 ]
    expect "  leaves no capture of that language" "the captures are: $(captures iphone en)" [ -z "$(captures iphone en)" ]
    expect "  leaves the captures of another language" "the captures are: $(captures iphone de)" [ "$(captures iphone de)" = "$six" ]
    expect "  leaves no half-made set" "a .partial is left" no_partial
    expect "  leaves no lock" "$LOCK is left" no_lock
    run -- --compose-only
    expect "  and a --compose-only after it" "exit $RC, want a failure" [ "$RC" != 0 ]
    expect "    does not compose" "the composer ran" not_composed
}
failed_early "a Mac with no runtime of the iOS asked for" -- --ios 26
failed_early "a build that fails" FAKE_FAIL_ON=build --
failed_early "a simulator that cannot be prepared" FAKE_FAIL_ON=erase --
# A run that only composes removes nothing
rm -rf "$OUT_DIR"; put_captures iphone en 6
run -- --compose-only
expect "a --compose-only run" "exit $RC" [ "$RC" = 0 ]
expect "  keeps the captures" "the captures are: $(captures iphone en)" [ "$(captures iphone en)" = "$six" ]

# 13. A run that is killed (no chance to clean up) while it captures leaves the captures of the languages it had finished,
#     and none of the language it was in, or of those after it, however old: the captures of the earlier run were removed
#     when the run began, and a language is put in place whole, by a rename. A --compose-only after it accepts the
#     languages that are whole, and refuses the others.
killed_in() {
    local name="$1" language="$2"
    rm -rf "$LOCK" "$OUT_DIR" "$T/child.pid"; write_devices
    put_captures iphone en 6; put_captures iphone de 6
    exec 7<>"$T/ready"
    FAKE_HANG_ON="$language" FAKE_READY="$T/ready" FAKE_CHILD_PID="$T/child.pid" \
        "$SCRIPT" --output "$OUT_DIR" --devices iphone --languages en,de > /dev/null 2>&1 < /dev/null &
    killed=$!
    read -t 60 -u 7 started   # the test of the language has started
    kill -9 "$killed"; { wait "$killed"; } 2>/dev/null
    kill "$(cat "$T/child.pid" 2>/dev/null)" 2>/dev/null
    exec 7>&-
    rm -rf "$LOCK"
    OUT="the run was killed while it captured $language"
    expect "$name: no capture of the earlier run is left" "the captures are: en $(captures iphone en), de $(captures iphone de)" \
        no_old_capture
    expect "  leaves no half-made set" "a .partial is left" no_partial
}
killed_in "a run killed during its first language" en
expect "  leaves no capture of that language" "the captures are: $(captures iphone en)" [ -z "$(captures iphone en)" ]
expect "  leaves none of the language after it" "the captures are: $(captures iphone de)" [ -z "$(captures iphone de)" ]
run -- --compose-only --languages en,de
expect "  and a --compose-only after it" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "    does not compose" "the composer ran" not_composed
killed_in "a run killed during its second language" de
expect "  keeps the first language, as that run took it" "the captures are: $(captures iphone en)" [ "$(captures iphone en)" = "$six" ]
expect "  they are not those of the earlier run" "$(cat "$OUT_DIR/captures/iphone/en/01.png")" grep -q "png of en-01.png" "$OUT_DIR/captures/iphone/en/01.png"
expect "  leaves no capture of the language it was in" "the captures are: $(captures iphone de)" [ -z "$(captures iphone de)" ]
run -- --compose-only --languages en,de
expect "  a --compose-only for both languages after it" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "    names a missing capture of the second" "no mention of iphone/de/01.png" says "iphone/de/01.png"
expect "    does not compose" "the composer ran" not_composed
run -- --compose-only --languages en
expect "  a --compose-only for the language that is whole" "exit $RC" [ "$RC" = 0 ]
expect "    composes it" "the composer did not run" composed

# 14. A simulator that is not there yet is made on the newest iOS runtime that runs its device type. An Xcode can bring a
#     newer runtime that runs only some devices: Xcode 27.2 has iOS 27.1, which runs only the iPhone Duo, and simctl will not
#     make an iPhone 17 Pro Max on it ("Incompatible device"). An --ios whose runtime does not run the device is refused.
printf '{"runtimes":[%s,%s,%s]}' "$(runtime runtime-26-5 26.5 iphone ipad)" "$(runtime runtime-27-0 27.0 iphone ipad)" \
    "$(runtime runtime-27-1 27.1 duo)" > "$T/runtimes-xcode-27.2.json"
printf '{"runtimes":[%s]}' "$(runtime runtime-27-1 27.1 duo)" > "$T/runtimes-duo-only.json"
XCODE_27_2="FAKE_RUNTIMES=$T/runtimes-xcode-27.2.json"
# A prefix no simulator carries yet, so that the run makes its simulator
NEW=(--simulator-prefix "PrestoCV store new")
rm -rf "$LOCK" "$OUT_DIR"
run "$XCODE_27_2" -- "${NEW[@]}"
expect "a newest runtime that does not run the device" "exit $RC" [ "$RC" = 0 ]
expect "  makes the simulator on the newest one that does" "no simctl create on runtime-27-0" \
    called "simctl create PrestoCV store new iphone type-iphone runtime-27-0"
expect "  and not on the newest" "a simctl call names runtime-27-1" not_called "runtime-27-1"
run "$XCODE_27_2" -- "${NEW[@]}" --ios 27
expect "an --ios of two runtimes, the newer of which does not run the device" "exit $RC" [ "$RC" = 0 ]
expect "  makes the simulator on the one that does" "no simctl create on runtime-27-0" \
    called "simctl create PrestoCV store new iphone (iOS 27) type-iphone runtime-27-0"
run "$XCODE_27_2" -- "${NEW[@]}" --ios 27.1
expect "an --ios whose runtime does not run the device" "exit $RC, want 2" [ "$RC" = 2 ]
expect "  says why" "no mention of iOS 27.1" says "iOS 27.1"
expect "  names the device" "no mention of the iPhone 17 Pro Max" says "iPhone 17 Pro Max"
expect "  names the runtimes that run it" "no mention of 26.5 and 27.0" says "26.5, 27.0"
expect "  makes no simulator" "simctl create was called" not_called "simctl create"
expect "  erases nothing" "something was erased" not_called "simctl erase"
expect "  leaves no lock" "$LOCK is left" no_lock
run "FAKE_RUNTIMES=$T/runtimes-duo-only.json" -- "${NEW[@]}"
expect "a Mac with no runtime that runs the device" "exit $RC, want 1" [ "$RC" = 1 ]
expect "  says why" "no mention of the iPhone 17 Pro Max" says "iPhone 17 Pro Max"
expect "  makes no simulator" "simctl create was called" not_called "simctl create"
expect "  erases nothing" "something was erased" not_called "simctl erase"
expect "  leaves no lock" "$LOCK is left" no_lock
run "FAKE_RUNTIMES=$T/runtimes-duo-only.json" -- "${NEW[@]}" --ios 27.1
expect "an --ios whose runtime does not run the device, on a Mac where none does" "exit $RC, want 2" [ "$RC" = 2 ]
expect "  says that no other runtime runs it" "no mention of the other runtimes" says "no other iOS runtime of this Mac does"
expect "  makes no simulator" "simctl create was called" not_called "simctl create"

# The test sets a time allowance for each language, and Xcode enforces it only where the plan turns test timeouts on
PLAN="$HERE/../../TestPlans/StoreScreenshots.xctestplan"
expect "the StoreScreenshots plan" "does not turn test timeouts on, so a test that hangs is never ended" grep -q '"testTimeoutsEnabled" : true' "$PLAN"

# The composer writes the iPad's date again in the language of each locale, and refuses a language it has no date for: every
# language of the listing has one
LISTING="$HERE/../../docs/release/store-listing.md"
listed_languages() { sed -n 's/^## .*, \([a-z][a-z]\)\(-[A-Z][A-Z]\)\{0,1\}$/\1/p' "$LISTING" | sort -u; }
dated_languages() { sed -n '/^let statusBarDates/,/^]/s/^    "\([a-z][a-z]\)": ".*",$/\1/p' "$COMPOSER" | sort -u; }
undated() { comm -23 <(listed_languages) <(dated_languages); }
all_dated() { [ -n "$(listed_languages)" ] && [ -z "$(undated)" ]; }
expect "the languages of the listing" "the composer has no status bar date for: $(undated | tr '\n' ' ')" all_dated
# The dates are of the day the clock is set to: each names its day of the month, and the English one, in the device's
# format (EEE MMM d), is that day's
date_of() { sed -n "/^let statusBarDates/,/^]/s/^    \"$1\": \"\(.*\)\",\$/\1/p" "$COMPOSER"; }
english_day() {
    LC_ALL=C python3 -I -c 'import datetime, sys; day = datetime.date.fromisoformat(sys.argv[1])
print(day.strftime("%a %b ") + str(day.day))' "$DAY"
}
without_the_day() {
    local language
    [ -n "$DAY" ] || return 0
    for language in $(dated_languages); do
        [[ " $(date_of "$language" | tr -d .) " == *" $((10#${DAY##*-})) "* ]] || echo "$language"
    done
}
days_named() { [ -n "$DAY" ] && [ -n "$(dated_languages)" ] && [ -z "$(without_the_day)" ]; }
expect "  each names the day of the month of ${DAY:-?}" "these do not: $(without_the_day | tr '\n' ' ')" days_named
expect "  the English one is that day" "the English date is \"$(date_of en)\", ${DAY:-?} is \"$(english_day)\"" \
    [ "$(date_of en)" = "$(english_day)" ]

echo "store-screenshots-selftest: $pass passed, $fail failed"
[ "$fail" = 0 ]
