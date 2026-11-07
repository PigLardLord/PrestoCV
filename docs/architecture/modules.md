# Packages and targets

This is the authoritative list of production modules and of what each may import. The checker's `rules.json` must agree with it in both directions ([ADR 0006](adr/0006-enforce-architecture-mechanically.md)):

- every target listed here has a rule, or is declared `notYetImplemented`;
- no rule allows an import this file does not allow. Rules may be stricter, never looser;
- every dependency declared in a `Package.swift` must be an allowed import.

A new target, or a new edge between targets, changes this file in the same pull request.

Notation:
- **May import** lists every module the target may `import`. Swift and Foundation are always allowed; in domain targets only as value types (R2).
- The platform column reads iOS / macOS / Linux / Android. **Linux ✓** means the target must build and pass its tests on Linux in CI. **Android ✓** means it must also build for Android (arm64, API level 28) in CI; its tests do not run there yet ([ADR 0026](adr/0026-keep-the-core-portable-to-android.md)).

Test targets and test-support targets are described below each package. The checker applies only its import allow-lists to them.

---

## Package `DiagnosticLogging` — Diagnostic logging

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `DiagnosticLogging` | port, value types and decorators | iOS, macOS, Linux ✓, Android ✓ | Foundation |
| `DiagnosticLoggingOSLog` | outbound adapter | iOS, macOS | `DiagnosticLogging`, `os` |

A leaf package that depends on no other package ([ADR 0030](adr/0030-log-through-one-interface-that-carries-no-cv-content.md)). `PrestoCVCore`, `CVPDFExporter` and `CVGeneratorAI` may depend on its `DiagnosticLogging` target, and only on that one: an exception to the forbidden edges between the three packages, as `DiagnosticTrace` is.

**`DiagnosticLogging`**
- **The port, `DiagnosticLogger`:** one synchronous `log(_:)` that never throws, with the shorthands `debug`, `info`, `notice`, `error` and `fault`.
- **The entry, `LogEntry`:** a level, a `LogCategory` each module declares once, an event that is a `StaticString`, and fields of a closed set of kinds: `count`, `duration`, `flag`, `token` (a `StaticString`), `identifier` (a UUID) and `error`, which is written as its type and the `logCode` of a `LoggableError`, never as its description. So no value of a CV can reach a line. `line` writes the event and its `key=value` pairs.
- **The decorators:** `FanOutLogger`, `MinimumLevelLogger` and `SilentLogger`, for previews.
- **`Stopwatch`:** the time a step took, on an injected `Clock`.
- No platform condition, no Apple-only import, no bundle (R11, R18).

**`DiagnosticLoggingOSLog`** writes each entry to the unified log: one `os.Logger` per category of the subsystem, the levels mapped one to one, and the line as public text. Only the composition root makes one (R4). Every file is wrapped in `#if canImport(os)`.

**Test support and tests.**
- `DiagnosticLoggingTestSupport` may import `DiagnosticLogging`, Foundation, Synchronization. It holds `RecordingLogger`, which records the entries under a `Mutex`, and `TickingClock`, a `Clock` that moves on by one step at every reading.
- **`DiagnosticLoggingTests`** may import `DiagnosticLogging`, `DiagnosticLoggingTestSupport`, Testing, Foundation. They test the lines, the decorators and the stopwatch, on Linux too.
- **`DiagnosticLoggingOSLogTests`** (Apple hosts) may import `DiagnosticLoggingOSLog`, `DiagnosticLogging`, Testing and `os`.

---

## Package `DiagnosticTrace` — Trace of a test build

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `DiagnosticTrace` | port, value types, decorators and rules | iOS, macOS, Linux ✓, Android ✓ | `DiagnosticLogging`, Foundation, Synchronization |
| `DiagnosticTraceFiles` | outbound adapter (the store) | iOS, macOS, Linux ✓ | `DiagnosticTrace`, `DiagnosticLogging`, Foundation, Synchronization |
| `DiagnosticTraceDistribution` | outbound adapter (how the app was installed) | iOS, macOS | `DiagnosticTrace`, StoreKit |

Each step of the AI draft and of the import, with the text it read and wrote, kept on the device in TestFlight and Debug builds only ([ADR 0032](adr/0032-record-each-step-of-the-ai-draft-and-the-import-in-test-builds.md)). It carries CV content, so it is a package of its own, apart from `DiagnosticLogging`, which never does. It depends on `DiagnosticLogging` only. `PrestoCVCore` and `CVGeneratorAI` may depend on its `DiagnosticTrace` target, and only on that one; only the composition root imports its adapters and makes its recorder, gate and decorators, which the checker's `compositionOnly` rule enforces.

**`DiagnosticTrace`**
- **The port, `DiagnosticTracer`:** `begin(kind)` opens a run of a kind (`aiDraft` or `textImport`) and returns its `TraceRunRecording`, which records steps and finishes with an outcome; `record(_:_:into:)` adds a step to the run whose `TraceScope` the work is in (`within` sets it: the run, `suppressed` or none; a step outside a run is dropped); `mirror(_:)` takes a log entry. Every call is synchronous and never throws.
- **The values:** `TraceRun` (id, kind, start, build, steps, outcome), `TraceStep` (sequence, elapsed time, a `TraceStepName` from a closed set, ordered fields) and `TraceField`, whose `TraceValue` is a text cut at 32 KB, a count, a flag, a duration or a token.
- **The decorators:** `NoTracer`, for previews and tests that do not look at the trace; `GatedTracer(gate:next:)`, which drops what comes while its gate is closed; `TracingLogger(tracer:next:kinds:)`, a `DiagnosticLogger` that mirrors each entry into the run of the work's scope, or into the session events when the work is in no run.
- **The recorder, `TraceRecorder`:** keeps each open run under its size cap and hands every new state to a `TraceStoring`, on an injected clock, time source and id generator (R2).
- **The gate rule:** `ConstantGate` for a Debug build, and `DistributionGate`, open only for a verified TestFlight install (`DistributionAnswer.sandbox`) through the port `DistributionReading`; everything else fails closed.
- **The rules of the files:** the JSON document of a run (schema 1, keys sorted), its plain-text summary (`TraceSummary`), the ten runs kept (`TraceRetention`), the 200 session events kept (`TraceSessionLog`), and the port `TraceReading`, through which the diagnostics screen lists and shares the runs.
- No platform condition, no Apple-only import, no bundle (R11, R18).

