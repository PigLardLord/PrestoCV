#!/usr/bin/env bash
# Self-test of compose-store-screenshots.swift, on a Mac (it uses CoreGraphics). The composer puts the nth caption of a
# locale on the nth capture, and the images it writes are what is uploaded, so it must:
#   - refuse a locale that has not exactly six captions, before it writes anything: with one caption short, the others
#     would sit over the wrong screens,
#   - refuse a capture that is not the size of the device's screen: it would be stretched or cut,
#   - replace the folder of a locale and device as a whole, so that an image of an earlier run is never left in it,
#   - write nothing of a locale when one of its captures is missing,
#   - leave the output as it was when a run fails at any step, even after it has composed a locale or a device: it makes
#     the whole output aside and puts it in place at the end, so that a missing capture of a later locale or device, a
#     write that fails and a folder that cannot be replaced leave the earlier set whole, with no half-made folder next to it.
#
#   Tools/Release/compose-store-screenshots-selftest.sh
set -u
if [ "$(uname)" != Darwin ]; then
    echo "compose-store-screenshots-selftest: skipped, it needs CoreGraphics (macOS)"
    exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
pass=0; fail=0
swiftc -O -swift-version 6 -o "$T/compose" "$HERE/compose-store-screenshots.swift" 2>"$T/swiftc.log" \
    || { cat "$T/swiftc.log"; echo "compose-store-screenshots-selftest: the composer does not compile"; exit 1; }

# A plain PNG of a size, as the simulator takes it: <width> <height> <file>
png() {
    python3 - "$@" <<'PY'
import struct, sys, zlib
width, height, path = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
def chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))
row = b"\x00" + bytes([0xF0, 0xF0, 0xF0]) * width
with open(path, "wb") as out:
    out.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
              + chunk(b"IDAT", zlib.compress(row * height)) + chunk(b"IEND", b""))
PY
}

# A listing with the captions of one locale: <file> <caption>...
listing() {
    local file="$1"; shift
    { printf '## English, en-US\n\n### Screenshot captions\n\n```text\n'; printf '%s\n' "$@"; printf '```\n'; } > "$file"
}

SIX=("One. | The first." "Two. | The second." "Three. | The third." "Four. | The fourth." "Five. | The fifth." "Six. | The sixth.")

# captures_for <dir> <device> <language> <width> <height> <count>: the captures of a language on a device
captures_for() {
    local dir="$1/$2/$3" number
    mkdir -p "$dir"
    for number in $(seq 1 "$6"); do png "$4" "$5" "$dir/$(printf '%02d' "$number").png"; done
}
# captures <dir> <width> <height> <count>: the captures of the iphone in English
captures() { captures_for "$1" iphone en "$2" "$3" "$4"; }

# compose <name>: runs the composer on $T/listing.md and $T/captures into $T/out; sets OUT and RC
compose() {
    OUT="$("$T/compose" "$T/listing.md" "$T/captures" "$T/out" iphone en 2>&1)"; RC=$?
}

# expect <name> <what failed> <test command...>
expect() {
    local name="$1" what="$2"; shift 2
    if "$@"; then pass=$((pass+1)); echo "ok   $name"; return; fi
    fail=$((fail+1)); echo "FAIL $name: $what"; sed 's/^/     /' <<< "$OUT"
}
folder_holds() { [ "$(ls "$T/out/en-US/iphone" 2>/dev/null | tr '\n' ' ')" = "$1" ]; }
# No folder of a run is left in the output: the one it makes the output in, and the one it moves what it replaces to
no_leftovers() { [ ! -e "$T/out/.compose-staging" ] && [ ! -e "$T/out/.compose-previous" ]; }
# Nothing was written: the output holds no file (it may be there, empty), and no folder of a run
nothing_written() { [ -z "$(find "$T/out" -type f 2>/dev/null)" ] && no_leftovers; }
# The files of the output, hidden ones too, each with its checksum: the output as it is
tree_of() { ( cd "$T/out" 2>/dev/null && find . -type f | LC_ALL=C sort | while read -r file; do printf '%s %s\n' "$(cksum < "$file")" "$file"; done ); }

