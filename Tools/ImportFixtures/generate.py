#!/usr/bin/env python3
"""Generates the import's synthetic corpus (ADR 0027) into PrestoCVCore/Tests/ImportFixtures.

Each invented person of people.py is written in several forms, and each form lists the fields it states:
  chat      a chat assistant's Markdown answer, with its opening and closing sentences;
  word      text copied from a Word document;
  latex     text copied from a LaTeX CV (moderncv): ligatures, icon glyphs, a word hyphenated at a line's end;
  europass  the Italian "formato europeo" copied from Word (the Italian people);
  lebenslauf the German tabular Lebenslauf copied from Word (the German people);
and, as PDFs with the words and boxes a PDF reader sees (`*.layout.json`):
  linkedin  LinkedIn's "Save to PDF": a sidebar, English headings, computed durations (one person per language);
  wordpdf   a one-column CV exported from a word processor (the other person per language);
  railpdf   a CV whose headings stand right-aligned in a narrow column beside their sections (the other person too);
  lebenslaufpdf, europasspdf, and a scan without a text layer.

Run it from the repository's root: python3 Tools/ImportFixtures/generate.py. The output is committed and reviewed like
code; never put a real CV here.
"""

import json
import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from helvetica import WIDTHS  # noqa: E402
from people import LANGUAGES, PEOPLE  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "PrestoCVCore", "Tests", "ImportFixtures")
TODAY = (2026, 10)
DASH = "–"


# ---------------------------------------------------------------------------------------------------------- dates

def month_name(lang, month, short=False):
    names = LANGUAGES[lang]["months_short" if short else "months"]
    return names[month - 1]


def date_text(lang, ym, style):
    year, month = ym
    if month is None:
        return str(year)
    if style == "numeric":
        return f"{month:02d}/{year}"
    if style == "short":
        return f"{month_name(lang, month, short=True)} {year}"
    name = month_name(lang, month)
    if lang in ("es", "pt"):
        return f"{name} de {year}"
    return f"{name} {year}"


def capitalised(text):
    return text[:1].upper() + text[1:]


def period_text(lang, start, end, style, current=None, sep=f" {DASH} ", capital=False):
    first = date_text(lang, start, style)
    last = (current or LANGUAGES[lang]["current"]) if end is None else date_text(lang, end, style)
    text = f"{first}{sep}{last}"
    return capitalised(text) if capital else text


def expected_period(start, end):
    return {"start": [start[0], start[1]], "end": "current" if end is None else [end[0], end[1]]}


def years_only(entry):
    return dict(entry, start=(entry["start"][0], None), end=None if entry["end"] is None else (entry["end"][0], None))


# ---------------------------------------------------------------------------------------------------------- expected

def expected(p, form, **fields):
    base = {
        "id": f"{p['id']}/{form}", "language": p["lang"], "form": form,
        "person": {"name": f"{p['first']} {p['last']}", "title": p["title"], "email": p["email"], "phone": p["phone"],
                   "location": f"{p['city']}, {p['country']}", "links": [f"https://{p['linkedin']}"], "summary": p["summary"]},
        "experience": [
            dict(role=e["role"], employer=e["employer"], location=e["city"], details=len(e["bullets"]), **expected_period(e["start"], e["end"]))
            for e in p["experience"]
        ],
        "education": [dict(degree=e["degree"], school=e["school"], **expected_period(e["start"], e["end"])) for e in p["education"]],
        "skills": list(p["skills"]),
        "languages": [{"name": name, "level": None if level.startswith("words:") else level.lower()} for name, level in p["languages"]],
        "certifications": [{"name": n, "issuer": i, "year": y} for n, i, y in p["certifications"]],
        "interests": list(p["interests"]),
    }
    for key, value in fields.items():
        if key in base["person"]:
            base["person"][key] = value
        else:
            base[key] = value
    return base


def level_text(lang, level, form):
    L = LANGUAGES[lang]
    if level == "native":
        return L["native"]
    if level.startswith("words:"):
        return level[len("words:"):]
    return level


# ---------------------------------------------------------------------------------------------------------- text forms

