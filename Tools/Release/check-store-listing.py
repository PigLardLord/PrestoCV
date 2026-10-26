#!/usr/bin/env python3
"""Counts the texts of docs/release/store-listing.md and checks them against the App Store limits.

    Tools/Release/check-store-listing.py           # exits 1 if a text breaks a limit or the counts table is stale
    Tools/Release/check-store-listing.py --write   # rewrites the counts table first

A text is the fenced ```text block under a field heading (### Name) of a locale section (## German, de-DE), or under
"## Notes for App Review". Characters are Unicode scalars of NFC text; keywords are counted in UTF-8 bytes.
"""
import re
import sys
import unicodedata
from pathlib import Path

DOC = Path(__file__).resolve().parents[2] / "docs" / "release" / "store-listing.md"
FIELDS = ["Name", "Subtitle", "Keywords", "Promotional text", "Description", "Screenshot captions", "What's New"]
LIMITS = {"Name": 30, "Subtitle": 30, "Promotional text": 170, "Description": 4000, "What's New": 4000}
KEYWORD_BYTES, NOTES_LIMIT, CAPTIONS = 100, 4000, (5, 6)
# A caption is "Title | Line below". The limits keep the title on one or two lines of the screenshot, at its large size.
CAPTION_TITLE, CAPTION_LINE = 30, 80
# Guideline 2.3.7: no prices in the name, the subtitle, the keywords or the screenshots.
PRICE_WORDS = {"free", "gratis", "kostenlos", "gratuit", "gratuite", "gratuito", "gratuita", "gratuitos", "price",
               "preis", "prezzo", "precio", "prix", "preco"}
PRICED_FIELDS = ["Name", "Subtitle", "Keywords", "Screenshot captions"]
NOTES = "Notes for App Review"
LOCALE = re.compile(r"^## .+, ([a-z]{2}(?:-[A-Z]{2})?)$")
START, END = "<!-- counts:start -->", "<!-- counts:end -->"


def fold(text):
    """Lower case without diacritics, so "Currículum" and "curriculum" are one word, as the App Store matches them."""
    return "".join(c for c in unicodedata.normalize("NFKD", text) if not unicodedata.combining(c)).casefold()


def words(text):
    return set(re.findall(r"\w+", fold(text)))


def parse(lines):
    """{locale: {field: text}} and the review notes."""
    locales, notes, section, field, block = {}, None, None, None, None
    for line in lines:
        if block is not None:
            if line == "```":
                text = "\n".join(block)
                if section == NOTES:
                    notes = text
                elif section in locales and field:
                    locales[section].setdefault(field, []).append(text)
                block = None
            else:
                block.append(line)
        elif line == "```text":
            block = []
        elif match := LOCALE.match(line):
            section, field = match.group(1), None
            locales[section] = {}
        elif line.startswith("## "):
            section, field = line[3:], None
        elif line.startswith("### "):
            field = line[4:]
    return locales, notes


def check(locales, notes):
    errors = []
    if notes is None:
        errors.append(f"no text under '## {NOTES}'")
    elif len(notes) > NOTES_LIMIT:
        errors.append(f"{NOTES}: {len(notes)} characters, limit {NOTES_LIMIT}")
    for locale, fields in locales.items():
        for name in FIELDS:
            if len(fields.get(name, [])) != 1:
                errors.append(f"{locale}: needs exactly one text under '### {name}'")
        if any(len(fields.get(name, [])) != 1 for name in FIELDS):
            continue
        text = {name: fields[name][0] for name in FIELDS}
        for name, value in text.items():
            if value != unicodedata.normalize("NFC", value):
                errors.append(f"{locale} {name}: not in NFC")
            if name in LIMITS and len(value) > LIMITS[name]:
                errors.append(f"{locale} {name}: {len(value)} characters, limit {LIMITS[name]}")
        keywords = text["Keywords"]
        if len(keywords.encode("utf-8")) > KEYWORD_BYTES:
            errors.append(f"{locale} Keywords: {len(keywords.encode('utf-8'))} bytes, limit {KEYWORD_BYTES}")
        listed = keywords.split(",")
        named = words(text["Name"]) | words(text["Subtitle"])
        for keyword in listed:
            if keyword != keyword.strip() or len(keyword) <= 2:
                errors.append(f"{locale} Keywords: '{keyword}' needs more than two characters and no surrounding space")
            if words(keyword) & named:
                errors.append(f"{locale} Keywords: '{keyword}' repeats a word of the name or the subtitle")
        if len({fold(k) for k in listed}) != len(listed):
            errors.append(f"{locale} Keywords: a keyword is listed twice")
        captions = text["Screenshot captions"].split("\n")
        if not CAPTIONS[0] <= len(captions) <= CAPTIONS[1] or not all(c.strip() for c in captions):
            errors.append(f"{locale} Screenshot captions: needs {CAPTIONS[0]} to {CAPTIONS[1]} non-empty lines")
        for number, caption in enumerate(captions, 1):
            parts = caption.split(" | ")
            if len(parts) != 2 or not all(part.strip() for part in parts):
                errors.append(f"{locale} Screenshot caption {number}: write it as 'Title | Line below'")
            elif len(parts[0]) > CAPTION_TITLE or len(parts[1]) > CAPTION_LINE:
                errors.append(f"{locale} Screenshot caption {number}: title {len(parts[0])} characters (limit "
                              f"{CAPTION_TITLE}), line below {len(parts[1])} (limit {CAPTION_LINE})")
        for name in PRICED_FIELDS:
            if words(text[name]) & PRICE_WORDS or re.search(r"[$€£]", text[name]):
                errors.append(f"{locale} {name}: names a price (guideline 2.3.7)")
    return errors


def caption_lengths(captions):
    """The longest title and the longest line below, as "27 / 72 (6 captions)"."""
    parts = [caption.split(" | ", 1) + [""] for caption in captions]
    return f"{max(len(p[0]) for p in parts)} / {max(len(p[1]) for p in parts)} ({len(captions)} captions)"


def table(locales, notes):
    rows = ["| Locale | Name (30) | Subtitle (30) | Keywords (100 bytes) | Promotional text (170) | Description (4000) "
            "| Captions (longest title / line) | What's New (4000) |",
            "|---|---|---|---|---|---|---|---|"]
    for locale, fields in locales.items():
        text = {name: (fields.get(name) or [""])[0] for name in FIELDS}
        captions = text["Screenshot captions"].split("\n")
        cells = [len(text["Name"]), len(text["Subtitle"]), len(text["Keywords"].encode("utf-8")),
                 len(text["Promotional text"]), len(text["Description"]),
                 caption_lengths(captions), len(text["What's New"])]
        rows.append("| " + " | ".join(map(str, [locale, *cells])) + " |")
    rows += ["", f"{NOTES}: {len(notes or '')} characters ({NOTES_LIMIT})."]
    return rows


def main():
    write = sys.argv[1:] == ["--write"]
    if sys.argv[1:] not in ([], ["--write"]):
        sys.exit(__doc__)
    lines = DOC.read_text(encoding="utf-8").split("\n")
    locales, notes = parse(lines)
    errors = check(locales, notes)
    if START not in lines or END not in lines:
        sys.exit(f"{DOC.name}: no {START} … {END} markers")
    start, end = lines.index(START), lines.index(END)
    counts = table(locales, notes)
    print("\n".join(counts))
    if lines[start + 1:end] != counts:
        if write:
            DOC.write_text("\n".join(lines[:start + 1] + counts + lines[end:]), encoding="utf-8")
            print(f"\nwrote the counts table of {DOC.name}")
        else:
            errors.append("the counts table is stale: run with --write")
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