# 1. Six captions and six captures of the screen's size: six images, and the contact sheet
rm -rf "$T/captures" "$T/out"; listing "$T/listing.md" "${SIX[@]}"; captures "$T/captures" 1320 2868 6
compose
expect "six captions and six captures" "exit $RC" [ "$RC" = 0 ]
expect "  writes six images" "the folder holds: $(ls "$T/out/en-US/iphone" 2>&1 | tr '\n' ' ')" folder_holds "01.png 02.png 03.png 04.png 05.png 06.png "
expect "  writes the contact sheet" "no contact sheet" [ -s "$T/out/contact-sheet-iphone.png" ]
expect "  leaves no folder of the run" "$(ls -A "$T/out")" no_leftovers

# 2. An image of an earlier run is not left in the folder: the folder is replaced as a whole
touch "$T/out/en-US/iphone/07.png" "$T/out/en-US/iphone/old.png"
compose
expect "a folder with images of an earlier run" "exit $RC" [ "$RC" = 0 ]
expect "  holds only the six images" "the folder holds: $(ls "$T/out/en-US/iphone" 2>&1 | tr '\n' ' ')" folder_holds "01.png 02.png 03.png 04.png 05.png 06.png "
expect "  leaves no folder of the run" "$(ls -A "$T/out")" no_leftovers

# 3. Five captions, or seven, are refused before anything is written
for count in 5 7; do
    rm -rf "$T/out"
    if [ "$count" = 5 ]; then listing "$T/listing.md" "${SIX[@]:0:5}"; else listing "$T/listing.md" "${SIX[@]}" "Seven. | The seventh."; fi
    compose
    expect "$count captions" "exit $RC, want a failure" [ "$RC" != 0 ]
    expect "  names the locale and the count" "the message is: $OUT" grep -q "en-US.*exactly 6" <<< "$OUT"
    expect "  writes nothing" "$(find "$T/out" 2>&1)" nothing_written
done

# 4. A capture that is not the size of the screen is refused, and nothing is written
rm -rf "$T/captures" "$T/out"; listing "$T/listing.md" "${SIX[@]}"; captures "$T/captures" 1320 2868 6
png 1206 2622 "$T/captures/iphone/en/04.png"
compose
expect "a capture of another size" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  names the file and the sizes" "the message is: $OUT" grep -q "04.png.*1206 x 2622.*1320 x 2868" <<< "$OUT"
expect "  writes nothing" "$(find "$T/out" 2>&1)" nothing_written

# 5. A missing capture: no image of the locale is written, not even those of the captures that are there
rm -rf "$T/captures" "$T/out"; captures "$T/captures" 1320 2868 5
compose
expect "a missing capture" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  writes nothing" "$(find "$T/out" 2>&1)" nothing_written

# A listing of two locales, English and German, whose captions are the same six
two_locales() {
    listing "$T/listing.md" "${SIX[@]}"
    { printf '\n## German, de-DE\n\n### Screenshot captions\n\n```text\n'; printf '%s\n' "${SIX[@]}"; printf '```\n'; } >> "$T/listing.md"
}
# compose_all <devices>: runs the composer on every locale of $T/listing.md; sets OUT and RC
compose_all() {
    OUT="$("$T/compose" "$T/listing.md" "$T/captures" "$T/out" "$1" 2>&1)"; RC=$?
}
# An output of an earlier run: both locales on the iphone, a contact sheet, and a mark in each folder and on the sheet
# that only the earlier run could have left
earlier_run() {
    rm -rf "$T/captures" "$T/out"; two_locales
    captures_for "$T/captures" iphone en 1320 2868 6; captures_for "$T/captures" iphone de 1320 2868 6
    "$T/compose" "$T/listing.md" "$T/captures" "$T/out" iphone > /dev/null 2>&1 || echo "the earlier run failed"
    echo "earlier run" > "$T/out/en-US/iphone/07.png"; echo "earlier run" > "$T/out/de-DE/iphone/07.png"
    echo "earlier sheet" > "$T/out/contact-sheet-iphone.png"
    BEFORE="$(tree_of)"
}
unchanged() { [ "$(tree_of)" = "$BEFORE" ]; }