def chat(p):
    lang, L = p["lang"], LANGUAGES[p["lang"]]
    h = L["md"]
    style = p["dates"]
    one_line = p["id"].endswith(("marco", "jonas", "james", "javier", "thomas", "joao"))
    out = [L["opener"], "", f"# {p['first']} {p['last']}", f"**{p['title']}**",
           f"📍 {p['city']}, {p['country']} | 📞 {p['phone']} | ✉️ {p['email']} | 🔗 {p['linkedin']}", "", "---", "",
           f"## {h['profile']}", p["summary"], "", f"## {h['experience']}"]
    for e in p["experience"]:
        period = period_text(lang, e["start"], e["end"], style, capital=True)
        if one_line:
            out.append(f"**{e['role']}** | {e['employer']} | {e['city']} | {period}")
        else:
            out += [f"### {e['role']} — {e['employer']}, {e['city']}", f"*{period}*"]
        out += [f"- {b}" for b in e["bullets"]]
        out.append("")
    out.append(f"## {h['education']}")
    for e in p["education"]:
        out += [f"### {e['degree']}", f"{e['school']}, {e['city']} | {period_text(lang, e['start'], e['end'], style)}", ""]
    out += [f"## {h['skills']}", "- " + ", ".join(p["skills"]), "", f"## {h['languages']}"]
    if one_line:
        out += ["| Lingua | Livello |" if lang == "it" else "| Language | Level |", "|---|---|"]
        out += [f"| {n} | {level_text(lang, lv, 'chat')} |" for n, lv in p["languages"]]
    else:
        out += [f"- **{n}:** {level_text(lang, lv, 'chat')}" for n, lv in p["languages"]]
    out += ["", f"## {h['certifications']}"]
    out += [f"- {n} – {i} ({y})" for n, i, y in p["certifications"]]
    out += ["", f"## {h['interests']}", ", ".join(p["interests"]), "", "---", "", L["closer"]]
    exp = expected(p, "chat", links=[f"https://{p['linkedin']}"])
    exp["education"] = [dict(degree=e["degree"], school=e["school"], **expected_period(e["start"], e["end"])) for e in p["education"]]
    return "\n".join(out) + "\n", exp


def word(p):
    lang, L = p["lang"], LANGUAGES[p["lang"]]
    h = L["word"]
    style = "numeric" if p["dates"] == "month" else "month"
    out = [f"{p['first']} {p['last']}", p["title"], p["address"], f"{L['phone']}: {p['phone']}", f"{L['email']}: {p['email']}",
           p["linkedin"], "", h["profile"].upper(), p["summary"], "", h["experience"].upper()]
    for e in p["experience"]:
        out += [e["role"], f"{e['employer']}, {e['city']}", period_text(lang, e["start"], e["end"], style, capital=True)]
        out += [f"• {b}" for b in e["bullets"]]
        out.append("")
    out.append(h["education"].upper())
    for e in p["education"]:
        out.append(f"{period_text(lang, e['start'], e['end'], style)}: {e['degree']}, {e['school']}")
    out += ["", h["skills"].upper(), ", ".join(p["skills"]), "", h["languages"].upper()]
    out += [f"{n} – {level_text(lang, lv, 'word')}" for n, lv in p["languages"]]
    out += ["", h["certifications"].upper()]
    out += [f"{n}, {i}, {y}" for n, i, y in p["certifications"]]
    out += ["", h["interests"].upper(), ", ".join(p["interests"])]
    exp = expected(p, "word", location=p["address"])
    return "\n".join(out) + "\n", exp


LIGATURES = [("ffi", "ﬃ"), ("ffl", "ﬄ"), ("ff", "ﬀ"), ("fi", "ﬁ"), ("fl", "ﬂ")]


def ligatured(text):
    for plain, ligature in LIGATURES:
        text = text.replace(plain, ligature)
    return text


def hyphenated_lines(text, width=58):
    """Wraps a text and breaks one long word across a line's end with a hyphen, as LaTeX does."""
    words = text.split()
    lines, line, broke = [], "", False
    for word in words:
        candidate = (line + " " + word).strip()
        if len(candidate) <= width:
            line = candidate
            continue
        if not broke and len(word) >= 9 and word[0].islower() and word.isalpha():
            cut = len(word) // 2
            lines.append((line + " " + word[:cut] + "-").strip())
            line = word[cut:]
            broke = True
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def latex(p):
    lang, L = p["lang"], LANGUAGES[p["lang"]]
    h = L["latex"]
    current = capitalised(L["current"])
    out = [f"{p['first']} {p['last']}", p["title"],
           f" {p['phone']}    {p['email']}    {p['linkedin']}", f" {p['city']}, {p['country']}", "",
           h["profile"]]
    out += [ligatured(line) for line in hyphenated_lines(p["summary"])]
    out += ["", h["experience"]]
    for e in p["experience"]:
        period = f"{e['start'][0]}{DASH}{current if e['end'] is None else e['end'][0]}"
        out.append(f"{period}   {e['role']}, {e['employer']}, {e['city']}")
        out += [f"• {ligatured(b)}" for b in e["bullets"]]
    out += ["", h["education"]]
    for e in p["education"]:
        out.append(f"{e['start'][0]}{DASH}{e['end'][0]}   {e['degree']}, {e['school']}")
    out += ["", h["skills"], f"{h['skills']}   {', '.join(p['skills'])}", "", h["languages"]]
    out += [f"{n}   {level_text(lang, lv, 'latex')}" for n, lv in p["languages"]]
    out += ["", h["certifications"]]
    out += [f"{y}   {n}, {i}" for n, i, y in p["certifications"]]
    out += ["", h["interests"], ", ".join(p["interests"]), "", "1"]
    exp = expected(p, "latex")
    exp["experience"] = [dict(e, **expected_period((e["start"][0], None), None if e["end"] == "current" else (e["end"][0], None)))
                         for e in exp["experience"]]
    exp["education"] = [dict(e, **expected_period((e["start"][0], None), (e["end"][0], None))) for e in exp["education"]]
    return "\n".join(out) + "\n", exp


