#!/usr/bin/env bash
# Self-test of store-screenshots.sh. It runs the script with fake xcrun, xcodebuild and swiftc, which only record what they
# are asked to do, so that no simulator is touched. The script erases the simulators it uses, and must:
#   - erase only simulators whose name is reserved to it ("PrestoCV store ..."),
#   - refuse to run while another run holds the simulators and the work folder, and take over the lock of a run that ended,
#   - put the simulator back (status bar cleared, shut down) and release the lock on every way out: the end, a failure
#     and a signal.
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

BIN="$T/bin"; LOG="$T/calls.log"; DEVICES="$T/devices.json"
mkdir -p "$BIN" "$T/tmp"
export PATH="$BIN:$PATH" TMPDIR="$T/tmp" FAKE_LOG="$LOG" FAKE_DEVICES="$DEVICES"
LOCK="$TMPDIR/prestocv-store-screenshots/lock"

# The tools the script calls. xcrun records every call; the others make what the script reads from them.
cat > "$BIN/xcrun" <<'FAKE'
#!/usr/bin/env bash
echo "xcrun $*" >> "$FAKE_LOG"
case "$1 $2" in
    "simctl list")
        case "$3" in
            devices) cat "$FAKE_DEVICES" ;;
            devicetypes) echo '{"devicetypes":[{"name":"iPhone 17 Pro Max","identifier":"type-iphone"}]}' ;;
            runtimes) echo '{"runtimes":[{"platform":"iOS","isAvailable":true,"version":"27.0","identifier":"runtime-27"}]}' ;;
        esac ;;
    "simctl create") echo NEW-UDID ;;
    "simctl erase") [ "${FAKE_FAIL_ON:-}" != erase ] || exit 1 ;;
    "xcresulttool export")
        while [ $# -gt 0 ]; do [ "$1" != --output-path ] || { mkdir -p "$2"; echo '[]' > "$2/manifest.json"; }; shift; done ;;
esac
exit 0
FAKE
cat > "$BIN/xcodebuild" <<'FAKE'
#!/usr/bin/env bash
case " $* " in
    *" test-without-building "*)
        [ "${FAKE_SIGNAL:-}" != term ] || { kill -TERM "$PPID"; sleep 1; }
        while [ $# -gt 0 ]; do [ "$1" != -resultBundlePath ] || mkdir -p "$2"; shift; done ;;
esac
exit 0
FAKE
cat > "$BIN/swiftc" <<'FAKE'
#!/usr/bin/env bash
while [ $# -gt 0 ]; do [ "$1" != -o ] || { printf '#!/bin/sh\nexit 0\n' > "$2"; chmod +x "$2"; }; shift; done
FAKE
chmod +x "$BIN/xcrun" "$BIN/xcodebuild" "$BIN/swiftc"

# The simulators the Mac has: the one of the tool, and one of someone else's
write_devices() {
    printf '{"devices":{"runtime-27":[{"name":"PrestoCV store iphone","udid":"OWN-UDID"},{"name":"MyTests iphone","udid":"THEIR-UDID"}]}}' > "$DEVICES"
}

# run <environment assignments>... -- <arguments of the script>...; sets OUT and RC, and LOG holds the calls to xcrun
run() {
    local env=()
    while [ "$1" != -- ]; do env+=("$1"); shift; done; shift
    : > "$LOG"; write_devices
    OUT="$(env ${env[@]+"${env[@]}"} "$SCRIPT" --output "$T/out" --devices iphone --languages en "$@" 2>&1 < /dev/null)"; RC=$?
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
no_lock() { [ ! -e "$LOCK" ]; }

# 1. A run to the end erases its own simulator, puts it back, and leaves no lock
run -- --simulator-prefix "PrestoCV store"
expect "a run to the end" "exit $RC" [ "$RC" = 0 ]
expect "  erases its own simulator" "no erase of OWN-UDID" called "simctl erase OWN-UDID"
expect "  puts it back" "the last calls are not the clearing of the status bar and the shutdown" put_back OWN-UDID
expect "  leaves no lock" "$LOCK is left" no_lock

# 2. The name of the simulators is reserved to the tool: another name is refused before anything is erased
run -- --simulator-prefix "MyTests"
expect "a prefix that is not reserved" "exit $RC, want 2" [ "$RC" = 2 ]
expect "  erases nothing" "something was erased" not_called "simctl erase"
expect "  says why" "no mention of the reserved name" grep -qF "PrestoCV store" <<< "$OUT"
run -- --simulator-prefix "PrestoCV storefront"
expect "a prefix that only starts like the reserved name" "exit $RC, want 2" [ "$RC" = 2 ]

# 3. A run that holds the simulators and the work folder is not disturbed by another
sleep 60 & LIVE=$!
mkdir -p "$LOCK"; echo "$LIVE" > "$LOCK/pid"
run -- --simulator-prefix "PrestoCV store"
expect "a lock held by a run that is alive" "exit $RC, want 75" [ "$RC" = 75 ]
expect "  touches no simulator" "xcrun was called" [ ! -s "$LOG" ]
expect "  keeps the lock" "the lock of the other run is gone" [ -d "$LOCK" ]
kill "$LIVE" 2>/dev/null; wait "$LIVE" 2>/dev/null; LIVE=""

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

# 6. A signal (the fake test run terminates the script, as an interrupted run would be) does the same
run FAKE_SIGNAL=term -- --simulator-prefix "PrestoCV store"
expect "a signal during the test run" "exit $RC, want 143" [ "$RC" = 143 ]
expect "  puts the simulator back" "the last calls are not the clearing of the status bar and the shutdown" put_back OWN-UDID
expect "  leaves no lock" "$LOCK is left" no_lock

echo "store-screenshots-selftest: $pass passed, $fail failed"
[ "$fail" = 0 ]
