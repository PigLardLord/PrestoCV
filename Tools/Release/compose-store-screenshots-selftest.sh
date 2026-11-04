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
#     write that fails and a folder that cannot be replaced leave the earlier set whole, with no half-made folder next to it,
#   - never take for whole a set that a run was killed while it put in place, also when there was no earlier output (an
#     empty output folder): the file it writes before the first move, and removes after the last, makes the next run
#     refuse, at every point of the promotion, the first move, the last move and before any move (the kill is the
#     composer's COMPOSE_TEST_KILL_AFTER_MOVE hook, which does nothing when it is not set),
#   - write the date of the iPad's status bar again in the language of each locale, which the simulator writes in English,
#     and change nothing else of the image, and refuse, before it writes anything, a capture whose bar is not the time,
#     the date and the name on a plain background, and a language whose date it does not have.
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

# A plain PNG of a size, as the simulator takes it: <width> <height> <file> [bar | bar-on-a-mark | bar-of-four |
# bar-long-name]. With "bar" it has the iPad's status bar where the simulator puts it: the time, the date and the app's
# name, each a black block; with "bar-on-a-mark" also a mark right of the name, too faint to be text, on what must be a
# plain background; with "bar-of-four" a fourth item after the name; with "bar-long-name" a name that reaches nearly to
# the end of the share of the width the composer searches (x 825 of 2064), so that it cannot move right. That name is thin
# strokes, as letters are: a block so long would make the colour of most of the row black, and the bar's background with it
png() {
    python3 - "$@" <<'PY'
import struct, sys, zlib
width, height, path = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
bar = sys.argv[4] if len(sys.argv) > 4 else ""
def chunk(kind, data):
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))
plain = bytearray(b"\x00" + bytes([0xF0, 0xF0, 0xF0]) * width)
rows = [bytes(plain)] * height
if bar:
    text = bytearray(plain)
    blocks = [(51, 122, 1), (147, 275, 1), (299, 820, 3) if bar == "bar-long-name" else (299, 427, 1)]
    if bar == "bar-of-four":
        blocks.append((451, 520, 1))
    for start, end, step in blocks:
        for x in range(start, end, step):
            text[1 + 3 * x:4 + 3 * x] = bytes(3)
    rows[22:42] = [bytes(text)] * 20
    if bar == "bar-on-a-mark":
        marked = bytearray(text)
        marked[1 + 3 * 600:1 + 3 * 610] = bytes([0xE8]) * 30
        rows[30] = bytes(marked)
with open(path, "wb") as out:
    out.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
              + chunk(b"IDAT", zlib.compress(b"".join(rows))) + chunk(b"IEND", b""))
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
# Nothing of a run is left in the output: the folder it makes the output in, the one it moves what it replaces to, and the
# file that says it is putting the output in place
no_leftovers() {
    [ ! -e "$T/out/.compose-staging" ] && [ ! -e "$T/out/.compose-previous" ] && [ ! -e "$T/out/.compose-promoting" ]
}
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

# 10. What an earlier run could not put back (.compose-previous) is not written over, also when the file that says a run
#     was putting the output in place is gone: the run refuses
earlier_run; mkdir -p "$T/out/.compose-previous/en-US"; echo "kept" > "$T/out/.compose-previous/en-US/iphone"; BEFORE="$(tree_of)"
compose_all iphone
expect "what an earlier run could not put back" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  names the folder" "the message is: $OUT" grep -q ".compose-previous" <<< "$OUT"
expect "  leaves everything as it was" "$(diff <(echo "$BEFORE") <(tree_of))" unchanged
expect "  leaves no staging folder" "$(ls -A "$T/out")" [ ! -e "$T/out/.compose-staging" ]