def europass(p):
    """The Italian formato europeo, copied from its Word table: labels and values separated by tabs."""
    lang, L = p["lang"], LANGUAGES[p["lang"]]
    out = ["FORMATO EUROPEO PER IL CURRICULUM VITAE", "", "INFORMAZIONI PERSONALI",
           f"Nome\t{p['last']} {p['first']}", f"Indirizzo\t{p['address']}", f"Telefono\t{p['phone']}", f"E-mail\t{p['email']}",
           "Nazionalità\tItaliana", "Data di nascita\t14/05/1992", "", "ESPERIENZA LAVORATIVA"]
    for e in p["experience"]:
        period = period_text(lang, e["start"], e["end"], "month", current=L["current_caps"], capital=True)
        out += [f"• Date (da – a)\t{period}", f"• Nome e indirizzo del datore di lavoro\t{e['employer']}, Via Esempio 1, {e['city']}",
                f"• Tipo di azienda o settore\t{e['sector']}", f"• Tipo di impiego\t{e['role']}",
                f"• Principali mansioni e responsabilità\t{'; '.join(e['bullets'])}", ""]
    out.append("ISTRUZIONE E FORMAZIONE")
    for e in p["education"]:
        out += [f"• Date (da – a)\t{e['start'][0]} – {e['end'][0]}",
                f"• Nome e tipo di istituto di istruzione o formazione\t{e['school']}",
                f"• Principali materie / abilità professionali oggetto dello studio\t{e['subjects']}",
                f"• Qualifica conseguita\t{e['degree']}", ""]
    out += ["CAPACITÀ E COMPETENZE PERSONALI",
            "Acquisite nel corso della vita e della carriera ma non necessariamente riconosciute da certificati e diplomi ufficiali.",
            "MADRELINGUA\tItaliano", "ALTRE LINGUE"]
    others = [(n, lv) for n, lv in p["languages"] if lv != "native"]
    for name, level in others:
        words = level[len("words:"):] if level.startswith("words:") else "buono"
        out += [f"\t{name}", f"• Capacità di lettura\t{words}", f"• Capacità di scrittura\t{words}",
                f"• Capacità di espressione orale\t{words}"]
    out += ["", f"CAPACITÀ E COMPETENZE TECNICHE\t{', '.join(p['skills'])}", "", "PATENTE O PATENTI\tB", "",
            "Autorizzo il trattamento dei miei dati personali ai sensi del D.Lgs. 196/2003 e del Regolamento UE 2016/679."]
    exp = expected(p, "europass", name=f"{p['last']} {p['first']}", title=None, location=p["address"], links=[], summary=None,
                   certifications=[], interests=[])
    exp["experience"] = [dict(x, location=f"Via Esempio 1, {e['city']}", details=2) for x, e in zip(exp["experience"], p["experience"])]
    exp["education"] = [dict(x, **expected_period((e["start"][0], None), (e["end"][0], None))) for x, e in zip(exp["education"], p["education"])]
    exp["languages"] = [{"name": "Italiano", "level": "native"}] + [{"name": n, "level": None} for n, _ in others]
    return "\n".join(out) + "\n", exp


