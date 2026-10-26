#!/usr/bin/env bash
# Self-test of store-screenshots.sh. It runs the script with fake xcrun, xcodebuild and swiftc, which only record what they
# are asked to do, so that no simulator is touched. The script erases the simulators it uses, and must:
#   - erase only simulators whose name is reserved to it ("PrestoCV store ..."),
#   - check its arguments before it takes the lock or touches a simulator,
#   - refuse to run while another run holds the simulators and the work folder, and take over the lock of a run that ended,
#     unless the capture of that run is still going,
#   - put the simulator back (status bar cleared, shut down) and release the lock on every way out: the end, a failure
#     and a signal, which stops the capture at once,
#   - leave no capture of an earlier run to be composed: a language whose test failed has none, and --compose-only
#     composes only a complete set.
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

BIN="$T/bin"; LOG="$T/calls.log"; COMPOSED="$T/composed.log"; DEVICES="$T/devices.json"
mkdir -p "$BIN" "$T/tmp"
mkfifo "$T/block" "$T/ready"
export PATH="$BIN:$PATH" TMPDIR="$T/tmp" FAKE_LOG="$LOG" FAKE_COMPOSED="$COMPOSED" FAKE_DEVICES="$DEVICES" FAKE_BLOCK="$T/block"
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
            runtimes) echo '{"runtimes":[{"platform":"iOS","isAvailable":true,"version":"27.0","identifier":"runtime-27"}]}' ;;
        esac ;;
    "simctl create") echo NEW-UDID ;;
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
        echo "[{\"attachments\":[$entries]}]" > "$out/manifest.json" ;;
esac
exit 0
FAKE
cat > "$BIN/xcodebuild" <<'FAKE'
#!/usr/bin/env bash
case " $* " in
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
# put_captures <device> <language> <count>: the captures of an earlier run
put_captures() {
    local dir="$OUT_DIR/captures/$1/$2" number
    mkdir -p "$dir"
    for number in $(seq 1 "$3"); do echo "old capture" > "$dir/$(printf '%02d' "$number").png"; done
}
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
expect "  composes them" "the composer did not run" composed

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
expect "  does not compose" "the composer ran" not_composed

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

echo "store-screenshots-selftest: $pass passed, $fail failed"
[ "$fail" = 0 ]