# 6. A run that fails after it has composed a locale (or a device) leaves the output of the earlier run as it was: nothing
#    is replaced before everything is made
earlier_run; rm "$T/captures/iphone/de/06.png"
compose_all iphone
expect "a second locale with a capture missing" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  names the capture" "the message is: $OUT" grep -q "iphone/de/06.png" <<< "$OUT"
expect "  leaves the output as it was" "$(diff <(echo "$BEFORE") <(tree_of))" unchanged
expect "  leaves no folder of the run" "$(ls -A "$T/out")" no_leftovers
earlier_run
compose_all iphone,ipad
expect "a second device without captures" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  leaves the output as it was, the contact sheet too" "$(diff <(echo "$BEFORE") <(tree_of))" unchanged
expect "  leaves no folder of the run" "$(ls -A "$T/out")" no_leftovers

# 7. A folder that cannot be replaced (a file is where the folder of the second locale goes) fails the run at the very end,
#    when the first locale is already in place: it is put back
earlier_run; rm -rf "$T/out/de-DE"; echo "in the way" > "$T/out/de-DE"; BEFORE="$(tree_of)"
compose_all iphone
expect "a folder that cannot be replaced" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  says that the output is as it was" "the message is: $OUT" grep -q "as it was" <<< "$OUT"
expect "  leaves the output as it was" "$(diff <(echo "$BEFORE") <(tree_of))" unchanged
expect "  leaves no folder of the run" "$(ls -A "$T/out")" no_leftovers

# 8. A write that fails (the size of a file is limited, and the limit is met by the first image) leaves the output as it was
earlier_run
OUT="$( ( ulimit -f 16; trap '' XFSZ; exec "$T/compose" "$T/listing.md" "$T/captures" "$T/out" iphone ) 2>&1 )"; RC=$?
expect "a write that fails" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  leaves the output as it was" "$(diff <(echo "$BEFORE") <(tree_of))" unchanged
expect "  leaves no folder of the run" "$(ls -A "$T/out")" no_leftovers

# 9. The folder a run that was killed left to make its output in is not mistaken for anything: the next run clears it
earlier_run; mkdir -p "$T/out/.compose-staging/en-US/iphone"; echo "half" > "$T/out/.compose-staging/en-US/iphone/01.png"
compose_all iphone
expect "a staging folder left by a run that was killed" "exit $RC" [ "$RC" = 0 ]
expect "  leaves no folder of the run" "$(ls -A "$T/out")" no_leftovers
expect "  holds only the six images" "the folder holds: $(ls "$T/out/en-US/iphone" 2>&1 | tr '\n' ' ')" folder_holds "01.png 02.png 03.png 04.png 05.png 06.png "

# 10. What an earlier run could not put back (.compose-previous) is not written over: the run refuses
earlier_run; mkdir -p "$T/out/.compose-previous/en-US"; echo "kept" > "$T/out/.compose-previous/en-US/iphone"; BEFORE="$(tree_of)"
compose_all iphone
expect "what an earlier run could not put back" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  names the folder" "the message is: $OUT" grep -q ".compose-previous" <<< "$OUT"
expect "  leaves everything as it was" "$(diff <(echo "$BEFORE") <(tree_of))" unchanged
expect "  leaves no staging folder" "$(ls -A "$T/out")" [ ! -e "$T/out/.compose-staging" ]

echo "compose-store-screenshots-selftest: $pass passed, $fail failed"
[ "$fail" = 0 ]