def lebenslauf(p):
    """The German tabular Lebenslauf, copied from its Word table: the dates in the left column."""
    lang, L = p["lang"], LANGUAGES[p["lang"]]
    since = p["id"] == "de-jonas"
    out = ["Lebenslauf", "", "Persönliche Daten", f"Name:\t{p['first']} {p['last']}", f"Anschrift:\t{p['address']}",
           f"Telefon:\t{p['phone']}", f"E-Mail:\t{p['email']}", "Geburtsdatum:\t14.05.1992", "Staatsangehörigkeit:\tdeutsch", "",
           "Berufserfahrung"]
    for e in p["experience"]:
        if e["end"] is None and since:
            period = f"seit {e['start'][1]:02d}/{e['start'][0]}"
        else:
            period = period_text(lang, e["start"], e["end"], "numeric")
        out += [f"{period}\t{e['role']}", f"\t{e['employer']}, {e['city']}"] + [f"\t• {b}" for b in e["bullets"]]
    out += ["", "Ausbildung"]
    for e in p["education"]:
        out += [f"{period_text(lang, e['start'], e['end'], 'numeric')}\t{e['degree']}", f"\t{e['school']}, {e['city']}"]
    out += ["", "Kenntnisse", f"Fachlich:\t{', '.join(p['skills'])}", "", "Sprachen"]
    for name, level in p["languages"]:
        text = "Muttersprache" if level == "native" else level[len("words:"):] if level.startswith("words:") else f"verhandlungssicher ({level})" if level == "C1" else f"Grundkenntnisse ({level})"
        out.append(f"{name}\t{text}")
    out += ["", "Weiterbildungen"] + [f"{y}\t{n}, {i}" for n, i, y in p["certifications"]]
    out += ["", "Hobbys", ", ".join(p["interests"]), "", f"{p['city']}, 12.03.2026", f"{p['first']} {p['last']}"]
    exp = expected(p, "lebenslauf", title=None, location=p["address"], links=[], summary=None)
    exp["education"] = [dict(x, location=e["city"]) for x, e in zip(exp["education"], p["education"])]
    return "\n".join(out) + "\n", exp


# ---------------------------------------------------------------------------------------------------------- PDF layouts

ASCENT, HEIGHT = 0.718, 0.925


def text_width(text, size, bold):
    return sum(WIDTHS[bold].get(c, 556) for c in text) * size / 1000


class Layout:
    """Pages of runs of text, each at a baseline, measured with Helvetica's widths."""

    def __init__(self):
        self.pages = [[]]

    def new_page(self):
        self.pages.append([])

    def run(self, x, baseline, text, size=10, bold=False, page=None):
        self.pages[-1 if page is None else page].append((x, baseline, text, size, bold))

    def words(self, page):
        words = []
        for x, baseline, text, size, bold in self.pages[page]:
            cursor = x
            for index, word in enumerate(text.split(" ")):
                if index:
                    cursor += text_width(" ", size, bold)
                width = text_width(word, size, bold)
                if word:
                    words.append({"t": word, "x": round(cursor, 2), "y": round(baseline - ASCENT * size, 2),
                                  "w": round(width, 2), "h": round(HEIGHT * size, 2), "s": size, "b": bold})
                cursor += width
        return words

    def json(self):
        return {"pages": [{"width": 595, "height": 842, "words": self.words(i)} for i in range(len(self.pages))]}


def wrap(text, width, size, bold=False):
    lines, line = [], ""
    for word in text.split():
        candidate = (line + " " + word).strip()
        if text_width(candidate, size, bold) <= width or not line:
            line = candidate
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def linkedin_duration(start, end):
    end = end or TODAY
    months = (end[0] * 12 + end[1]) - (start[0] * 12 + start[1]) + 1
    years, months = divmod(months, 12)
    parts = []
    if years:
        parts.append(f"{years} year{'s' if years > 1 else ''}")
    if months:
        parts.append(f"{months} month{'s' if months > 1 else ''}")
    return " ".join(parts)


EN_MONTHS = LANGUAGES["en"]["months"]


