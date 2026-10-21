# 0027. Import a CV from its text with rules, in a portable core, every value traced to its source

- **Status:** Accepted
- **Date:** 2026-10-20
- **Supersedes:** ADR 0020, "Import an existing CV as a draft, checked against its own text" (Accepted on 2026-10-03 on the branch `chore/192-import-adr`, never merged)
- **Related:** [ADR 0007](0007-each-package-owns-its-model.md), [ADR 0012](0012-legacy-targets-during-migration.md), [ADR 0022](0022-ship-legacy-app-as-v1.md), [ADR 0023](0023-ground-the-ai-draft-in-the-description.md), [ADR 0025](0025-hold-the-legacy-app-to-the-separation-rules.md), [ADR 0026](0026-keep-the-core-portable-to-android.md), [R1](../rules.md#r1-packages-are-isolated-contexts-depend-only-along-documented-edges), [R2](../rules.md#r2-pure-layers-read-no-ambient-state), [R3](../rules.md#r3-ports-belong-to-the-consumer-adapters-live-in-their-own-targets), [R5](../rules.md#r5-views-render-view-models-present-neither-decides), [R6](../rules.md#r6-the-domain-is-rich-and-keeps-its-invariants), [R8](../rules.md#r8-untrusted-input-enters-through-one-validating-boundary), [R11](../rules.md#r11-platform-code-lives-only-in-adapters), [R13](../rules.md#r13-localisation-happens-at-the-edges), [R18](../rules.md#r18-pure-targets-stay-portable-to-android), issues #265 and #275

## Context

- **Typing a CV by hand is the problem.** The owner tried build 55 on 2026-10-20: "È una noia mortale creare un CV da zero senza AI" (it is deadly boring to create a CV from scratch without AI), while a chat assistant writes one in a minute. Most iPhones, the owner's among them, have no Apple Intelligence, so for most people the AI draft is not there.
- **People already have the text.** A CV written by a chat assistant, copied from Word, from an e-mail or from LinkedIn, or an old CV as a PDF. The analysis of #265 (`Analisi import CV.md`, 2026-10-20) lists every form a CV arrives in, what each carries and what iOS reads on the device. A text PDF is the most common form in Germany and Italy; pasted text is the universal fallback, also from paper through Live Text.
- **The owner decided on 2026-10-20** (#265):
  - the parsing core is a pure Swift target, tested on Linux, and a new ADR replaces ADR 0020;
  - fixtures are synthetic, never real CVs;
  - import works on every iPhone and iPad: rules alone segment and fill the CV, and the values the rules are unsure of are flagged for the person to check. Where the on-device model is available, it later improves the result by choosing among spans of the source text, never by writing text.

  This ADR was accepted on 2026-10-21 on those decisions: the core first, rules alone on every iPhone, pasted text and PDFs in version 1. Placing the core in the `PrestoCVCore` package is a technical choice that follows from "the core first".
- **#275 brings the first two forms into version 1:** pasted text and text PDFs (phases F0 and F1 of the analysis). The LinkedIn archive, the camera and scans, the model's help and Word files come later.
- **ADR 0020 was written when a server was planned.** It grew AI Drafting into import, checked a model's draft against the text with `CVTailoring`'s content checks, and sent long texts to the server. `CVTailoring` is not in `main` ([ADR 0005](0005-remove-ai-tailoring-and-json-resume.md)), there is no server before version 2, and a rules-only import writes no text that a check would have to catch.
- **The core must stay portable** to Android ([ADR 0026](0026-keep-the-core-portable-to-android.md), R18): no Apple-only import and no bundle in a pure target, and as few calls of the full Foundation as possible.

## Decision

**1. A pure core, `PrestoCVImporting`, in the `PrestoCVCore` package.**
- It is a target of its own next to `PrestoCVDomain` (domain and application layer of the CV Import context). It builds and tests on Linux, imports no Apple-only module, reads no bundle and no ambient state, and has no platform condition (R2, R11, R18).
- **It imports `PrestoCVDomain`**, a new edge inside the package, documented in [modules.md](../modules.md). The import reads the CV's own value objects and rules rather than copying them (R6): an e-mail address is one only if `EmailAddress` accepts it, a phone number if `PhoneNumber` does, a link if `WebLink` does; a level is a `LanguageProficiency`; a period is checked with `Period.make`. `PrestoCVDomain` does not import it.
- **It owns its draft model**, `ImportedCV`, because a `CV` has no provenance. The mapping to a `CV` belongs to the integration layer at migration step 5 ([ADR 0007](0007-each-package-owns-its-model.md)); version 1 maps to the legacy `CVModel` in the app (5 below).

**2. One intermediate representation.** Every reader produces an `ExtractedLayout`, and the core turns it into a `SourceDocument`:
- **`ExtractedLayout`** is what a reader saw: for pasted text, its lines; for a PDF, per page, the words with their box and their style (font size, bold), in the reader's order. It is untrusted input (R8).
- **`SourceDocument`** is the document in reading order: blocks (a line, a heading, a list item, a row of cells) with their page, box, column and style when the PDF gives them, over one canonical text that every span points into. Spans count Unicode scalars, the same on every platform.
- **The page analysis is in the core,** so it is tested on Linux: words into lines and cells, a sidebar told from a table by what its left column holds, the reading order (the wider column first), and the headers, footers and page numbers that repeat on every page.
- **Normalisation is a closed list of rules,** each tested: the Markdown of chat assistants (headings, bold, bullets, tables, rules, links; emphasis only between word boundaries, escapes only before punctuation) and their opening and closing sentences; the ligatures (ﬁ, ﬂ…); a word hyphenated at the end of a line, joined only when the next line starts in lower case, losing a visible hyphen and nothing else after a soft one; icon glyphs of the private-use area and symbols used as labels; soft hyphens and zero-width characters. The canonical text is the text after these rules, and nothing else is changed.

**3. Rules only, and nothing invented.**
- **Sections** are found by their headings, from a closed vocabulary in English, Italian, German, Spanish, French and Portuguese with their synonyms, the labels of the Europass and of the Italian "formato europeo", and the German Lebenslauf's. A heading the vocabulary does not know, but that the text marks as one (Markdown, bold or a larger font in a PDF, capitals), opens a section of unknown kind.
- **Fields are read by closed rules:** the name, the contacts (only from the head of the CV or its personal details, never from references), the summary, entries anchored to their dates (role, employer, place, period, bullets), education, skills, languages and their levels, certifications and interests. Dates and periods are read in the six languages' forms ("03/2019 – heute", "da marzo 2019 a oggi", "2016–2020", "seit 2019", "Jan 2020 – Present").
- **Provenance.** Every value is `Sourced`: the value, the spans it was quoted from, and, for a value that a rule read (a period, a level), the rule. A value is always a quote of the canonical text, or a reading of a quote by a closed rule. A final gate checks every value against its spans, so the guarantee is checked, not only built in.
- **What is not read is never dropped silently:**
  - a value the rules are unsure of is kept and flagged with a reason (for example "role or employer", "name by position", "level not CEFR"), and the flags form the **review list**;
  - text that fits no field is kept, with its section, as the **text not imported**, which the person can copy;
  - only noise is left out, each piece with its reason: repeated page headers and footers, page numbers, the opening and closing sentences of a chat answer, Markdown rules, the durations LinkedIn computes ("(2 years 3 months)"), the place and date of a signature, the Italian consent to data processing.
- **Levels:** a language keeps a level only when the text states a CEFR level or that it is a native language. "Fließend", "buono" or "Professional working" leave the language without a level, with the words kept for the review.
- **The output** is an `ImportedCV`, its review list, the text not imported, the noise left out with its reasons, and the language the CV is written in, told from the core's vocabulary.

**4. Ports, owned by the core (R3).**
- **The text sources.** The edge reads the text: a `PasteButton` (no paste prompt) or a text field. The core's `PlainTextReader` turns it into an `ExtractedLayout`; a plain-text file later takes the same path.
- **`PDFTextExtracting`**: the bytes of a PDF in, an `ExtractedLayout` out, with untyped `throws` so that cancellation passes. The adapter is **`PrestoCVImportingPDFKit`**, a target of its own (iOS and macOS, every file wrapped in its platform condition): PDFKit's words with their boxes and fonts, and nothing decided about their order. It holds to the limits as it reads: a page whose text is longer than the characters left is refused before its glyphs are read, its words are counted as they are read, and the reading stops in the middle of a page once its task is cancelled.
- **`ImportCV`**, the use case, validates the input first (R8): the bytes of a PDF, its pages, the characters of a text and of the extracted text are bounded, and so is a PDF's geometry: its words before the page analysis, its lines and cells before the columns are looked for, and the analysis's work, counted in steps of sweeps over sorted values, which a cancelled task stops. An empty, encrypted or unreadable document, or one without a text layer (a scan), is a typed `ImportError`. The app words it (R13); a scan is told to copy and paste the text instead.

**5. Version 1 uses the core from the legacy app** ([ADR 0022](0022-ship-legacy-app-as-v1.md), [ADR 0025](0025-hold-the-legacy-app-to-the-separation-rules.md)).
- New CV and the first run offer a third way to start, "Paste or import a CV", next to the blank CV and the examples, in the six languages.
- The import screen takes pasted text or a PDF: from Files (`fileImporter`), pasted after "Copy" in Files (the same `PasteButton` takes text or a PDF), or opened in the app from the share sheet ("Open in PrestoCV": the app declares PDFs at the alternate rank, copied, never opened in place, and deletes the copy once the import is done with it, with a CV or without). Its view model calls the use case in a task of its own, which the screen cancels when it goes away; the factory makes it with the PDFKit adapter. The views hold no rule (R5).
- A mapper in the app turns the `ImportedCV` into an unsaved `CVModel`, as the AI draft's mapper does. The editor opens it as a new CV, as it opens an example, with a notice that shows the values to check and the text not imported, ready to copy. A language without a CEFR level has no place in the legacy model, which requires one: it goes to the text not imported, with its words, and is listed for the review.
- The provenance serves the review and is not saved with the CV.

**6. The phased plan.**

| Phase | Content | When |
|---|---|---|
| **F0** | This ADR; the core's types; the fixture corpus and the contract table | #275, version 1 |
| **F1** | Pasted text and text PDFs, from Files, the clipboard or "Open in PrestoCV"; the review in the editor | #275, version 1 |
| F2 | LinkedIn's data archive (ZIP of CSV files, a ZIP reader under MIT that builds on Linux), the XML a Europass PDF carries, JSON Resume | after version 1 |
| F3 | The camera, photos, scans and screenshots: VisionKit's document camera in the app's `Platform/` folder, Vision's `RecognizeDocumentsRequest` in an adapter of its own; OCR for a PDF without text | after version 1 |
| F4 | The on-device model: a port that chooses among the candidate spans of one entry at a time, never writing text | after version 1 |
| F5 | Word, ODT and RTF files; a guide to export DOC and Pages files as PDF | after version 1 |

**7. What carries over from ADR 0020, and what does not.**
- **Carried over:**
  - an import is a draft the person reviews before it is a CV, and it says nothing its document does not say;
  - the camera is a view in `Platform/`, not an adapter; the text recognition is an adapter target of its own (F3);
  - LinkedIn's archive is read in memory, under limits, and only its six named files (F2); no scraping, ever;
  - imported documents are untrusted input (R8), bounded before they are read;
  - images and PDFs never leave the device.
- **Not carried over:**
  - **no server and no model in the first phases.** Rules structure the text; the model only chooses among spans, later (F4). So there is no retry loop and no device-or-server rule;
  - **no `CVTailoring` checks.** The import's own grounding replaces them: every value is a span of the text, by construction and by the final gate;
  - **not in AI Drafting.** The core lives in `PrestoCVCore` (Alternatives);
  - **geometry is part of the intermediate representation,** so the reading order is decided in the core and tested on Linux. ADR 0020's `ExtractedDocument` held text only;
  - **the language is told by the core's vocabulary,** the same on every device, not by a device's recogniser (the lesson of #244).

## Consequences

- **Every iPhone and iPad can import,** with no model, no permission and no network. Pasting needs no prompt, and Files gives access to the chosen file only.
- **The rules are measured, not trusted.** A contract table runs the synthetic corpus: two people per language, each in several forms (a chat assistant's Markdown answer, plain Word text, the Italian formato europeo, the German tabular Lebenslauf, the reading order of LinkedIn's PDF, the text of a LaTeX PDF), plus rows for the traps: a sidebar, contacts in references, a signature's date, "ATTUALE", LinkedIn's durations, levels as bars, icons as labels, "seit 2019", the dates of a Lebenslauf's left column. Each fixture lists its expected fields; the table reports, per language and form, the values found, missed, misplaced and invented. **Invented values block the release;** a new defect adds a row before its fix, and rows are never removed.
- **The rules will miss things.** Roles and employers without a marker are told apart by the CV's own order and flagged; a creative layout or an unknown heading leaves text not imported. The person sees both. The model (F4) is the planned help.
- **PDFKit's reading order is not trusted.** The adapter hands over words with boxes, and the core orders them. Its contract test, on Apple hosts, compares what PDFKit reads from the fixture PDFs with the layouts the Linux tests use, and requires each fixture PDF to import through PDFKit exactly as through its recorded layout.
- **PDFKit's character boxes skip its line breaks** (FB16264926): `characterBounds(at:)` has no box for the line breaks that `PDFPage.string` holds, so each one shifts the boxes of the rest of the page. The adapter walks the string and the boxes together; the contract test would see a new shift.
- **modules.md gains `PrestoCVImporting` and `PrestoCVImportingPDFKit`,** the edge from `PrestoCVImporting` to `PrestoCVDomain`, the legacy app's two new imports, and the planned edges of the migration: `PrestoCVIntegration` imports `PrestoCVImporting`, `PrestoCVComposition` imports the adapter. The checker's `rules.json` declares both targets and their tests. R8 lists imported documents and their text among untrusted input. The glossary gains **Import**, **Source document**, **Review list** and **Text not imported**.
- **The legacy model loses two things** until the migration: a language without a CEFR level, and the personal details a German or Italian CV states (date of birth, nationality), which `PersonalDetails` does not have (#214). Both stay in the text not imported.
- **Enforced by:**
  - the compiler: `PrestoCVImporting` depends only on `PrestoCVDomain`, so it cannot reach PDFKit or a framework of the app;
  - the checker: the allow-lists, R2, R11 and R18 on the core; R5 and R17 on the legacy app's new view model and views;
  - tests: the contract table and the unit tests of each rule on Linux; the adapter's contract test on Apple hosts; the view model's tests; UI tests that paste a fixture and open a fixture PDF;
  - review: that no view holds a rule, and that the adapter opens no connection.

## Alternatives considered

- **A target in AI Drafting (`CVGeneratorAI`), as ADR 0020 and the analysis proposed.** A rules-only import has no model, and R1 would forbid it to read `EmailAddress`, `PhoneNumber`, `WebLink`, `LanguageProficiency` and `Period.make`, so it would copy them, as ADR 0020 had to copy Authoring's bounds. The model's help (F4) needs a FoundationModels adapter for the import's port; it can be a second adapter target, or the drafting adapter can implement the port through the app's composition. That choice is left to F4.
- **A package of its own.** Clear borders, but the same copies of the value objects, and one more package to wire into the project and CI for a target that only Authoring's types feed.
- **In `PrestoCVDomain` and `PrestoCVApplication`.** Authoring would carry the vocabulary of six languages, the page analysis and the provenance types of a single use.
- **Have the on-device model structure the text, with the rules as a fallback.** Most devices have no model, its context holds a short CV at best, and it paraphrases and moves facts between entries ([ADR 0023](0023-ground-the-ai-draft-in-the-description.md)). The owner decided that rules alone serve every device.
- **Trust PDFKit's reading order.** It mixes a sidebar into the main column, and Apple's forum reports wrong orders and character boxes on iOS 18. Ordering in the core is testable on Linux.
- **Drop the text that fits no field.** Nothing the person wrote may vanish without their seeing it (owner, #265).
- **Map words such as "fluent" to a CEFR level.** A level the text does not state would be invented.
- **Keep the provenance with the saved CV.** It would need a new schema; it serves the review, and the review ends when the person saves.
