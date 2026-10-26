#!/usr/bin/env bash
# Self-test of compose-store-screenshots.swift, on a Mac (it uses CoreGraphics). The composer puts the nth caption of a
# locale on the nth capture, and the images it writes are what is uploaded, so it must:
#   - refuse a locale that has not exactly six captions, before it writes anything: with one caption short, the others
#     would sit over the wrong screens,
#   - refuse a capture that is not the size of the device's screen: it would be stretched or cut,
#   - replace the folder of a locale and device as a whole, so that an image of an earlier run is never left in it,
#   - write nothing of a locale when one of its captures is missing.
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

# captures <dir> <width> <height> <count>: the captures of the iphone in English
captures() {
    local dir="$1/iphone/en" number
    mkdir -p "$dir"
    for number in $(seq 1 "$4"); do png "$2" "$3" "$dir/$(printf '%02d' "$number").png"; done
}

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

# 1. Six captions and six captures of the screen's size: six images, and the contact sheet
rm -rf "$T/captures" "$T/out"; listing "$T/listing.md" "${SIX[@]}"; captures "$T/captures" 1320 2868 6
compose
expect "six captions and six captures" "exit $RC" [ "$RC" = 0 ]
expect "  writes six images" "the folder holds: $(ls "$T/out/en-US/iphone" 2>&1 | tr '\n' ' ')" folder_holds "01.png 02.png 03.png 04.png 05.png 06.png "
expect "  writes the contact sheet" "no contact sheet" [ -s "$T/out/contact-sheet-iphone.png" ]

# 2. An image of an earlier run is not left in the folder: the folder is replaced as a whole
touch "$T/out/en-US/iphone/07.png" "$T/out/en-US/iphone/old.png"
compose
expect "a folder with images of an earlier run" "exit $RC" [ "$RC" = 0 ]
expect "  holds only the six images" "the folder holds: $(ls "$T/out/en-US/iphone" 2>&1 | tr '\n' ' ')" folder_holds "01.png 02.png 03.png 04.png 05.png 06.png "

# 3. Five captions, or seven, are refused before anything is written
for count in 5 7; do
    rm -rf "$T/out"
    if [ "$count" = 5 ]; then listing "$T/listing.md" "${SIX[@]:0:5}"; else listing "$T/listing.md" "${SIX[@]}" "Seven. | The seventh."; fi
    compose
    expect "$count captions" "exit $RC, want a failure" [ "$RC" != 0 ]
    expect "  names the locale and the count" "the message is: $OUT" grep -q "en-US.*exactly 6" <<< "$OUT"
    expect "  writes nothing" "$(ls "$T/out" 2>&1)" [ ! -e "$T/out" ]
done

# 4. A capture that is not the size of the screen is refused, and nothing is written
rm -rf "$T/captures" "$T/out"; listing "$T/listing.md" "${SIX[@]}"; captures "$T/captures" 1320 2868 6
png 1206 2622 "$T/captures/iphone/en/04.png"
compose
expect "a capture of another size" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  names the file and the sizes" "the message is: $OUT" grep -q "04.png.*1206 x 2622.*1320 x 2868" <<< "$OUT"
expect "  writes nothing" "$(ls "$T/out" 2>&1)" [ ! -e "$T/out" ]

# 5. A missing capture: no image of the locale is written, not even those of the captures that are there
rm -rf "$T/captures" "$T/out"; captures "$T/captures" 1320 2868 5
compose
expect "a missing capture" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  writes nothing" "$(ls "$T/out" 2>&1)" [ ! -e "$T/out" ]

echo "compose-store-screenshots-selftest: $pass passed, $fail failed"
[ "$fail" = 0 ]