def linkedin(p):
    """LinkedIn's "Save to PDF": a sidebar on the left, the profile on the right, English headings, page numbers."""
    layout = Layout()
    side_x, main_x, main_width, bottom = 36, 220, 340, 640
    y = 60

    def side(text, size=10, bold=False, gap=0):
        nonlocal y
        y += gap
        for line in wrap(text, 150, size, bold):
            layout.run(side_x, y, line, size, bold, page=0)
            y += size * 1.35

    side("Contact", 13, True)
    side(p["email"])
    side(f"{p['phone']} (Mobile)")
    side(f"www.{p['linkedin']} (LinkedIn)")
    side("Top Skills", 13, True, gap=10)
    for skill in p["skills"][:3]:
        side(skill)
    side("Languages", 13, True, gap=10)
    levels = {"native": "Native or Bilingual", "C1": "Full Professional", "B2": "Professional Working", "B1": "Limited Working",
              "A2": "Elementary", "A1": "Elementary"}
    for name, level in p["languages"]:
        side(f"{name} ({levels.get(level, 'Limited Working')})")
    side("Certifications", 13, True, gap=10)
    for name, _, _ in p["certifications"]:
        side(name)

    page, y = 0, 60
    pages_used = [0]

    def main(text, size=10, bold=False, gap=0):
        nonlocal y, page
        y += gap
        for line in wrap(text, main_width, size, bold):
            if y > bottom:
                layout.new_page()
                page += 1
                pages_used.append(page)
                y = 60
            layout.run(main_x, y, line, size, bold, page=page)
            y += size * 1.35

    main(f"{p['first']} {p['last']}", 24, False)
    main(p["title"], 12, gap=4)
    main(f"{p['city']}, {p['country']}", 10)
    main("Summary", 15, True, gap=12)
    main(p["summary"])
    main("Experience", 15, True, gap=12)
    for e in p["experience"]:
        main(e["employer"], 12, True, gap=6)
        main(e["role"], 11)
        start = f"{EN_MONTHS[e['start'][1] - 1]} {e['start'][0]}"
        end = "Present" if e["end"] is None else f"{EN_MONTHS[e['end'][1] - 1]} {e['end'][0]}"
        main(f"{start} - {end} ({linkedin_duration(e['start'], e['end'])})")
        main(f"{e['city']}, {p['country']}")
        for bullet in e["bullets"]:
            main(bullet + ".")
    main("Education", 15, True, gap=12)
    for e in p["education"]:
        main(e["school"], 12, True, gap=6)
        main(f"{e['degree']} · ({e['start'][0]} - {e['end'][0]})")
    total = len(layout.pages)
    for index in range(total):
        layout.run(270, 815, f"Page {index + 1} of {total}", 9, page=index)

    exp = expected(p, "linkedin")
    exp["person"]["links"] = [f"https://www.{p['linkedin']}"]
    exp["experience"] = [dict(x, location=f"{e['city']}, {p['country']}") for x, e in zip(exp["experience"], p["experience"])]
    exp["education"] = [dict(x, **expected_period((e["start"][0], None), (e["end"][0], None))) for x, e in zip(exp["education"], p["education"])]
    exp["skills"] = p["skills"][:3]
    exp["languages"] = [{"name": n, "level": "native" if lv == "native" else None} for n, lv in p["languages"]]
    exp["certifications"] = [{"name": n, "issuer": None, "year": None} for n, _, _ in p["certifications"]]
    exp["interests"] = []
    return layout, exp


def wordpdf(p):
    """A one-column CV exported from a word processor: bold headings, the dates after role and employer, bullets that
    wrap under their text."""
    lang, L = p["lang"], LANGUAGES[p["lang"]]
    h = L["word"]
    layout = Layout()
    x, width, bottom = 56, 480, 770
    y = 70
    page = 0

    def line(text, size=10, bold=False, gap=0, indent=0, bullet=False):
        nonlocal y, page
        y += gap
        lines = wrap(text, width - indent - (12 if bullet else 0), size, bold)
        for index, part in enumerate(lines):
            if y > bottom:
                layout.new_page()
                page += 1
                y = 70
            if bullet and index == 0:
                layout.run(x + indent, y, "•", size, bold, page=page)
            layout.run(x + indent + (12 if bullet else 0), y, part, size, bold, page=page)
            y += size * 1.3

    line(f"{p['first']} {p['last']}", 22, True)
    line(p["title"], 12, gap=2)
    line(f"{p['address']} · {p['phone']} · {p['email']}", 9, gap=2)
    line(h["profile"], 13, True, gap=14)
    line(p["summary"])
    line(h["experience"], 13, True, gap=14)
    for e in p["experience"]:
        line(e["role"], 11, True, gap=6)
        line(f"{e['employer']}, {e['city']}")
        line(period_text(lang, e["start"], e["end"], "month", capital=True), 9)
        for bullet in e["bullets"]:
            line(bullet + " " + " ".join(["und"] * 0), bullet=True, indent=6)
    line(h["education"], 13, True, gap=14)
    for e in p["education"]:
        line(f"{period_text(lang, e['start'], e['end'], 'month')}: {e['degree']}, {e['school']}", gap=4)
    line(h["skills"], 13, True, gap=14)
    line(", ".join(p["skills"]))
    line(h["languages"], 13, True, gap=14)
    for name, level in p["languages"]:
        line(f"{name} – {level_text(lang, level, 'word')}")
    line(h["certifications"], 13, True, gap=14)
    for n, i, yr in p["certifications"]:
        line(f"{n}, {i}, {yr}")
    line(h["interests"], 13, True, gap=14)
    line(", ".join(p["interests"]))
    total = len(layout.pages)
    if total > 1:
        for index in range(total):
            layout.run(270, 815, L["page"].format(n=index + 1, m=total), 8, page=index)
    exp = expected(p, "wordpdf", location=p["address"], links=[])
    return layout, exp