# 11. A run that is killed while it puts the output in place leaves a set that may be whole in part only, and the next run
#     must not take it for a whole one: not in an empty output folder (nothing was moved aside, so there is no
#     .compose-previous to say so), and not when it replaces an earlier set. The file that says so is written before the
#     first move and removed after the last, so every point of the promotion is tried: <n> is the move after which the
#     run is killed, 0 for before the first move; one move more than there are is a run that is not killed.
# compose_killed <n>: runs the composer on every locale and kills it after its nth move into place; sets OUT and RC
compose_killed() {
    { OUT="$(COMPOSE_TEST_KILL_AFTER_MOVE="$1" "$T/compose" "$T/listing.md" "$T/captures" "$T/out" iphone 2>&1)"; RC=$?; } 2>/dev/null
}
# An empty output folder: the captures, and no output
empty_output() {
    rm -rf "$T/captures" "$T/out"; two_locales
    captures_for "$T/captures" iphone en 1320 2868 6; captures_for "$T/captures" iphone de 1320 2868 6
    mkdir -p "$T/out"
}
# Both locales and the contact sheet are made: the folders hold the six images, and the sheet is the composer's
whole_set() {
    folder_holds "01.png 02.png 03.png 04.png 05.png 06.png " \
        && [ "$(ls "$T/out/de-DE/iphone" 2>/dev/null | tr '\n' ' ')" = "01.png 02.png 03.png 04.png 05.png 06.png " ] \
        && [ "$(wc -c < "$T/out/contact-sheet-iphone.png" | tr -d ' ')" -gt 1000 ]
}
# killed_at_every_move <what> <setup function> <moves the promotion makes>
killed_at_every_move() {
    local what="$1" setup="$2" moves="$3" n
    for n in $(seq 0 "$moves"); do
        "$setup"
        compose_killed "$n"
        expect "$what, killed after move $n" "exit $RC, want 137 (killed)" [ "$RC" = 137 ]
        expect "  leaves the file that says it was putting the output in place" "$(ls -A "$T/out")" [ -f "$T/out/.compose-promoting" ]
        # Into an empty folder nothing is set aside: the file is all the evidence there is of the promotion
        [ "$setup" != empty_output ] || expect "  sets nothing aside" "$(ls -A "$T/out")" [ ! -e "$T/out/.compose-previous" ]
        BEFORE="$(tree_of)"
        compose_all iphone
        expect "  the next run refuses" "exit $RC, want a failure" [ "$RC" != 0 ]
        expect "  says why" "the message is: $OUT" grep -q "compose-promoting is there: an earlier run was stopped" <<< "$OUT"
        expect "  changes nothing" "$(diff <(echo "$BEFORE") <(tree_of))" unchanged
        # What the message says to do: remove the file (and .compose-previous, which holds what the run replaced)
        rm -rf "$T/out/.compose-promoting" "$T/out/.compose-previous"
        compose_all iphone
        expect "  after the file is removed, a run makes the whole set" "exit $RC; $(ls -A "$T/out")" whole_set
        expect "  leaves nothing of the run" "$(ls -A "$T/out")" no_leftovers
    done
    "$setup"
    compose_killed "$((moves + 1))"
    expect "$what, not killed (there are $moves moves)" "exit $RC, want 0; $OUT" [ "$RC" = 0 ]
    expect "  makes the whole set" "$(ls -A "$T/out")" whole_set
    expect "  leaves nothing of the run" "$(ls -A "$T/out")" no_leftovers
}
# Two folders and a contact sheet are put in place: one move each into an empty output folder, two each (the item
# set aside, the new one) over an earlier set
killed_at_every_move "an empty output folder" empty_output 3
killed_at_every_move "an earlier set" earlier_run 6