**`DiagnosticTraceFiles`** is the store, `TraceFileStore`: one folder, made on the first write, excluded from backup, with files under complete protection on iOS; per run a JSON document and a summary; the session's events. It writes on one task off the main actor, only the latest state of each run, and logs a failure through `DiagnosticLogger` under the category `trace`. It makes the copies to share in a temporary folder.

**`DiagnosticTraceDistribution`** reads `AppTransaction.shared`, never `refresh()`, and maps its environment to a `DistributionAnswer`. Every file is wrapped in `#if canImport(StoreKit)`, and the manifest adds the target on Apple hosts only.

**Test support and tests.**
- `DiagnosticTraceTestSupport` may import `DiagnosticTrace`, Foundation, Synchronization. It holds `RecordingTraceStore`, `RecordingTracer` (the real recorder on a stopped clock, with the runs it recorded), `FixedDistribution` and `StoppedClock`.
- **`DiagnosticTraceTests`** may import `DiagnosticTrace`, `DiagnosticTraceTestSupport`, `DiagnosticLogging`, `DiagnosticLoggingTestSupport`, Testing, Foundation. They test the recorder, the gate's truth table, the decorators, the document, the summary and the retention, on Linux too.
- **`DiagnosticTraceFilesTests`** may import `DiagnosticTraceFiles`, `DiagnosticTrace`, `DiagnosticLogging`, `DiagnosticLoggingTestSupport`, Testing, Foundation, Synchronization. They write to a temporary folder, on Linux too; a spy of the folder protection records its calls under a `Mutex`.

---

## Package `PrestoCVCore` — CV Authoring and CV Import

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `PrestoCVDomain` | domain | iOS, macOS, Linux ✓, Android ✓ | Foundation |
| `PrestoCVApplication` | application | iOS, macOS, Linux ✓, Android ✓ | `PrestoCVDomain`, Foundation |
| `PrestoCVPersistence` | outbound adapter | iOS, macOS, Linux ✓, Android ✓ | `PrestoCVApplication`, `PrestoCVDomain`, Foundation, Glibc, Darwin, Android |
| `PrestoCVImporting` | domain + application (CV Import) | iOS, macOS, Linux ✓, Android ✓ | `PrestoCVDomain`, `DiagnosticLogging`, `DiagnosticTrace`, Foundation |
| `PrestoCVImportingPDFKit` | outbound adapter | iOS, macOS | `PrestoCVImporting`, `DiagnosticLogging`, PDFKit, UIKit, AppKit, CoreGraphics, Foundation |

**`PrestoCVDomain`**
- **`CV`**, the aggregate:
  - a typed identity (`CVID`);
  - `revision`, `createdAt` and `updatedAt`, settable only inside the package;
  - a private title, `PersonalDetails`, and ordered sections of entries;
  - the "has enough content to be saved" rule, `SaveRule`: a detail of the person is written, or a section has an entry. It reads plain values, so the legacy app's editor is judged by it too ([ADR 0025](adr/0025-hold-the-legacy-app-to-the-separation-rules.md));
  - duplication with a title composed by the caller.
- **`TextRules`**, the one rule for the text of a CV, applied by the initialisers and setters of every value type that holds text, so also by the store's reader and the draft mapper (R8). It removes without a word, in single-line and multi-line text alike: control characters other than line breaks (NUL and DEL included), bidirectional embeddings, overrides and isolates (U+202A to U+202E, U+2066 to U+2069), the marks U+200E, U+200F and U+061C, and tag characters (U+E0000 to U+E007F). A line break or tab in a single-line field becomes a space; a multi-line field (the summary, and the description of an experience, an education and a certification) keeps LF only: CRLF, CR, NEL, VT, FF, U+2028 and U+2029 become LF, a tab a space. ZWJ and ZWNJ are kept, and so are U+200B, U+2060, U+FEFF and U+00AD. A tag-sequence flag emoji (England, Scotland, Wales) loses its tags. The table is in the doc comment of `TextRules`; a test lists every text field by reflection, so a new one cannot skip the rule. The list of interests has one rule too, `CVSections.canonicalInterests(_:cleaningText:)` (trimmed, none empty, no two equal ignoring case): `setInterests` applies it with the cleanup, and the store's reader applies it without, to tell a canonical stored list from a corrupt one before the cleanup changes it.
- **`CVLimits`** and **`SaveVerdict`**: each text at most 16,384 UTF-8 bytes and 10,000 characters, all texts together at most 262,144 bytes, each section at most 200 entries. `CV.saveCheck()` says `ok`, `notEnoughContent`, `textTooLong(field)`, `tooManyEntries(section)` or `cvTooLarge`, and `canBeSaved` means `ok`. The limits equal or sit below the exporter's document validator, which the domain cannot import (R1), so a CV that can be saved maps to a document the validator accepts. A stored CV above a limit still opens, and is never cut; saving it is refused with the reason (`AuthoringError.textTooLong`, `.tooManyEntries`, `.cvTooLarge`).
- **Value objects:**
  - `PartialDate` (year or month precision, partial order);
  - `Period`, whose end is a date, "current" or "ended, date unknown" (`PeriodEnd.unknown`);
  - `SkillLevel` (1–5);
  - `LanguageProficiency` (CEFR + native);
  - `EmailAddress`, `PhoneNumber`, `WebLink`, `DocumentLanguage`, `DesignChoice`.