def railpdf(p):
    """A CV whose section headings stand bold and right-aligned in a narrow column on the left, each beside the first line
    of its section, ten points off the heading's right edge: the layout of a LaTeX CV's section titles and of many
    templates (#287). The gap is narrower than the one between two cells of a table."""
    lang, L = p["lang"], LANGUAGES[p["lang"]]
    h = L["latex"]
    layout = Layout()
    left, edge, body, right, bottom = 40, 180, 190, 555, 770
    width = right - body
    y = 56
    page = 0
    pending = None

    def line(text, size=9.3, bold=False, gap=0, indent=0, bullet=False, full=False):
        """A line of a section, wrapped to its column; the heading waiting for a line is drawn beside the first."""
        nonlocal y, page, pending
        y += gap
        column = right - left if full else width - indent - (12 if bullet else 0)
        for index, part in enumerate(wrap(text, column, size, bold)):
            if y > bottom:
                layout.new_page()
                page += 1
                y = 56
            if pending and index == 0:
                assert text_width(pending, 9.5, True) <= edge - left, pending
                layout.run(edge - text_width(pending, 9.5, True), y, pending, 9.5, True, page=page)
                pending = None
            if bullet and index == 0:
                layout.run(body + indent, y, "\u2022", size, bold, page=page)
            layout.run(left if full else body + indent + (12 if bullet else 0), y, part, size, bold, page=page)
            y += size * 1.35

    def section(heading, gap=14):
        nonlocal y, pending
        y += gap
        pending = heading

    line(f"{p['first']} {p['last']}", 22, True, full=True)
    line(p["title"], 12, gap=2, full=True)
    line(f"{p['address']} \u00b7 {p['phone']} \u00b7 {p['email']}", 9, gap=2, full=True)
    section(h["profile"], 18)
    line(p["summary"])
    section(h["experience"])
    for index, e in enumerate(p["experience"]):
        line(e["role"], 11.5, True, gap=6 if index else 0)
        line(f"{e['employer']}, {e['city']}", 9.5, True)
        line(period_text(lang, e["start"], e["end"], "month", capital=True), 9)
        for bullet in e["bullets"]:
            line(bullet, bullet=True, indent=6)
    section(h["education"])
    for index, e in enumerate(p["education"]):
        line(f"{period_text(lang, e['start'], e['end'], 'month')}: {e['degree']}, {e['school']}", gap=4 if index else 0)
    section(h["skills"])
    line(", ".join(p["skills"]))
    section(h["languages"])
    for name, level in p["languages"]:
        line(f"{name} \u2013 {level_text(lang, level, 'word')}")
    section(h["certifications"])
    for n, i, yr in p["certifications"]:
        line(f"{n}, {i}, {yr}")
    section(h["interests"])
    line(", ".join(p["interests"]))
    exp = expected(p, "railpdf", location=p["address"], links=[])
    return layout, exp


def lebenslaufpdf(p):
    """The German tabular Lebenslauf as a PDF: labels and dates in the left column, the rest on the right."""
    lang = p["lang"]
    layout = Layout()
    left, right = 56, 200
    y = 70

    def row(label, value=None, bold_value=False, gap=0, size=10):
        nonlocal y
        y += gap
        if label:
            layout.run(left, y, label, size)
        if value:
            for index, part in enumerate(wrap(value, 340, size, bold_value)):
                layout.run(right, y, part, size, bold_value)
                y += size * 1.35
        else:
            y += size * 1.35

    layout.run(left, y, "Lebenslauf", 22, True)
    y += 40
    layout.run(left, y, "Persönliche Daten", 13, True)
    y += 22
    for label, value in [("Name", f"{p['first']} {p['last']}"), ("Anschrift", p["address"]), ("Telefon", p["phone"]),
                         ("E-Mail", p["email"]), ("Geburtsdatum", "14.05.1992"), ("Staatsangehörigkeit", "deutsch")]:
        row(label, value)
    y += 14
    layout.run(left, y, "Berufserfahrung", 13, True)
    y += 22
    for e in p["experience"]:
        row(period_text(lang, e["start"], e["end"], "numeric"), e["role"], bold_value=True, gap=6)
        row(None, f"{e['employer']}, {e['city']}")
        for bullet in e["bullets"]:
            layout.run(right, y, "•", 10)
            for part in wrap(bullet, 320, 10):
                layout.run(right + 12, y, part, 10)
                y += 13.5
    y += 14
    layout.run(left, y, "Ausbildung", 13, True)
    y += 22
    for e in p["education"]:
        row(period_text(lang, e["start"], e["end"], "numeric"), e["degree"], bold_value=True, gap=6)
        row(None, f"{e['school']}, {e['city']}")
    y += 14
    layout.run(left, y, "Kenntnisse", 13, True)
    y += 22
    row("Fachlich", ", ".join(p["skills"]))
    y += 14
    layout.run(left, y, "Sprachen", 13, True)
    y += 22
    for name, level in p["languages"]:
        row(name, "Muttersprache" if level == "native" else f"verhandlungssicher ({level})")
    y += 14
    layout.run(left, y, "Hobbys", 13, True)
    y += 22
    row(None, ", ".join(p["interests"]))
    y += 30
    layout.run(left, y, f"{p['city']}, 12.03.2026", 10)
    layout.run(left, y + 16, f"{p['first']} {p['last']}", 10)
    exp = expected(p, "lebenslaufpdf", title=None, location=p["address"], links=[], summary=None, certifications=[])
    exp["education"] = [dict(x, location=e["city"]) for x, e in zip(exp["education"], p["education"])]
    return layout, exp