# The iPad's status bar shows a date, which the simulator writes in English in every language: the composer writes it again
# in the language of the locale. Three locales of two languages, with the same captions and the same captures (each with
# the bar), so that only the date can tell their images apart.
ipad_locales() {
    rm -rf "$T/captures" "$T/out"
    { for locale in "English, en-US" "English, en-GB" "German, de-DE"; do
        printf '## %s\n\n### Screenshot captions\n\n```text\n' "$locale"; printf '%s\n' "${SIX[@]}"; printf '```\n\n'
      done; } > "$T/listing.md"
    for language in en de; do
        mkdir -p "$T/captures/ipad/$language"
        for number in 01 02 03 04 05 06; do png 2064 2752 "$T/captures/ipad/$language/$number.png" bar; done
    done
}
# bar_of <a.png> <b.png>: the status bars of two composed iPad images of one screen, in the pixels of their 2064-wide
# captures, which the composer scales down. Prints the box where the two images differ ("differ <top> <bottom> <left>
# <right>", or "differ none"), then the items of text of each bar, from the time to the end of the share of the width the
# composer searches ("items a <start>-<end> ..." and "items b ..."). sips makes each a BMP, whose rows are uncompressed
bar_of() {
    sips -s format bmp "$1" --out "$T/a.bmp" > /dev/null && sips -s format bmp "$2" --out "$T/b.bmp" > /dev/null \
        || { echo "sips failed"; return; }
    python3 - "$T/a.bmp" "$T/b.bmp" <<'PY'
import re, struct, sys
def image(path):
    data = open(path, "rb").read()
    start, = struct.unpack("<I", data[10:14])
    width, height = struct.unpack("<ii", data[18:26])
    size = struct.unpack("<H", data[28:30])[0] // 8
    stride = (8 * size * width + 31) // 32 * 4
    rows = [data[start + y * stride:start + y * stride + size * width] for y in range(abs(height))]
    return (rows[::-1] if height > 0 else rows), size  # a positive height lists the rows from the bottom
(a, size), (b, _) = image(sys.argv[1]), image(sys.argv[2])
if len(a) != len(b) or len(a[0]) != len(b[0]):
    sys.exit(print("differ in size"))
def pixel(rows, x, y): return rows[y][size * x:size * (x + 1)]  # blue, green, red, and maybe alpha
def run(pattern, row, least):
    match = re.compile(b"(?:" + pattern + b"." * (size - 3) + b"){%d,}" % least, re.S).search(row)
    return (-(-match.start() // size), match.end() // size) if match else None
# The bar's top: the first row with a run of black, the time and the name. The scale: the width of the capture's plain
# grey in a row below the bar, where the screen is not rounded
top = next((y for y, row in enumerate(b) if run(b"\0\0\0", row, 40)), None)
screen = run(b"[\xee-\xf2]{3}", b[top + 150], 1000) if top is not None else None
if not screen:
    sys.exit(print("no status bar"))
scale = (screen[1] - screen[0]) / 2064
def x_of(x): return round((x - screen[0]) / scale)
def y_of(y): return round(22 + (y - top) / scale)
def at(x): return screen[0] + round(x * scale)
differing = [y for y in range(len(a)) if a[y] != b[y]]
if differing:
    columns = [x for x in range(len(a[0]) // size) if any(pixel(a, x, y) != pixel(b, x, y) for y in differing)]
    print("differ", y_of(differing[0]), y_of(differing[-1]), x_of(columns[0]), x_of(columns[-1]))
else:
    print("differ none")
# A pixel of text: grey, darker than the bar's background. The items: runs of columns with one in the bar's rows
# (StatusBar.rows, 10 to 53), those closer than the composer's gap between items (16) joined
def text(p): return max(p[:3]) - min(p[:3]) < 16 and (722 * p[0] + 7152 * p[1] + 2126 * p[2]) // 10_000 < 200
band = range(top + round((10 - 22) * scale), top + round((54 - 22) * scale))
for name, rows in (("a", a), ("b", b)):
    items = []
    for x in range(at(51), at(825)):
        if any(text(pixel(rows, x, y)) for y in band):
            if items and x - items[-1][1] < 16 * scale:
                items[-1][1] = x + 1
            else:
                items.append([x, x + 1])
    print("items", name, *(f"{x_of(start)}-{x_of(end)}" for start, end in items))
PY
}
# The images differ only inside the part of the bar the composer paints: its rows (StatusBar.rows, 10 to 53), and its
# columns from the date (x 144) to the end of the searched share of the width (x 825), a pixel or two either way for the
# scaling
only_the_bar_differs() {
    [[ "$(sed -n 's/^differ //p' <<< "$BAR")" =~ ^([0-9]+)\ ([0-9]+)\ ([0-9]+)\ ([0-9]+)$ ]] \
        && [ "${BASH_REMATCH[1]}" -ge 8 ] && [ "${BASH_REMATCH[2]}" -le 55 ] \
        && [ "${BASH_REMATCH[3]}" -ge 140 ] && [ "${BASH_REMATCH[4]}" -le 828 ]
}
# items_of <a | b>: the items of an image's bar, one "<start> <end>" a line
items_of() { sed -n "s/^items $1 //p" <<< "$BAR" | tr ' ' '\n' | tr '-' ' '; }
three_items() { [ "$(items_of a | grep -c .)" = 3 ] && [ "$(items_of b | grep -c .)" = 3 ]; }
name_start() { items_of "$1" | sed -n '3s/ .*//p'; }
name_moved() { three_items && [ "$(name_start b)" -gt "$(($(name_start a) + 20))" ]; }
# The name keeps its width (128, and a pixel of each soft edge) and follows the date as the device places it: its ink 22
# pixels after the date's advance, so 22 or a few more after the ink of the date's last letter (22 in English, 24 in German)
name_follows_the_date() {
    local image date_end name_left name_right
    three_items || return 1
    for image in a b; do
        { read -r _; read -r _ date_end; read -r name_left name_right; } < <(items_of "$image")
        [ $((name_right - name_left)) -ge 124 ] && [ $((name_right - name_left)) -le 132 ] \
            && [ $((name_left - date_end)) -ge 19 ] && [ $((name_left - date_end)) -le 27 ] || return 1
    done
}

# 12. The iPad's images of each locale show the date in its language: those of en-US and en-GB are the same, and those of
#     de-DE differ from them only in the band of the status bar
ipad_locales
compose_all ipad
expect "the iPad's status bar" "exit $RC" [ "$RC" = 0 ]
expect "  writes six images of each locale" "$(cd "$T/out" 2>/dev/null && find . -name '*.png' | sort | tr '\n' ' ')" \
    [ "$(find "$T/out" -path '*/ipad/*.png' | wc -l | tr -d ' ')" = 18 ]
expect "  writes the same images for two locales of one language" "en-US and en-GB differ" \
    cmp -s "$T/out/en-US/ipad/03.png" "$T/out/en-GB/ipad/03.png"
BAR="$(bar_of "$T/out/en-US/ipad/03.png" "$T/out/de-DE/ipad/03.png")"; OUT="$BAR"
what="the bars of en-US (a) and de-DE (b), in the pixels of the capture:"
expect "  writes the date of each language in the status bar, and nothing else differs" "$what" only_the_bar_differs
expect "  leaves the time, the date and the name in each bar" "$what" three_items
expect "  moves the name right after the longer date" "$what" name_moved
expect "  keeps the name's width, the device's gap after the date" "$what" name_follows_the_date

# 13. A capture without the status bar is refused, and nothing is written: its date could not be found
ipad_locales; png 2064 2752 "$T/captures/ipad/en/03.png"
compose_all ipad
expect "an iPad capture without the status bar" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  names the capture and what it shows" "the message is: $OUT" grep -q "ipad/en/03.png.*shows 0 items" <<< "$OUT"
expect "  writes nothing" "$(find "$T/out" 2>&1)" nothing_written

# 14. A status bar over something that is not a plain background is refused, and nothing is written: painting over the
#     date would leave a patch
ipad_locales; png 2064 2752 "$T/captures/ipad/de/05.png" bar-on-a-mark
compose_all ipad
expect "an iPad status bar that is not on a plain background" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  names the capture and the reason" "the message is: $OUT" grep -q "ipad/de/05.png.*not on a plain background" <<< "$OUT"
expect "  writes nothing" "$(find "$T/out" 2>&1)" nothing_written

# 15. A status bar with a fourth item at the top left is refused, and nothing is written: the date is the second of three
ipad_locales; png 2064 2752 "$T/captures/ipad/en/02.png" bar-of-four
compose_all ipad
expect "an iPad status bar with four items at the top left" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  names the capture and what it shows" "the message is: $OUT" grep -q "ipad/en/02.png.*shows 4 items" <<< "$OUT"
expect "  writes nothing" "$(find "$T/out" 2>&1)" nothing_written

# 16. A date that would push the app's name past the share of the width the composer searches is refused, and nothing is
#     written: the name would run into what the bar shows further right. The name fits after the capture's date, not
#     after the German one, which is wider
ipad_locales; png 2064 2752 "$T/captures/ipad/de/04.png" bar-long-name
compose_all ipad
expect "an iPad status bar with no room for the name after the date" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  names the capture and the reason" "the message is: $OUT" \
    grep -q "ipad/de/04.png.*leaves no room for the app's name" <<< "$OUT"
expect "  writes nothing" "$(find "$T/out" 2>&1)" nothing_written

# 17. A language with no date in the composer's table is refused on the iPad, before anything is written, and composed on
#     the iPhone, whose status bar shows no date
rm -rf "$T/captures" "$T/out"
{ printf '## Japanese, ja-JP\n\n### Screenshot captions\n\n```text\n'; printf '%s\n' "${SIX[@]}"; printf '```\n'; } > "$T/listing.md"
captures_for "$T/captures" ipad ja 2064 2752 6; captures_for "$T/captures" iphone ja 1320 2868 6
compose_all ipad
expect "a language with no date of the status bar, on the iPad" "exit $RC, want a failure" [ "$RC" != 0 ]
expect "  names the language" "the message is: $OUT" grep -q "no status bar date for ja" <<< "$OUT"
expect "  writes nothing" "$(find "$T/out" 2>&1)" nothing_written
compose_all iphone
expect "  is composed on the iPhone" "exit $RC" [ "$RC" = 0 ]

echo "compose-store-screenshots-selftest: $pass passed, $fail failed"
[ "$fail" = 0 ]