- **`Period.make(start:end:current:)`** is the single rule that turns loose data into a period, or into a typed `PeriodError`.
- **`FieldCheck`**: whether the text of an e-mail, phone or web-address field reads as one. E-mail addresses and web addresses are judged by `EmailAddress` and `WebLink`; a phone number needs a digit, and is otherwise written as the person likes. The legacy app's editor checks a field when the person leaves it.
- **`CVTitle`**: what a CV is called wherever it is named: its name, otherwise the name of its person, otherwise the role it is for; "Untitled CV", which the app words, only for a CV with none of the three; the name of a copy, that title followed by the app's word for a copy; and the labels of a list's rows, in which a CV whose title reads like another's takes the first number that gives a label no other row shows, so that no two rows read the same. A CV with none of the three, as a new one the editor stored before it was named, is numbered as the platform numbers an untitled document: "Untitled CV", "Untitled CV 2". The legacy app passes the name of a copy to the legacy duplicate operation.
- **`CVSubtitle`**: the line under the title of a CV in a row of the list, which never repeats the title: the name of the person and the role under a CV titled by its own name, only the role under one titled by its person, only the person under one titled by its role; an empty part leaves no separator.
- **`ExampleDraft`**: the fields (`CVField`) a draft started from an example leaves blank, who its person is and how to reach them.
- **`PDFFileName`**: the title of an exported PDF and the name of its file, from the person's name or the CV's, cleaned for every file system and cut to its bytes, around the pattern of the PDF's language, which the app gives from its catalog.
- **`ExportReadiness`**: whether a CV can be exported, and which field to fix: only the person's name is required; a missing e-mail address or phone number only warns.
- **`ExportPolicy`**: the page of version 1's export, A4 with a 43-point margin and 10 pages at most.
- The legacy app reads both while it exports through the legacy exporter; at migration step 5 the policy of `CVRendering` replaces them ([ADR 0025](adr/0025-hold-the-legacy-app-to-the-separation-rules.md)).
- Planned: projects (#54), photo (#53).

**`PrestoCVApplication`**
- **Ports:**
  - `CVRepository`: create, conditional update, load, list, conditional delete. Typed `RepositoryError`, not cancellable.
  - `CVStoreMaintenance`: restore from quarantine, erase every copy, purge quarantine.
  - `SampleCVSource`, `IDGenerator`, `TimeSource`. `TimeSource` is so named to avoid shadowing `Swift.Clock`.
- **Use cases:**
  - `NewCV`, `SaveCV` (create or conditional update, errors translated to `AuthoringError`, including `tooLarge`), `LoadCV`;
  - list (by last change), rename, duplicate, delete, start from a sample, determine onboarding;
  - `ChangeStoredCV`: renames a stored CV (trimmed, never blank), sets the language of its PDF, or changes the parts of its look that the person chose (`LookChange`: the parts chosen, and the look the export sheet showed; the others stay as the store holds them), reading it again just before it is stored, so nothing else changes; a look the stored CV has already is no change and stores nothing. It works through the `StoredCVs` port, generic over the store's own CV, which the legacy app implements over its stored CVs until the migration replaces them ([ADR 0025](adr/0025-hold-the-legacy-app-to-the-separation-rules.md)).
- **`ImportLegacyStore`**: the one-time import of the released app's store ([ADR 0022](adr/0022-ship-legacy-app-as-v1.md)). It reads the candidates of a `LegacyStore` port and hands each CV to a `LegacyImportTarget` port, which stores it as revision 1 with the times it carried, or answers `existing` when the store already holds that id. A source file is removed only after its copy is stored and reads back as what was mapped, and only while it still holds the exact bytes the run read (`LegacyRecord.Version`; the store compares the bytes and answers `LegacyRemoval`: removed, already gone, or changed, in which case the file stays and the report says `sourceChanged`); with removal off, never; a file that fails stays, byte for byte, and the `LegacyImportReport` says which and why (a code, never content), together with what was dropped per CV (`LegacyDrop`), also for a CV an earlier run stored, since that run may have stopped before its report. The source of a CV with drops is the durable record of the loss: `run` keeps it and lists it as awaiting acknowledgement, and `acknowledgeLosses(of:)` removes it, under the same bytes check, once the person has seen the losses (a source that changed since stays, and the next run reports its new losses) (a run that stops before then finds the CV stored and reports the same drops again). A second run changes nothing in the store.
- **Listing** returns the healthy CVs plus `StoreIssue`s: `corrupt`, `upgradeRequired`, `unreadable`, `tooLarge`, `quarantineFailed`.
- **`Autosave`**: when an editor writes what it shows. A second after the last change, at once on a flush (the app leaving the foreground, the editor being left); never when the content equals what is stored, so its edit time stays; a CV the store does not hold yet only once it is worth storing. After each write the content is compared with the store again: a change made while it ran, or one that undid it, is written next, and a flush goes on until the store holds what the form shows. A failed write leaves the content in memory and a `failed` status until a write succeeds or the content returns to what the store holds, and a write that runs meanwhile says `retrying`, not `writing`, so that it hides no failure (`hasUnresolvedFailure`); the error the write threw goes to a hook the caller gives (`onWriteFailure`), apart from the status. The store is known to hold the content (`storeHoldsTheContent`) only when no write runs and nothing differs: the end of a write that runs can leave something else there. A write the store cancels is no failure: the content stays to be written, and the flush passes the cancellation on. The write is told whether the store holds the CV, so that it needs nothing of the editor; it and the clock are given by the caller.

**`PrestoCVPersistence`**
- `FileCVRepository`:
  - one `CVFileV1` file per CV, named from its id;
  - atomic writes, with `complete` protection unless the composition root gives another class through `StoreOptions` (tests of the store's logic give none; [ADR 0009](adr/0009-persisted-schema-v1.md): what that means for a locked device and for CI hosts), and a read-back check before every write;
  - a failed write, delete, restore, erase or purge (the failures mapped to `writeFailed`) keeps the error it came from, as a `FailureCause` (domain, code, and the `errno` under a Cocoa error); the classified read, lock, listing and quarantine outcomes keep no cause, and the use cases drop it when they translate to `AuthoringError`;
  - every mutation under an exclusive `flock` on the store, from the C library of the platform: `Glibc`, `Darwin` or `Android` ([ADR 0026](adr/0026-keep-the-core-portable-to-android.md));
  - reads classified as described in R12;
  - `Quarantine/` with validated restore, erase and purge.
- `DirectoryLegacyStore` and `FileCVRepository.adopt`: the adapters of the legacy import. The directory store lists `cv_*.json`, reads only regular files within a size cap and never through a link (R8), and maps each through `LegacyCVFile` (the legacy shape, read as the released app reads it, with the look mapped as ADR 0022 says) to a domain CV; `LegacyPeriod` converts the period text only when it is an unambiguous range of two dates, and drops the rest. `adopt` runs under the store lock and keeps the legacy times, which `create` would reset; a legacy file is never read as schema 1, because the store lists only `*.cv.json`.
- `DirectorySampleCVSource`: sample CVs from an injected directory, in the same v1 format and through the store's own reader. They are kept in `PrestoCV/Resources/Samples/`, and the app ships them from the switch to the new stack on (version 1 ships the legacy samples).

**`PrestoCVImporting`** turns a CV someone already has into a draft, with rules only ([ADR 0027](adr/0027-import-a-cv-from-its-text-with-rules.md)). It is the CV Import context, packaged with Authoring because it reads Authoring's value objects and period rule instead of copying them: the only edge between two contexts inside this package, and it goes one way.
- **What a reader saw, `ExtractedLayout`:** the lines of a pasted text, or the words of each page of a PDF with their box and style. Untrusted input (R8), bounded by `ImportLimits`.
- **The document in reading order, `SourceDocument`:** blocks (a line, a heading, a list item, a row of cells) with page, box, column and style when there are any, over one canonical text. `SourceSpan`s count Unicode scalars.
- **The rules:**
  - `PlainTextReader` for pasted text, and `LayoutAnalyzer` for pages: lines, cells, a sidebar told from a table, the reading order, repeated headers and footers, page numbers;
  - normalisation: chat Markdown and chatter, ligatures, line-end hyphenation, icon glyphs;
  - `SectionVocabulary` and the segmentation by headings in six languages, Europass and Lebenslauf labels included;
  - the readers of names, contacts, dates and periods, entries, skills, languages and levels, certifications and interests.
- **The draft, `ImportedCV`:** every value is `Sourced`, with the spans it quotes and the rule that read it, if any. Values the rules are unsure of carry a check reason, and the review list collects them. Text that fits no field is kept as text not imported; noise is left out with its reason. A final gate checks every value against its spans.
- **The use case, `ImportCV`:** pasted text, or a PDF through the port **`PDFTextExtracting`**; both are untyped `throws` and cancellable, and both are read within one budget of work. Typed `ImportError`: empty, too large, too many pages, encrypted, unreadable, no text (a scan).
- **What it logs** through the `DiagnosticLogger` its initialiser takes ([ADR 0030](adr/0030-log-through-one-interface-that-carries-no-cv-content.md)), under the category `import`: the kind of input, its pages and characters, the sections by kind and the time taken; the headings not recognised and the lines left unplaced, as counts; a failure by kind, and the limit of the bounded reading it reached; a cancellation.
- No platform condition, no Apple-only import, no bundle (R11, R18). It is built for Android with the rest of `PrestoCVCore`.

**`PrestoCVImportingPDFKit`** implements `PDFTextExtracting` with PDFKit: each page's words with their box, font size and weight, in PDFKit's order, and nothing decided about the reading order, which the core decides. It checks the size, the page count and the encryption before it reads any text, refuses a page whose text is longer than the characters left before it reads the page's glyphs, counts the words as it reads them, and stops in the middle of a page once its task is cancelled. A word whose font PDFKit cannot name comes back without its weight, so the adapter draws the page with CoreGraphics and marks a word bold when its strokes are clearly heavier than the page's ([ADR 0027](adr/0027-import-a-cv-from-its-text-with-rules.md)). `characterBounds(at:)` has no box for the line breaks of `PDFPage.string`, so the adapter walks the two together. Through the logger its initialiser takes, it logs the pages and the words it read, and the limit that stopped it, which it throws as a `LimitReached` for the use case to word and log. Every file is wrapped in `#if canImport(PDFKit)`.

**Test support and tests.**
- **`PrestoCVImportingTests`** may import `PrestoCVImporting`, `PrestoCVDomain`, `DiagnosticLogging`, `DiagnosticLoggingTestSupport`, `DiagnosticTrace`, `DiagnosticTraceTestSupport`, Testing, Foundation. It holds the unit tests of every rule and the **contract table**: the synthetic corpus under `PrestoCVCore/Tests/ImportFixtures/` (texts, recorded page layouts and their PDFs, each with the fields it states), measured per language and form, and checked line by line: every line of every fixture is covered by a value, a text not imported or a left-out piece. No real CV is ever committed.
- **`PrestoCVImportingPDFKitTests`** (Apple hosts) may import `PrestoCVImportingPDFKit`, `PrestoCVImporting`, `DiagnosticLogging`, `DiagnosticLoggingTestSupport`, `DiagnosticTrace` (its `NoTracer`), Testing, Foundation, PDFKit, CoreGraphics, and CoreText, with which it draws hostile pages when it runs. Its contract test reads the fixture PDFs with PDFKit and compares the words with the recorded layouts that the Linux tests use.
- `PrestoCVCoreTestSupport` may import `PrestoCVApplication`, `PrestoCVDomain`, Foundation, Synchronization. It holds:
  - `InMemoryCVRepository`, `SteppingClock`, `SequentialIDGenerator`;
  - `ManualClock`, a `Clock` that moves only when a test moves it, for the timing of `Autosave`;
  - the **`CVRepository` contract suite**: round trip with timestamps, create twice, update bumps the revision, stale update and stale delete, 50 concurrent updates from one revision leave exactly one success, update after delete, listing order.
- File-store behaviour that an in-memory store cannot have is tested in the Core tests, not in the contract: mixed directory, unreadable, oversized and hostile files, restore, erase, purge, and two instances racing.

---

## Package `CVPDFExporter` — Design Catalog and Document Rendering

Standalone and portable. It has no dependency on any PrestoCV package ([ADR 0002](adr/0002-cvpdfexporter-standalone-and-portable.md)). Legacy targets are declared only on Apple hosts during the migration ([ADR 0012](adr/0012-legacy-targets-during-migration.md)).

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `CVDocumentModel` | published language | iOS, macOS, Linux ✓, Android ✓ | Foundation |
| `CVDesignCatalog` | domain + application | iOS, macOS, Linux ✓, Android ✓ | Foundation |
| `CVDesignCatalogFileStore` | outbound adapter | iOS, macOS, Linux ✓, Android ✓ | `CVDesignCatalog`, Foundation, Glibc, Darwin, Android |
| `CVBundledDesigns` | outbound adapter + resources | iOS, macOS, Linux ✓, Android ✓ | `CVDesignCatalog`, Foundation |
| `CVRendering` | application | iOS, macOS, Linux ✓, Android ✓ | `CVDocumentModel`, `CVDesignCatalog`, Foundation |
| `CVBundledHeadings` | outbound adapter + resources | iOS, macOS, Linux ✓, Android ✓ | `CVRendering`, Foundation |
| `CVRenderingWebKitSupport` | adapter support | iOS, macOS | `CVRendering`, WebKit, Foundation |
| `CVRenderingIOS` | outbound adapter | iOS | `CVRenderingWebKitSupport`, `CVRendering`, WebKit, UIKit, Foundation |
| `CVRenderingMacOS` | outbound adapter | macOS | `CVRenderingWebKitSupport`, `CVRendering`, WebKit, AppKit, Foundation |
| `CVRenderingPDFKitInspector` | outbound adapter | iOS, macOS | `CVRendering`, PDFKit, Foundation |
| *(future)* `CVRenderingServer` | outbound adapter | Linux | `CVRendering`, Foundation |

**`CVDocumentModel`**
- **`CVDocument`**, the package's public contract, also the JSON a backend accepts:
  - `schemaVersion` (other versions are rejected) and `language`;
  - the person: name, professional title, email, phone, location, website;
  - typed sections: summary, experience, education, skills, languages, certifications (name, issuer, year, URL, description), profiles, interests;
  - dates as `DocumentDate` and `DocumentPeriod` with `PeriodEnd` `present`, `date` or `unspecified`, never display strings.
- **Explicit JSON.** Sections are `{"kind": …}` objects and periods carry an `end` discriminator.
- **`CVDocumentValidator`** is the anti-corruption layer for documents from outside:
  - it checks the name, counts, dates and ratings;
  - it bounds text in UTF-8 bytes, per field and for the whole document, and refuses control characters and bidirectional overrides;
  - JSON arrives through `decode(json:)`, which checks the size before decoding.
- Pending: a committed JSON Schema.

**`CVDesignCatalog`**
- **`MarkupContract`**, version 1: elements, classes, section kinds, ratings, pseudo-classes. See [markup-contract.md](../../CVPDFExporter/Docs/markup-contract.md).
- **The CSS policy:** a tokenizer, an allow-list of properties and values, and canonical re-serialisation into `ValidatedStylesheet`, whose initialiser is internal.
- **`DesignPackageValidator`** takes raw bytes and returns a `ValidatedDesign`: manifest, stylesheet and PNG preview.
- **Customisation values:** `HexColor`, `Palette` (exists only with readable contrast) and `FontScheme` (a closed set).
- **Use cases:**
  - list, get, sync bundled designs (upgrade when newer);
  - **`InstallDesign`**: validate the raw bytes, then `DesignRenderingGate.verify`, then `DesignStore.save`. Nothing is stored unless both checks pass.
- **Ports:** `DesignStore`, `BundledDesignSource` (raw bytes), and **`DesignRenderingGate`**. The catalog owns the gate; `CVRendering` implements it, along the allowed Rendering → Catalog edge.

**`CVDesignCatalogFileStore`** holds `FileDesignStore`: the directory is injected, the index is written atomically under a lock (`flock`, from `Glibc`, `Darwin` or `Android`), and one instance serves the process. Every read validates the file again, so only validated designs leave the store.

**`CVBundledDesigns`** holds the bundled `.mcvt` files as resources, served as raw bytes through `Bundle.module`.

**`CVRendering`**
- **`DocumentHTMLBuilder`:**
  - produces the markup contract, with closed `Tag` and `Attr` enums and per-scalar escaping;
  - validates the language tag;
  - keeps only `WebLink`s, and prints each link's destination as its text;
  - formats dates in the document language.
- **`HeadingsCatalog`:** JSON heading tables per language plus an index, matched by BCP 47. An unsupported language is a typed error. It reads the tables as raw bytes through **`HeadingTableSource`**, its outbound port, and decodes them itself; only a tag that reads as BCP 47 reaches the source ([ADR 0026](adr/0026-keep-the-core-portable-to-android.md)).
- **`PDFRendering`**, the outbound port: `render(html:page:) async throws -> RenderedPDF`, with `data`, `pageCount` and `requiredPages`. `truncated` is derived from those.
- **`PDFInspecting`**, the outbound port that reads the page count and text of a PDF.
- **`RenderedDocument`:** the builder's output, meaning the HTML plus the exact text nodes it contains.
- **`DocumentCompleteness`:** every text node needs its own span of the PDF text, which no other node uses, ignoring case and spacing.
- **`FixtureRenderingGate`:** implements the catalog's `DesignRenderingGate`. It renders a fixture that uses every section with the candidate design, and requires a complete, untruncated PDF.
- **Policy:** the required fields and page limit, shared by preview and export.

**`CVBundledHeadings`** holds the heading tables as resources, served as raw bytes through `Bundle.module` by `BundleHeadingTableSource`. An Android app ships no SwiftPM bundle: its edge reads the same files from the app's assets and passes them through the same port ([ADR 0026](adr/0026-keep-the-core-portable-to-android.md)).

**`CVRenderingWebKitSupport`**
- `SecureWebViewConfiguration.compileRules()` is called once by the composition root: a block rule per network scheme, plus a block on every subresource type. `make(rules:)` then builds each configuration: JavaScript off for content, non-persistent store, media only on user action.
- `SingleLoadNavigationDelegate` loads the HTML string with no base URL, reports when that load has finished, and cancels every later navigation.
- `DocumentReadiness` waits until the document is complete and its fonts are ready. Its script runs in a content world of its own, with a timeout.
- Content blockers do not see `data:` URLs on Apple platforms: a test records this. None can enter the document, because the builder emits only http(s) links and the CSS policy has no `url()` (R8).
- A clicked link, which only happens in the preview, may open a connection to its host before the navigation is cancelled (a WebKit preconnect). Nothing is sent over it. A document's links and a refresh make no connection at all; tests record both.
- Every file is wrapped in `#if canImport(WebKit)`.
- **`CVRenderingWebKitSupportTests`** check each of these on iOS and macOS. Each network test has a control without the rules, which shows that the test can see a request.
- The control of the `file:` test cannot show a load on macOS 27: there WebKit itself blocks a `file:` image in a page loaded from a string under a `file:` base URL. The rules are proven against `file:` on the releases that load it (iOS 26 and 27, macOS 26); the test records which.
- On iOS the exporter's tests run through the shared `ExporterTests` scheme, which holds the new test targets only: the package scheme also builds the legacy targets, which do not build for iOS.

**`CVRenderingIOS`, `CVRenderingMacOS`**
- One `PDFRendering` implementation per platform ([ADR 0003](adr/0003-one-pdf-renderer-per-platform.md)). Every file is wrapped in its platform condition.
- On iOS the web view is never put in a window. A `UIPrintPageRenderer` with a fixed paper and printable area paginates it, and each page is drawn in turn into a `UIGraphicsPDFRenderer` context, with a check for cancellation before each one. No step waits on a print callback, so a stalled print cannot hang the export (#101); the load and the readiness wait have time limits.

**`CVRenderingPDFKitInspector`**
- `PDFInspecting` on PDFKit, used by the export workflow and by the native contract tests. Every file is wrapped in `#if canImport(PDFKit)`.

**Test support and tests.**
- **`CVRenderingTestSupport`** may import `CVRendering`, `CVDocumentModel`, `CVDesignCatalog`, `CVBundledHeadings` (the contract fixture prints the shipped Italian headings), Foundation. It holds `InMemoryDesignStore`, the **`DesignStore` contract suite** that it and `FileDesignStore` pass, and:
  - the **`PDFRendering` contract suite**:
    - the fixture must fit and contain every field;
    - page count per the inspector;
    - truncation reported;
    - `requiredPages` checked against an unlimited render;
    - deterministic pre-start cancellation;
  - `FakePDFRenderer`, which writes real uncompressed PDFs;
  - `MinimalPDFInspector`.
- **`CVRenderingIOSTests` and `CVRenderingMacOSTests`** run the contract suite against the real renderers with the PDFKit inspector: `xcodebuild test` on the iOS simulator, `swift test` on macOS. They also run the long-document pagination test, in-flight cancellation and the content-completeness test for every bundled design.

**Separate package `CVPDFExporterExamples`** holds the demos. The library package contains no executables (R14).

---

## Package `CVGeneratorAI` — AI Drafting

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `CVDrafting` | domain + application | iOS, macOS, Linux ✓, Android ✓ | Foundation |
| `CVDraftingFoundationModels` | outbound adapter | iOS 26, macOS 26 | `CVDrafting`, FoundationModels, Foundation |

**`CVDrafting`**
- **`CVDraft`:** plain `Sendable` structs; optional wherever the user may not have said it. A job has an optional start year, an optional end year and whether it is current.
- **Use case:** `DraftCV` validates the input, generates, then validates the output. Streaming follows the same path.
- **Ports:** `DraftGenerating` (untyped `throws`, cancellable) and `DraftAvailability`.
- **`DraftingError`:** one case per model failure.

**`CVDraftingFoundationModels`**
- Internal `@Generable` schema, a session with instructions, availability from `SystemLanguageModel`.
- Until it is implemented it throws a typed "unavailable" error; it never returns an empty draft.

**Test support.** `CVDraftingTestSupport` holds a fake generator and fixtures.

**The legacy target `CVGeneratorAI`**, which version 1 ships ([ADR 0022](adr/0022-ship-legacy-app-as-v1.md)), depends on `DiagnosticLogging` on Apple hosts: its use case takes a `DiagnosticLogger` and a `Clock` in its initialiser, and logs under the category `draft` the availability of the model and why not, the language of the description and the state of its data, a generation started, finished, cancelled or refused by the guardrails, with its time, the claims checked and withdrawn, as counts, and the check that rejected a request or a draft ([ADR 0030](adr/0030-log-through-one-interface-that-carries-no-cv-content.md)). It also depends on `DiagnosticTrace`: the use case, the model service and the claim checker take a `DiagnosticTracer`, and record each step of a draft with its text ([ADR 0032](adr/0032-record-each-step-of-the-ai-draft-and-the-import-in-test-builds.md)). Its tests may also import `DiagnosticLoggingTestSupport` and `DiagnosticTraceTestSupport`.

---

## Package `PrestoCVApp` — App integration and presentation

A local package next to the Xcode project. The compiler holds the app's layers too, and everything except the composition builds and tests on Linux.

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `PrestoCVWorkflowPorts` | app ports | iOS, macOS, Linux ✓, Android ✓ | `PrestoCVApplication`, `PrestoCVDomain`, Foundation |
| `PrestoCVIntegration` | app application layer | iOS, macOS, Linux ✓, Android ✓ | `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain`, `PrestoCVImporting`, `CVDocumentModel`, `CVDesignCatalog`, `CVRendering`, `CVDrafting`, Foundation |
| `PrestoCVPresentation` | inbound adapter | iOS, macOS, Linux ✓, Android ✓ | `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain` (both `internal import`), Observation, Foundation |
| `PrestoCVComposition` | composition root | iOS, macOS | everything above, plus `PrestoCVPersistence`, `PrestoCVImportingPDFKit`, `CVDesignCatalogFileStore`, `CVBundledDesigns`, `CVBundledHeadings`, `CVRenderingIOS` (iOS only), `CVRenderingMacOS` (macOS only), `CVRenderingWebKitSupport`, `CVRenderingPDFKitInspector`, `CVDraftingFoundationModels` |

**`PrestoCVWorkflowPorts`**
- The ports that view models consume: `CVEditing` (new, save, load) and `CVExporting` (untyped `throws`, so cancellation passes through).
- App value types: `ExportOutcome`, `ExportFailure`.

**`PrestoCVIntegration`**
- **Workflows**, implementing the ports:
  - `EditCVWorkflow`;
  - `ExportCVWorkflow`: from the editor snapshot, with the document language, through the renderer, then the completeness check on the actual PDF;
  - `BrowseDesigns`;
  - `DraftCVWithAI`: availability, then draft, then an unsaved CV plus its gaps;
  - `ImportCVWorkflow` (planned, [ADR 0027](adr/0027-import-a-cv-from-its-text-with-rules.md)): the import, then an unsaved CV plus its review list and the text not imported.
- **Mappers:** `CV → CVDocument`, `CVDraft → CV` and, when the import is wired in, `ImportedCV → CV`. They are exhaustive and deterministic, with typed dates. The draft mapper uses `Period.make` and reports every gap.

**`PrestoCVPresentation`**
- `@Observable @MainActor` view models whose public API holds presentation types only: status enums, and no domain types.
- **Saves** are serialised and coalesced, and every caller waits for its own edits to land.
- **Save and export** each have their own status, reset when a new intent starts.
- **Conflict** offers reload or save as a copy; **deleted elsewhere** offers save as a copy.
- **View-model initialisers do no I/O.** Loading happens in the view's `.task`, so the factory can be called on every view init.

**`PrestoCVComposition`**
- The only place that creates infrastructure (R4). The `@main` App type holds it in a `static let`. It owns:
  - file locations under Application Support;
  - one `FileCVRepository` and one `FileDesignStore`;
  - the web-view rule list, compiled once;
  - the platform renderer and the PDFKit inspector;
  - the AI adapter, the PDFKit reader of the import, `TimeSource`, `IDGenerator` and logger;
  - the `ScreenFactory`.
- **UI tests and previews** use the production `FileCVRepository` on a temporary directory seeded from fixture JSON. A launch argument selects it. No production target depends on a test-support target.

**Test support.** `PrestoCVAppTestSupport` holds fakes for the workflow ports.

---

## Xcode app target `PrestoCV` (iOS 26.5, macOS 26)

A native SwiftUI multiplatform target ([ADR 0004](adr/0004-native-multiplatform-app.md)). The checker maps each folder as its own target.

| Folder | Contents | May import |
|---|---|---|
| `App/` | `@main` (holds the composition), scenes and macOS commands; `#if os` allowed here | SwiftUI, `PrestoCVComposition`, `PrestoCVPresentation` |
| `Features/` | SwiftUI views per screen; `NavigationSplitView` navigation; no `#if` | SwiftUI, `PrestoCVPresentation` |
| `DesignSystem/` | tokens and reusable components | SwiftUI |
| `Platform/` | the platform shims: iOS-only modifiers wrapped for `Features/`, HTML and PDF previews, sharing, pasteboard, file import and export | SwiftUI, UIKit, AppKit, WebKit, PDFKit, QuickLook, UniformTypeIdentifiers, `CVRenderingWebKitSupport`, `PrestoCVPresentation` |
| `Resources/` | `Localizable.xcstrings`, sample CV JSON, assets | — |

**The legacy target `PrestoCV`**, which version 1 ships ([ADR 0022](adr/0022-ship-legacy-app-as-v1.md)), imports the legacy `PrestoCVCore`, `CVPDFExporter` and `CVGeneratorAI`, and also `PrestoCVDomain` and `PrestoCVApplication`, whose rules its view models call ([ADR 0025](adr/0025-hold-the-legacy-app-to-the-separation-rules.md)), and `PrestoCVImporting` with its PDFKit reader, for the import of version 1 ([ADR 0027](adr/0027-import-a-cv-from-its-text-with-rules.md)) and for a CV pasted in the AI draft ([ADR 0034](adr/0034-read-a-text-that-is-already-a-cv-with-the-import.md)), and `DiagnosticLogging` with `DiagnosticLoggingOSLog` ([ADR 0030](adr/0030-log-through-one-interface-that-carries-no-cv-content.md)), and `DiagnosticTrace` with `DiagnosticTraceFiles` and `DiagnosticTraceDistribution` ([ADR 0032](adr/0032-record-each-step-of-the-ai-draft-and-the-import-in-test-builds.md)):
- its entry point makes the one `OSLogDiagnosticLogger`, with the subsystem `com.PigLardLord.prestocv`, and its factory passes it to the import and to the AI draft; the construction moves into `PrestoCVComposition` with the app;
- its entry point and `App/AppEnvironment.swift`, and no other file, build the trace: the gate for the build, the recorder, the file store, and the `TracingLogger` in front of the native log; its factory passes the tracer to the import and to the AI draft, and the diagnostics screen reads the runs through `TraceReading`;
- it imports each declaration of the two by name (`import struct PrestoCVDomain.ExportPolicy`), since the legacy `PrestoCVCore` declares types with the same names;
- its adapters from the legacy `CVModel` to the plain values the rules read are in `PrestoCV/Shared/CoreRules/`;
- its mapper from an `ImportedCV` to an unsaved `CVModel` is in `PrestoCV/Features/Import/`, as the AI draft's is in `PrestoCV/Features/AIGeneration/`; the AI draft's view model reads a text that is already a CV through `PastedCVIntake`, in `PrestoCV/Features/AIGeneration/Services/`, which the factory builds from the same import and mapper ([ADR 0034](adr/0034-read-a-text-that-is-already-a-cv-with-the-import.md)); the PDFs it opens from the share sheet are declared in `PrestoCV/Info.plist`, which Xcode merges with the generated one;
- the checker holds it to R5 and R17, and its test target to R16.

---

## Tools

Packages under `Tools/` that check the repository. They are `tool` targets in `rules.json`, so the checker applies only their import allow-lists, and nothing in the app depends on them.

- **`Tools/ArchitectureCheck`**: the architecture checker ([ADR 0006](adr/0006-enforce-architecture-mechanically.md)). Its `ArchitectureCheck` executable may import SwiftSyntax, SwiftParser and Foundation.
- **`Tools/SourceChecks`**: the checks of source text, which read the repository and so cannot run in a test plan: the machines that run one have only the built products.
  - **What it checks:** the string catalog in its six languages and the keys the code uses; the rules the app's views follow (accent colours, button presses, the list's delete button); how the tests render views off screen (with Core Graphics, never through the GPU image of an `ImageRenderer`); release hygiene (console output, the privacy manifest, the linked products); the deployment targets (the project and every package manifest set iOS 26.5 or later: the web view's content rules let `object` and `embed` loads through on iOS 26.2, so the minimum is not lowered without a defence that does not rely on them, #180). The project file is read for every build setting that sets a release, and a manifest (`Package.swift` and `Package@swift-X.Y.swift`, in any case: a Mac's volume does not tell them apart) from its tokens, for the `platforms:` of its `Package` call: a platform written in a comment or a string is none, and whatever the reader cannot tell (a platforms list that is a variable, a release that is not a string or a `.vNN_N` constant, a source that cannot be read to its end) is a finding, because it could hide any value; so is a folder the scan cannot list, and so is any link or other entry that is not a folder or a regular file, as the scan never follows a link nor looks up its target. The manifests of the folders in `DeploymentTargets.hostOnlyFolders` (`Tools/`) may declare no iOS platform, and the validation prototype is not read. `Tools/Release/check-archive.sh` checks the same minimum on the archive (`MinimumOSVersion`), and a test holds its constant to the one of this check. The documents are checked too, over the files git tracks: every Markdown file is in English (by the share of the function words of each of the app's languages in it; the translated sections of the store listing are the only text left out), every path in the README's "Where things are" table exists and every top-level folder is in it, and the open-source files (`LICENSE`, `NOTICE`, `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`) exist and are linked from the README.
  - **Its target:** one test target, `SourceChecksTests`, which may import Testing and Foundation. It depends on no package, so it builds in seconds on Linux.
  - **Where it runs:** `swift test` runs it on the Linux CI job and, through `ci_scripts/ci_post_xcodebuild.sh`, on the Mac mini (the pull request check) and on the Xcode Cloud build host (the Release workflow).

---

## Dependency graph (summary)

```
PrestoCV (app) ─▶ PrestoCVPresentation ─▶ PrestoCVWorkflowPorts ─▶ PrestoCVApplication ─▶ PrestoCVDomain
     │                                     ▲                                                  ▲
     │                     PrestoCVIntegration ┴─▶ CVRendering ─┬─▶ CVDocumentModel             │
     │                                    │                └─▶ CVDesignCatalog              │
     │                                    ├─▶ CVDrafting                                     │
     │                                    └─▶ PrestoCVImporting ─────────────────────────────┘
     └────▶ PrestoCVComposition ─▶ (all of the above) + PrestoCVPersistence, PrestoCVImportingPDFKit, CVDesignCatalogFileStore, CVBundledDesigns, CVBundledHeadings,
                                CVRenderingWebKitSupport, CVRenderingIOS | CVRenderingMacOS,
                                CVRenderingPDFKitInspector, CVDraftingFoundationModels
PrestoCVImportingPDFKit ─▶ PrestoCVImporting
PrestoCVImporting, PrestoCVImportingPDFKit, CVGeneratorAI (legacy), PrestoCV (app) ─▶ DiagnosticLogging
PrestoCV (app) ─▶ DiagnosticLoggingOSLog ─▶ DiagnosticLogging
PrestoCVImporting, CVGeneratorAI (legacy), PrestoCV (app) ─▶ DiagnosticTrace ─▶ DiagnosticLogging
PrestoCV (app) ─▶ DiagnosticTraceFiles, DiagnosticTraceDistribution ─▶ DiagnosticTrace

Forbidden: any edge between PrestoCVCore, CVPDFExporter and CVGeneratorAI, except to DiagnosticLogging (ADR 0030) and DiagnosticTrace (ADR 0032).
Forbidden: any edge from a domain, application or port target to an adapter target.
Forbidden: PrestoCVPresentation → PrestoCVIntegration.
```