def europasspdf(p):
    """The Italian formato europeo as a PDF: labels on the left, aligned right, the values on the right."""
    lang, L = p["lang"], LANGUAGES[p["lang"]]
    layout = Layout()
    label_right, value_x = 200, 220
    y = 70

    def row(label, value, label_bold=False, value_bold=False, size=10):
        nonlocal y
        if label:
            layout.run(label_right - text_width(label, size, label_bold), y, label, size, label_bold)
        lines = wrap(value, 330, size, value_bold) if value else [""]
        for part in lines:
            if part:
                layout.run(value_x, y, part, size, value_bold)
            y += size * 1.4

    row("FORMATO EUROPEO PER IL", None, True)
    row("CURRICULUM VITAE", None, True)
    y += 20
    row("INFORMAZIONI PERSONALI", None, True)
    y += 6
    for label, value in [("Nome", f"{p['last']} {p['first']}"), ("Indirizzo", p["address"]), ("Telefono", p["phone"]),
                         ("E-mail", p["email"]), ("Nazionalità", "Italiana"), ("Data di nascita", "14/05/1992")]:
        row(label, value)
    y += 16
    row("ESPERIENZA LAVORATIVA", None, True)
    y += 6
    for e in p["experience"]:
        row("• Date (da – a)", period_text(lang, e["start"], e["end"], "month", current=L["current_caps"], capital=True))
        row("• Nome e indirizzo del datore", f"{e['employer']}, Via Esempio 1, {e['city']}")
        row("• Tipo di impiego", e["role"], value_bold=True)
        row("• Principali mansioni", "; ".join(e["bullets"]))
        y += 10
    row("ISTRUZIONE E FORMAZIONE", None, True)
    y += 6
    for e in p["education"]:
        row("• Date (da – a)", f"{e['start'][0]} – {e['end'][0]}")
        row("• Nome e tipo di istituto", e["school"])
        row("• Qualifica conseguita", e["degree"], value_bold=True)
        y += 10
    row("MADRELINGUA", "Italiano", True)
    others = [(n, lv) for n, lv in p["languages"] if lv != "native"]
    row("ALTRE LINGUE", None, True)
    for name, level in others:
        row(None, name, value_bold=True)
        row("• Capacità di lettura", "buono")
    y += 10
    row("CAPACITÀ E COMPETENZE", None, True)
    row("TECNICHE", ", ".join(p["skills"]), True)
    exp = expected(p, "europasspdf", name=f"{p['last']} {p['first']}", title=None, location=p["address"], links=[], summary=None,
                   certifications=[], interests=[])
    exp["experience"] = [dict(x, location=f"Via Esempio 1, {e['city']}", details=1) for x, e in zip(exp["experience"], p["experience"])]
    exp["education"] = [dict(x, **expected_period((e["start"][0], None), (e["end"][0], None))) for x, e in zip(exp["education"], p["education"])]
    exp["languages"] = [{"name": "Italiano", "level": "native"}] + [{"name": n, "level": None} for n, _ in others]
    return layout, exp


# ---------------------------------------------------------------------------------------------------------- PDF writer

def pdf_string(text):
    data = text.encode("cp1252")
    out = bytearray(b"(")
    for byte in data:
        if byte in b"()\\":
            out += b"\\" + bytes([byte])
        elif 32 <= byte < 127:
            out.append(byte)
        else:
            out += f"\\{byte:03o}".encode()
    return bytes(out + b")")


def write_pdf(path, layout, scan=False):
    """A minimal PDF of the layout, in Helvetica and Helvetica-Bold with WinAnsiEncoding. A scan draws a grey page with
    no text at all."""
    objects = []

    def add(body):
        objects.append(body)
        return len(objects)

    font = add(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
    bold = add(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>")
    pages_id = len(objects) + 2 * len(layout.pages) + 1
    page_ids = []
    for runs in layout.pages:
        if scan:
            content = b"0.85 g 40 60 515 720 re f 0.2 g 60 700 300 12 re f 60 680 260 8 re f 60 660 280 8 re f"
        else:
            parts = []
            for x, baseline, text, size, is_bold in runs:
                parts.append(b"BT /F%d %g Tf 1 0 0 1 %.2f %.2f Tm " % (2 if is_bold else 1, size, x, 842 - baseline) + pdf_string(text) + b" Tj ET")
            content = b"\n".join(parts)
        compressed = zlib.compress(content, 9)
        stream = add(b"<< /Length %d /Filter /FlateDecode >>\nstream\n" % len(compressed) + compressed + b"\nendstream")
        page_ids.append(add(b"<< /Type /Page /Parent %d 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 %d 0 R /F2 %d 0 R >> >> /Contents %d 0 R >>"
                            % (pages_id, font, bold, stream)))
    pages = add(b"<< /Type /Pages /Kids [" + b" ".join(b"%d 0 R" % i for i in page_ids) + b"] /Count %d >>" % len(page_ids))
    assert pages == pages_id
    catalog = add(b"<< /Type /Catalog /Pages %d 0 R >>" % pages)
    info = add(b"<< /Producer (PrestoCV synthetic corpus) >>")
    out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = []
    for index, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % index + body + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1)
    for offset in offsets:
        out += b"%010d 00000 n \n" % offset
    out += b"trailer\n<< /Size %d /Root %d 0 R /Info %d 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objects) + 1, catalog, info, xref)
    with open(path, "wb") as handle:
        handle.write(out)


# ---------------------------------------------------------------------------------------------------------- output

def save(index, folder, form, kind, content, exp):
    os.makedirs(os.path.join(OUT, folder), exist_ok=True)
    entry = {"id": f"{folder}/{form}", "language": exp["language"], "form": form, "kind": kind, "expected": f"{folder}/{form}.expected.json"}
    if kind == "text":
        with open(os.path.join(OUT, folder, f"{form}.txt"), "w", encoding="utf-8") as handle:
            handle.write(content)
        entry["source"] = f"{folder}/{form}.txt"
    else:
        layout = content
        with open(os.path.join(OUT, folder, f"{form}.layout.json"), "w", encoding="utf-8") as handle:
            json.dump(layout.json(), handle, ensure_ascii=False, separators=(",", ":"))
        write_pdf(os.path.join(OUT, folder, f"{form}.pdf"), layout)
        entry["source"] = f"{folder}/{form}.layout.json"
        entry["pdf"] = f"{folder}/{form}.pdf"
    with open(os.path.join(OUT, folder, f"{form}.expected.json"), "w", encoding="utf-8") as handle:
        json.dump(exp, handle, ensure_ascii=False, indent=1)
        handle.write("\n")
    index.append(entry)


def main():
    index = []
    first_of_language = set()
    for p in PEOPLE:
        folder = p["id"]
        for form, render in [("chat", chat), ("word", word), ("latex", latex)]:
            text, exp = render(p)
            save(index, folder, form, "text", text, exp)
        if p["lang"] == "it":
            text, exp = europass(p)
            save(index, folder, "europass", "text", text, exp)
        if p["lang"] == "de":
            text, exp = lebenslauf(p)
            save(index, folder, "lebenslauf", "text", text, exp)
        if p["lang"] not in first_of_language:
            first_of_language.add(p["lang"])
            layout, exp = linkedin(p)
            save(index, folder, "linkedin", "layout", layout, exp)
        else:
            layout, exp = wordpdf(p)
            save(index, folder, "wordpdf", "layout", layout, exp)
            layout, exp = railpdf(p)
            save(index, folder, "railpdf", "layout", layout, exp)
        if p["id"] == "de-lena":
            layout, exp = lebenslaufpdf(p)
            save(index, folder, "lebenslaufpdf", "layout", layout, exp)
        if p["id"] == "it-giulia":
            layout, exp = europasspdf(p)
            save(index, folder, "europasspdf", "layout", layout, exp)
    # Hand-written fixtures of the traps a CV sets, with their hand-written expectations
    traps = os.path.join(OUT, "traps")
    for name in sorted(os.listdir(traps)):
        if name.endswith(".txt"):
            stem = name[:-len(".txt")]
            with open(os.path.join(traps, f"{stem}.expected.json"), encoding="utf-8") as handle:
                language = json.load(handle)["language"]
            index.append({"id": f"traps/{stem}", "language": language, "form": "trap", "kind": "text",
                          "expected": f"traps/{stem}.expected.json", "source": f"traps/{name}"})
    scan = Layout()
    os.makedirs(os.path.join(OUT, "scan"), exist_ok=True)
    write_pdf(os.path.join(OUT, "scan", "scan.pdf"), scan, scan=True)
    with open(os.path.join(OUT, "index.json"), "w", encoding="utf-8") as handle:
        json.dump(index, handle, ensure_ascii=False, indent=1)
        handle.write("\n")
    print(f"{len(index)} fixtures in {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
