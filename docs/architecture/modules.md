# Packages and targets

This is the authoritative list of production modules and of what each may import. The checker's `rules.json` must agree with it in both directions ([ADR 0006](adr/0006-enforce-architecture-mechanically.md)):

- every target listed here has a rule, or is declared `notYetImplemented`;
- no rule allows an import this file does not allow. Rules may be stricter, never looser;
- every dependency declared in a `Package.swift` must be an allowed import.

A new target, or a new edge between targets, changes this file in the same pull request.

Notation:
- **May import** lists every module the target may `import`. Swift and Foundation are always allowed; in domain targets only as value types (R2).
- The platform column reads iOS / macOS / Linux. **Linux ✓** means the target must build and pass its tests on Linux in CI.

Test targets and test-support targets are described below each package. The checker applies only its import allow-lists to them.

---

## Package `PrestoCVCore` — CV Authoring

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `PrestoCVDomain` | domain | iOS, macOS, Linux ✓ | Foundation |
| `PrestoCVApplication` | application | iOS, macOS, Linux ✓ | `PrestoCVDomain`, Foundation |
| `PrestoCVPersistence` | outbound adapter | iOS, macOS, Linux ✓ | `PrestoCVApplication`, `PrestoCVDomain`, Foundation, Glibc, Darwin |

**`PrestoCVDomain`**
- **`CV`**, the aggregate:
  - a typed identity (`CVID`);
  - `revision`, `createdAt` and `updatedAt`, settable only inside the package;
  - a private title, `PersonalDetails`, and ordered sections of entries;
  - the "has enough content to be saved" rule;
  - duplication with a title composed by the caller.
- **Value objects:**
  - `PartialDate` (year or month precision, partial order);
  - `Period`, whose end is a date, "current" or "ended, date unknown" (`PeriodEnd.unknown`);
  - `SkillLevel` (1–5);
  - `LanguageProficiency` (CEFR + native);
  - `EmailAddress`, `PhoneNumber`, `WebLink`, `DocumentLanguage`, `DesignChoice`.
- **`Period.make(start:end:current:)`** is the single rule that turns loose data into a period, or into a typed `PeriodError`.
- Planned: projects (#54), photo (#53).

**`PrestoCVApplication`**
- **Ports:**
  - `CVRepository`: create, conditional update, load, list, conditional delete. Typed `RepositoryError`, not cancellable.
  - `CVStoreMaintenance`: restore from quarantine, erase every copy, purge quarantine.
  - `SampleCVSource`, `IDGenerator`, `TimeSource`. `TimeSource` is so named to avoid shadowing `Swift.Clock`.
- **Use cases:**
  - `NewCV`, `SaveCV` (create or conditional update, errors translated to `AuthoringError`, including `tooLarge`), `LoadCV`;
  - list (by last change), rename, duplicate, delete, start from a sample, determine onboarding.
- **Listing** returns the healthy CVs plus `StoreIssue`s: `corrupt`, `upgradeRequired`, `unreadable`, `tooLarge`, `quarantineFailed`.

**`PrestoCVPersistence`**
- `FileCVRepository`:
  - one `CVFileV1` file per CV, named from its id;
  - atomic writes with `complete` protection, and a read-back check before every write;
  - every mutation under an exclusive `flock` on the store;
  - reads classified as described in R12;
  - `Quarantine/` with validated restore, erase and purge.
- `DirectorySampleCVSource`: sample CVs from an injected directory, in the same v1 format and through the store's own reader. The app ships them in `PrestoCV/Resources/Samples/`.

**Test support and tests.**
- `PrestoCVCoreTestSupport` may import `PrestoCVApplication`, `PrestoCVDomain`, Foundation, Synchronization. It holds:
  - `InMemoryCVRepository`, `SteppingClock`, `SequentialIDGenerator`;
  - the **`CVRepository` contract suite**: round trip with timestamps, create twice, update bumps the revision, stale update and stale delete, 50 concurrent updates from one revision leave exactly one success, update after delete, listing order.
- File-store behaviour that an in-memory store cannot have is tested in the Core tests, not in the contract: mixed directory, unreadable, oversized and hostile files, restore, erase, purge, and two instances racing.

---

## Package `CVPDFExporter` — Design Catalog and Document Rendering

Standalone and portable. It has no dependency on any PrestoCV package ([ADR 0002](adr/0002-cvpdfexporter-standalone-and-portable.md)). Legacy targets are declared only on Apple hosts during the migration ([ADR 0012](adr/0012-legacy-targets-during-migration.md)).

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `CVDocumentModel` | published language | iOS, macOS, Linux ✓ | Foundation |
| `CVDesignCatalog` | domain + application | iOS, macOS, Linux ✓ | Foundation |
| `CVDesignCatalogFileStore` | outbound adapter | iOS, macOS, Linux ✓ | `CVDesignCatalog`, Foundation, Glibc, Darwin |
| `CVBundledDesigns` | outbound adapter + resources | iOS, macOS, Linux ✓ | `CVDesignCatalog`, Foundation |
| `CVRendering` | application | iOS, macOS, Linux ✓ | `CVDocumentModel`, `CVDesignCatalog`, Foundation |
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
- **`MarkupContract`**, version 1: elements, classes, section kinds, ratings, pseudo-classes. See [markup-contract.md](markup-contract.md).
- **The CSS policy:** a tokenizer, an allow-list of properties and values, and canonical re-serialisation into `ValidatedStylesheet`, whose initialiser is internal.
- **`DesignPackageValidator`** takes raw bytes and returns a `ValidatedDesign`: manifest, stylesheet and PNG preview.
- **Customisation values:** `HexColor`, `Palette` (exists only with readable contrast) and `FontScheme` (a closed set).
- **Use cases:**
  - list, get, sync bundled designs (upgrade when newer);
  - **`InstallDesign`**: validate the raw bytes, then `DesignRenderingGate.verify`, then `DesignStore.save`. Nothing is stored unless both checks pass.
- **Ports:** `DesignStore`, `BundledDesignSource` (raw bytes), and **`DesignRenderingGate`**. The catalog owns the gate; `CVRendering` implements it, along the allowed Rendering → Catalog edge.

**`CVDesignCatalogFileStore`** holds `FileDesignStore`: the directory is injected, the index is written atomically under a lock (`flock`), and one instance serves the process. Every read validates the file again, so only validated designs leave the store.

**`CVBundledDesigns`** holds the bundled `.mcvt` files as resources, served as raw bytes through `Bundle.module`.

**`CVRendering`**
- **`DocumentHTMLBuilder`:**
  - produces the markup contract, with closed `Tag` and `Attr` enums and per-scalar escaping;
  - validates the language tag;
  - keeps only `WebLink`s, and prints each link's destination as its text;
  - formats dates in the document language.
- **`HeadingsCatalog`:** JSON heading tables per language plus an index, matched by BCP 47. An unsupported language is a typed error.
- **`PDFRendering`**, the outbound port: `render(html:page:) async throws -> RenderedPDF`, with `data`, `pageCount` and `requiredPages`. `truncated` is derived from those.
- **`PDFInspecting`**, the outbound port that reads the page count and text of a PDF.
- **`RenderedDocument`:** the builder's output, meaning the HTML plus the exact text nodes it contains.
- **`DocumentCompleteness`:** every text node needs its own span of the PDF text, which no other node uses, ignoring case and spacing.
- **`FixtureRenderingGate`:** implements the catalog's `DesignRenderingGate`. It renders a fixture that uses every section with the candidate design, and requires a complete, untruncated PDF.
- **Policy:** the required fields and page limit, shared by preview and export.

**`CVRenderingWebKitSupport`**
- `SecureWebViewConfiguration.compileRules()` is called once by the composition root: a block rule per network scheme, plus a block on every subresource type. `make(rules:)` then builds each configuration: JavaScript off for content, non-persistent store, media only on user action.
- `SingleLoadNavigationDelegate` loads the HTML string with no base URL, reports when that load has finished, and cancels every later navigation.
- `DocumentReadiness` waits until the document is complete and its fonts are ready. Its script runs in a content world of its own, with a timeout.
- Content blockers do not see `data:` URLs on Apple platforms: a test records this. None can enter the document, because the builder emits only http(s) links and the CSS policy has no `url()` (R8).
- A clicked link, which only happens in the preview, may open a connection to its host before the navigation is cancelled (a WebKit preconnect). Nothing is sent over it. A document's links and a refresh make no connection at all; tests record both.
- Every file is wrapped in `#if canImport(WebKit)`.
- **`CVRenderingWebKitSupportTests`** check each of these on iOS and macOS. Each network test has a control without the rules, which shows that the test can see a request.
- On iOS the exporter's tests run through the shared `ExporterTests` scheme, which holds the new test targets only: the package scheme also builds the legacy targets, which do not build for iOS.

**`CVRenderingIOS`, `CVRenderingMacOS`**
- One `PDFRendering` implementation per platform ([ADR 0003](adr/0003-one-pdf-renderer-per-platform.md)). Every file is wrapped in its platform condition.

**`CVRenderingPDFKitInspector`**
- `PDFInspecting` on PDFKit, used by the export workflow and by the native contract tests. Every file is wrapped in `#if canImport(PDFKit)`.

**Test support and tests.**
- **`CVRenderingTestSupport`** may import `CVRendering`, `CVDocumentModel`, `CVDesignCatalog`, Foundation. It holds `InMemoryDesignStore`, the **`DesignStore` contract suite** that it and `FileDesignStore` pass, and:
  - the **`PDFRendering` contract suite**:
    - the fixture must fit and contain every field;
    - page count per the inspector;
    - truncation reported;
    - `requiredPages` checked against an unlimited render;
    - deterministic pre-start cancellation;
  - `FakePDFRenderer`, which writes real uncompressed PDFs;
  - `MinimalPDFInspector`.
- **`CVRenderingIOSTests` and `CVRenderingMacOSTests`** run the contract suite against the real renderers with the PDFKit inspector: `xcodebuild test` on the iOS simulator, `swift test` on macOS. They also run the long-document pagination test, in-flight cancellation and the content-completeness test for every bundled design.

**Separate package `CVPDFExporterExamples`** holds the demos and the template viewer. The library package contains no executables (R14).

---

## Package `CVGeneratorAI` — AI Drafting

The context grows into import ([ADR 0020](adr/0020-import.md)). Its sources are a description, a PDF, a photo or a scan, and LinkedIn's data archive. Every one produces a `CVDraft`, which the user reviews (#18) before it becomes a CV.

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `CVDrafting` | domain + application | iOS, macOS, Linux ✓ | Foundation |
| `CVDraftingFoundationModels` | outbound adapter | iOS 26, macOS 26 | `CVDrafting`, FoundationModels, Foundation |
| `CVImportVision` | outbound adapter | iOS 26, macOS 26 | `CVDrafting`, PDFKit, Vision, Foundation |
| `CVImportArchive` | outbound adapter | iOS, macOS, Linux ✓ | `CVDrafting`, Foundation |

`CVImportVision` and `CVImportArchive` are planned (#194, #193). Until they exist, they are declared not yet implemented in the checker's `rules.json`.

**`CVDrafting`**
- **`CVDraft`:** plain `Sendable` structs; optional wherever the user may not have said it. A job has an optional start, an optional end and whether it is current. Dates have year or month precision, so LinkedIn's "Jan 2020" keeps its month. A draft from an import is bounded by what a CV holds, not by a description's bounds: the bounds are copies of Authoring's caps, because this package cannot import Authoring, and a test in `PrestoCVIntegration` holds them equal. A value over a bound is a typed error that names the field, never a silent truncation (#193, #195).
- **Use cases:**
  - `DraftCV` validates the input, generates, then validates the output. Streaming follows the same path. A description is drafted on the device only, as today.
  - `DraftFromDocument` (planned, #195): validates an `ExtractedDocument`, structures it through a port, checks the draft through a second port, and sends the failures back to the structurer at most twice. Then it returns the draft, or fails with every failure listed. It validates the draft on every path, and it is the one loop, for the device and for the server ([ADR 0020](adr/0020-import.md)).
  - `DraftFromLinkedInArchive` (planned, #193): reads the six files through `ArchiveReading` and maps their CSV to a draft, with no model. The CSV is parsed strictly, with a bound on its rows and on the length of a field (R8). The six files carry no contact details, so an archive's draft has none.
- **`ExtractedDocument`** (planned, #194): what extraction reads from a PDF or an image, with its structure. It is a list of blocks in reading order, each a title, a paragraph, a list of items or a table of rows, and holds text only. It is untrusted input (R8), validated when it is made: bounded in blocks and in characters, and refusing control characters. No text of a block holds a line break, whether it is a title, a paragraph, a list item or a table cell: the adapter ends a block at each one, and the document refuses a text that holds one. The line breaks are U+000A, U+000D (alone or before U+000A), U+0085, U+2028 and U+2029. The mapping into `TailoringModel` does not split blocks. It cleans each block with `TextRules.removingHidden` before anything is read. Its format is documented beside it, and the server's request holds the same bounds.
- **Ports:**
  - `DraftGenerating` (untyped `throws`, cancellable) and `DraftAvailability`, which also reports the model's room and measures a text against it, as numbers (R3);
  - `DocumentExtracting` (planned, #194): the bytes of a PDF or of an image in, an `ExtractedDocument` out. Untyped `throws`, cancellable;
  - `DocumentStructuring` (planned, #195): an `ExtractedDocument` and the failures of the last attempt in, a `CVDraft` out. Untyped `throws`, cancellable. The on-device model implements it, and so does the server's adapter, `ServerInference`;
  - `DraftChecking` (planned, #195): a draft and its document in, the failures out. The integration layers implement it, in the app and on the server, because the checks live in `CVTailoring`, which this package cannot import (R1);
  - `ArchiveReading` (planned, #193): an archive's bytes in, the bytes of the files that the mapping reads out.
- **`DraftingError`:** one case per model failure, and one per way an import can fail. The check's failures are values with codes, like the provenance gate's (R7). The app words them (R13), and each structurer words them for its model.

**`CVDraftingFoundationModels`**
- Internal `@Generable` schema, a session with instructions, availability from `SystemLanguageModel`.
- It also implements `DocumentStructuring` with guided generation, and reports the model's room to the availability port (#195).
- Until it is implemented it throws a typed "unavailable" error; it never returns an empty draft.

**`CVImportVision`** (planned, #194, [ADR 0020](adr/0020-import.md))
- The outbound adapter that implements `DocumentExtracting`, on the device. #194 chooses, per PDF, between the text layer, read with PDFKit, and Vision. A PDF with no text layer is a scan and goes through Vision, and so does every image. Vision's `RecognizeDocumentsRequest` returns the text with its structure: titles, paragraphs, lists and tables.
- It is a target of its own, not part of `CVDraftingFoundationModels`. R3 puts an adapter in a target of its own, and this one imports different frameworks (PDFKit and Vision, where the other imports FoundationModels) and implements a different port. It must also work on a device that has no model, because the server fallback needs the text. It imports no PrestoCV package other than `CVDrafting`, and it opens no connection.
- The package's manifest declares it only on Apple hosts, as it declares `CVDraftingFoundationModels`, so the Linux job builds `CVGeneratorAI` without it and the macOS job builds it. Every file is wrapped entirely in its platform condition (R11), which review holds, as for the other Apple-only adapters. The bytes it reads are untrusted (R8): a size cap comes first, an image's pixel dimensions are read from its header and bounded before the image is decoded, and then come a bound on pages and on the text it yields.
- #194 adds `Vision` and `VisionKit` to the checker's list of known frameworks, with a self-test, when it creates this target's entry in `rules.json`.
- It presents nothing. VisionKit's document camera on iOS, Continuity Camera on macOS and the pickers are views of the app target's `Platform/` folder, which hand it bytes.

**`CVImportArchive`** (planned, #193, [ADR 0020](adr/0020-import.md))
- The outbound adapter that implements `ArchiveReading`, for LinkedIn's data archive. It reads the ZIP in memory under three limits (R8): its size, its uncompressed size and its number of entries. It counts the bytes it actually inflates and stops at the limit, whatever the archive's headers declare. It writes nothing to disk, so a path inside the archive is never followed.
- It returns the bytes of `Profile.csv`, `Positions.csv`, `Education.csv`, `Skills.csv`, `Languages.csv` and `Certifications.csv` and of no other file, matched by exact name. It inflates nothing else. A missing file is not an error.
- Linux ✓ is the requirement, so that the hostile-archive tests run in the Linux job. #193 chooses the ZIP reader and proves that it builds and tests on Linux, and then adds the reader's module to the allow-list above. If none does, #193 makes the target Apple-only, with every file wrapped in its platform condition (R11), and says so here.

**Test support.** `CVDraftingTestSupport` holds a fake generator and fixtures, and gains a scripted structurer, a fake extractor and invented documents and archives (#193 to #195). The corpus of drafts, texts and verdicts that holds the check's two mappings equal is committed once, under `CVGeneratorAI/Corpus/`, outside every target. The tests of `PrestoCVIntegration` and of `ServerApplication` read it by its path.

---

## Package `CVTailoring` — CV Tailoring

Standalone, like `CVPDFExporter`. It depends on no PrestoCV package ([ADR 0013](adr/0013-cv-tailoring-context.md)): the app and the server each map their own types into its model. The targets are empty until the tickets named below fill them.

In the app, `PrestoCVIntegration` may import `TailoringModel`, `AdvertAnalysis`, `ContentChecks` and `Provenance` only: the loop runs on the server. `Provenance` is there for the check of an imported draft, whose one entry point it publishes ([ADR 0020](adr/0020-import.md)). No type shares its module's name, so a qualified name always means the module (the loop is not a type called `Tailoring`, nor the gate one called `Provenance`).

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `TailoringModel` | domain | iOS, macOS, Linux ✓ | Foundation |
| `AdvertAnalysis` | domain | iOS, macOS, Linux ✓ | `TailoringModel`, Foundation |
| `ContentChecks` | domain | iOS, macOS, Linux ✓ | `TailoringModel`, Foundation |
| `Provenance` | domain | iOS, macOS, Linux ✓ | `TailoringModel`, `AdvertAnalysis`, `ContentChecks`, Foundation |
| `Tailoring` | application | iOS, macOS, Linux ✓ | `TailoringModel`, `AdvertAnalysis`, `ContentChecks`, `Provenance`, Foundation |

**`TailoringModel`** (#135, #136)
- The snapshot types: the source CV, its statements and typed references to them, the advert, the letter defaults, the questions and answers, the tailored CV, the cover letter and the report.
- The word lists, one JSON file per language plus an index, read through `Bundle.module`; the supported languages are those with a file (#136).

**`AdvertAnalysis`** (#138, #153)
- What an advert asks for, and where the source CV evidences it.
- Language detection. It also finds the language of an imported text, in the app and on the server, so that both sides find it the same way. It refuses a text that does not read as a language with a file: the share of the detected language's stopwords must reach a threshold that #195 sets and tests on the shared corpus, with texts in German, Spanish, French, Italian and Portuguese refused while English is the only file ([ADR 0020](adr/0020-import.md)). #138 notes that an advert in another language reads as English today, and #152's mismatch decision can use the same refusal.
- The questions asked before a tailoring: required terms the CV does not evidence, and the letter fields the advert asks for that the defaults do not give (#153).

**`ContentChecks`** (#139)
- Spans that stay true, and figures as the CV writes them.
- `Provenance`'s entry point for an imported draft calls them for the spans ([ADR 0020](adr/0020-import.md)).

**`Provenance`** (#140, #141)
- The gate for the tailored CV and for the cover letter.
- **The import check** (planned, #195, on #140's readers; [ADR 0020](adr/0020-import.md)). One public entry point holds an imported draft to its text, in the app and on the server. Given the draft's texts and fields, mapped into `TailoringModel`'s values, the extracted text, a language and `asOf`, it returns typed failures. Behind it:
  - a figure of the draft must be one the text states, and a year alone is held as a figure, with the gate's reading of stated figures, in which a year is a figure. A date's month is held too: the text must write that month beside the same year, as a name or an abbreviation from `dates.months`, or as a numeral month in a numeric date (`06/2019`, `2019-06`, `6.2019`). A draft date with a month that the text does not write beside that year fails;
  - names are held with the gate's reader of names, and a structured field such as a company or a school is read whole;
  - spans are held with `ContentChecks`.
- Both integration layers only map into it, and map its failures back into their own. A language without a word-list file is a typed error there, German until #142. The known gap of #140 holds: a technology or a name written in lower case, or opening a sentence, passes.
- Its failures are values with codes. The app words them for the user (R13); `Tailoring`'s prompt words them for the model.

**`Tailoring`** (#150–#152)
- The loop: a failure goes back to the model at most twice, then the tailoring fails with every failure listed.
- The outbound inference port (#150), owned here (R3): the one way the loop reaches a model, the port whose providers [ADR 0015](adr/0015-inference-providers-and-data-policy.md) describes. Its adapters live on the server, in `ServerInference`.
- The prompt and its schema.
- Decoding the model's reply through one anti-corruption layer (R8).

**Test support.** None yet; `CVTailoringTestSupport` arrives with the first port (#150).

---

## Package `PrestoCVApp` — App integration and presentation

A local package next to the Xcode project. The compiler holds the app's layers too, and everything except the composition builds and tests on Linux.

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `PrestoCVWorkflowPorts` | app ports | iOS, macOS, Linux ✓ | `PrestoCVApplication`, `PrestoCVDomain`, Foundation |
| `PrestoCVIntegration` | app application layer | iOS, macOS, Linux ✓ | `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain`, `CVDocumentModel`, `CVDesignCatalog`, `CVRendering`, `CVDrafting`, `TailoringModel`, `AdvertAnalysis`, `ContentChecks`, `Provenance`, Foundation |
| `PrestoCVPresentation` | inbound adapter | iOS, macOS, Linux ✓ | `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain` (both `internal import`), Observation, Foundation |
| `PrestoCVAPIAdapter` | outbound adapter | iOS, macOS, Linux ✓ | `PrestoCVIntegration`, `TailoringModel`, `CVDrafting`, `PrestoCVAPITypes`, `PrestoCVAPIClient` (both `internal import`), `OpenAPIRuntime`, `HTTPTypes`, Foundation |
| `PrestoCVComposition` | composition root | iOS, macOS | `PrestoCVIntegration`, `PrestoCVPresentation`, `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain`, `PrestoCVAPIAdapter`, `PrestoCVPersistence`, `CVDocumentModel`, `CVDesignCatalog`, `CVDesignCatalogFileStore`, `CVBundledDesigns`, `CVRendering`, `CVRenderingWebKitSupport`, `CVRenderingIOS` (iOS only), `CVRenderingMacOS` (macOS only), `CVRenderingPDFKitInspector`, `CVDrafting`, `CVDraftingFoundationModels`, `CVImportVision`, `CVImportArchive`, `TailoringModel`, `AdvertAnalysis`, `ContentChecks`, `OpenAPIURLSession`, Foundation |

**`PrestoCVWorkflowPorts`**
- The ports that view models consume: `CVEditing` (new, save, load) and `CVExporting` (untyped `throws`, so cancellation passes through).
- App value types: `ExportOutcome`, `ExportFailure`.

**`PrestoCVIntegration`**
- **Workflows**, implementing the ports:
  - `EditCVWorkflow`;
  - `ExportCVWorkflow`: from the editor snapshot, with the document language, through the renderer, then the completeness check on the actual PDF;
  - `BrowseDesigns`;
  - `DraftCVWithAI`: availability, then draft, then an unsaved CV plus its gaps. It grows into the import workflow (planned, #195, [ADR 0020](adr/0020-import.md)): from a description, a document or an archive, it extracts, picks the device or the server, drafts and checks. For a document, it also returns the extracted text beside the draft and, for each field, the blocks of the text behind it, or none. The workflow finds them, and the view model only presents them (R5), so the review (#18) can mark the fields that have none and show the blocks behind a field. The text lives for the review and is not saved.
- **Mappers:** `CV → CVDocument` and `CVDraft → CV`. They are exhaustive and deterministic, with typed dates. The draft mapper uses `Period.make` and reports every gap.
  - `CV → SourceCV`, and the tailoring result into the app's own types (planned, #184, #188).
- **The check of an imported draft** (planned, #195, [ADR 0020](adr/0020-import.md)). `PrestoCVIntegration` implements `CVDrafting`'s `DraftChecking`. That is a translation between two contexts, so it lives here, and it touches no infrastructure.
  - It only maps. It maps the draft and the extracted text into `TailoringModel`'s values, finds the text's language with `AdvertAnalysis`, and calls the one entry point of `Provenance` with `asOf` from the injected `TimeSource` (R2). It maps the typed failures back into `CVDrafting`'s own. `Provenance` is the one edge it gains, and it is still not `Tailoring`, so the loop stays off the device.
  - A text in a language without a word-list file is a typed error, never an unchecked pass. German is one until #142.
  - Its failures are values with codes, and the app words them (R13).
- **The rule that picks the device or the server** (planned, #195). It is a pure function here, tested as a table and documented where it is made. It takes whether the on-device model is available, how much of its context the text takes, and a reserve for the draft. Availability and fit decide, and so does a structurer's error that means the text did not fit or the model is unavailable: it feeds the same rule. Only a failed check ends an import, and it does not move to the server. Before the server, the workflow needs the user's consent to the policy's current version, through a consent port owned here (#190), and without it nothing leaves the device. #195 declares the draft job's port and the consent port here and fakes both in its tests, so it waits for neither #190 nor #196.
- **Outbound ports that reach the server,** owned here (R3): the tailoring workflow's (start, read, cancel and confirm), the policy's (#190) and the push token's (#181), and the draft job's (start, read, cancel and confirm; cancel and confirm are the same `DELETE`). They speak the tailoring or drafting model and the workflow's typed errors, never a generated type. The draft job's port takes an `ExtractedDocument` and nothing else, so an image or a PDF cannot be sent. #195 declares it, and `PrestoCVAPIAdapter` implements them (planned, #179, #188, #196).
- **The attestation port,** owned here (R3), not by `PrestoCVAPIAdapter` that calls it, so that no edge joins two adapters: it signs the encoded body of a start and proves the installation (#174). `PrestoCVAPIAdapter` calls it. The App Attest adapter of #174, a target that the ADR of #168 adds to this file, implements it and never calls the API.

**`PrestoCVPresentation`**
- `@Observable @MainActor` view models whose public API holds presentation types only: status enums, and no domain types.
- **Saves** are serialised and coalesced, and every caller waits for its own edits to land.
- **Save and export** each have their own status, reset when a new intent starts.
- **Conflict** offers reload or save as a copy; **deleted elsewhere** offers save as a copy.
- **View-model initialisers do no I/O.** Loading happens in the view's `.task`, so the factory can be called on every view init.

**`PrestoCVAPIAdapter`** (planned, #179, [ADR 0016](adr/0016-api-contract.md))
- The outbound adapter that implements the ports that reach the server. It is the app's only client of the API, for every endpoint the app calls: the tailorings, the policy, the push token, and the challenges, registration and sessions. It is the only target of the app that imports the API's generated client and types, and it imports both with `internal import`, so no generated type appears in its public API.
- It maps the tailoring model to the request, and the result back, exhaustively and under test ([ADR 0007](adr/0007-each-package-owns-its-model.md)). It does the same for the draft job, in the drafting model: start, read, and a `DELETE` that cancels or confirms (planned, #196, [ADR 0020](adr/0020-import.md)). It maps each documented problem `type` to a typed error of the workflow (R7): "update the app", "try again at this time", "no provider meets the policy", and "consent again" for a policy version that is not the current one (#190). A `type` it does not know, or a response the spec does not document for that operation, becomes a generic typed error, and an enum value it does not know becomes a typed "unknown" case.
- It opens and renews the session, and signs the encoded body of a start through the attestation port, which `PrestoCVIntegration` owns and the App Attest adapter of #174 implements. The attestation adapter never calls the API.
- It offers one read of a job per call, and it sends the `DELETE` that confirms a saved result when the workflow asks (#166). The workflow drives the polling, which ends when the job is final, and its caller cancels it when the app leaves the foreground (R3: cancellation passes through). The backoff goes through an injected clock or sleeper (R2, R10).
- The composition root creates it, and the URLSession transport it runs on (R4). It carries R4's detectors, and the checker's `infrastructureTypes` lists `URLSessionTransport` once it exists. Until `URLSessionTransport` is listed in `infrastructureTypes`, review holds it.
- It imports the runtime's modules, `OpenAPIRuntime` and `HTTPTypes`, which the middleware that signs a start and sends the session needs. How the transport reaches its initialiser is #179's. If that needs more, #179 extends this table, without a new ADR.

**`PrestoCVComposition`**
- The app's composition root, and the only place in the app that creates infrastructure (R4). The `@main` App type holds it in a `static let`. It owns:
  - file locations under Application Support;
  - one `FileCVRepository` and one `FileDesignStore`;
  - the web-view rule list, compiled once;
  - the platform renderer and the PDFKit inspector;
  - the AI adapter, `TimeSource`, `IDGenerator` and logger;
  - the extraction adapter and the archive reader (planned, #193, #194);
  - the API adapter, with the URLSession transport it runs on (planned, #179);
  - the `ScreenFactory`.
- **UI tests and previews** use the production `FileCVRepository` on a temporary directory seeded from fixture JSON. A launch argument selects it. No production target depends on a test-support target.

**Test support.** `PrestoCVAppTestSupport` holds fakes for the workflow ports.

---

## Package `PrestoCVServer` — the server

A package of its own, next to the app's, in this repository ([ADR 0014](adr/0014-server-modular-monolith.md)). It is an integration and composition package, like `PrestoCVApp`, and not one of the isolated context packages (R1). It builds and tests on Linux, and runs on macOS for development.

The targets are created by #158 and the tickets named below. Until the targets exist, they are declared not yet implemented in the checker's `rules.json`. The edges to `CVDrafting`, `AdvertAnalysis`, `ContentChecks` and `Provenance` that the draft job needs (#196, [ADR 0020](adr/0020-import.md)) are planned with the targets that hold them.

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `ServerApplication` | application | Linux ✓, macOS | `TailoringModel`, `Tailoring`, `CVDrafting`, `AdvertAnalysis`, `ContentChecks`, `Provenance`, Foundation |
| `ServerInference` | outbound adapter | Linux ✓, macOS | `ServerApplication`, `Tailoring`, `TailoringModel`, `CVDrafting`, `AsyncHTTPClient`, Foundation |
| `ServerStorePostgres` | outbound adapter | Linux ✓, macOS | `ServerApplication`, `TailoringModel`, `CVDrafting`, `PostgresNIO`, Foundation |
| `ServerQueueCloudTasks` | outbound adapter | Linux ✓, macOS | `ServerApplication`, `AsyncHTTPClient`, Foundation |
| `ServerLocalProfile` | outbound adapter | Linux ✓, macOS | `ServerApplication`, Foundation |
| `ServerHTTP` | inbound adapter | Linux ✓, macOS | `ServerApplication`, `TailoringModel`, `CVDrafting`, `PrestoCVAPITypes`, `PrestoCVAPIServer` (both `internal import`), `Hummingbird`, `OpenAPIRuntime`, `OpenAPIHummingbird`, Foundation |
| `PrestoCVServer` | executable and composition root | Linux ✓, macOS | `ServerApplication`, `ServerInference`, `ServerStorePostgres`, `ServerQueueCloudTasks`, `ServerLocalProfile`, `ServerHTTP`, `Tailoring`, `CVDrafting`, `Hummingbird`, `AsyncHTTPClient`, `PostgresNIO`, `ArgumentParser`, `Logging`, `ServiceLifecycle`, Foundation |

**`ServerApplication`** (#157, #155, #165, #166)
- **Use cases:** start a tailoring, run it, get it, erase (#166), and read the data policy (#155), which `GET /v1/policy` calls.
  - Start checks the caller's cost limits, records the job under its idempotency key and queues it. A known key returns its job before any limit is checked, and counts nothing more. It refuses a request that carries another policy version than the current one.
  - Run is the `work` role's use case: it loads the job, runs the loop of `Tailoring`, stores the result or the failure, and notifies the device (#180).
  - Get returns the job to its owner only.
  - Erase ([ADR 0017](adr/0017-hosting-storage-and-cost.md)) is the one rule that deletes data, with two entries. The app's `DELETE` runs it for one job, the owner's only. The schedule's call to the worker runs it for what is due:
    - first, it expires every job that has not ended within its queue's retry window, so that every job ends;
    - then every job that ended at least 24 hours minus the schedule's interval ago, so that no job outlives its 24 hours, whether it succeeded, failed or expired;
    - a device unused for 90 days;
    - the expired challenges (#170) and counts of hashed addresses (#172).
  - A `DELETE` during a run erases the job, and the worker's later write finds no row and does not bring it back. A worker neither runs nor writes a job that has ended. Erase does no harm run twice.
- **The job lifecycle:** queued, running, succeeded, failed, expired. A job is erased once the app confirms it has saved the result, and 24 hours after the job ends at the latest (#166). A job that never ends is expired by the schedule's run.
- **Retention and the cost limits** ([ADR 0017](adr/0017-hosting-storage-and-cost.md)):
  - Erasure reads the time from the injected clock (R2).
  - **The cost limits** are checked here, before a job is recorded (#165). The quota store counts tailorings per device and for everyone, per day. The tailoring is counted in the same transaction that records the job, so two starts that race for the last tailoring of a day record one job. Over a limit, the API answers 429 with when to retry.
  - The limits, the retention periods, the schedule's interval and the queue's retry window are values the executable reads from configuration and hands in. The hosted defaults are the owner's: 5 tailorings a device a day, 100 for everyone, 24 hours for a job and 90 days for an idle device.
  - The other two limits live outside the code: the hosted router's credit limit and the Google budget alert (#163, #165).
- **The `draft` job kind** (planned, #196, [ADR 0020](adr/0020-import.md)). It runs an import's structuring when the device cannot.
  - It has a tailoring's lifecycle, queue and erasure. A task carries the job's ID and nothing else, and the job's text and result go with it. It starts under an idempotency key, only its owner reads it, and the worker's route runs either kind.
  - It has its own quota: its own counts and limits, per device and for everyone, in configuration. The credit limit of the hosted router's key bounds both kinds of work. The hosted defaults are the owner's, set by #165 and #196.
  - A start carries the policy version that the app showed the user. Start refuses another one, the job records it, and the worker refuses to run it under another.
  - No log event carries the extracted text, the draft or the reply (#167).
  - The run is `CVDrafting`'s `DraftFromDocument`, with a structurer behind `CVDrafting`'s `DocumentStructuring` (`ServerInference` implements it) and a checker behind `DraftChecking`.
  - **The checker.** `ServerApplication` implements `DraftChecking` for the server, as `PrestoCVIntegration` does in the app, and only maps. It maps a draft and its text into `TailoringModel`'s values, finds the language with `AdvertAnalysis`, as the app does, and calls the one entry point of `Provenance` with `asOf` from the injected clock. It maps the typed failures back into `CVDrafting`'s own. They reuse the gate's failure type, which names `ContentChecks` types, so this target imports `ContentChecks` as well. **This file designates `ServerApplication` for that translation between two context packages** (R1). The two mappings are separate code, and one corpus of drafts, texts and verdicts, committed once under `CVGeneratorAI/Corpus/`, outside every target, and read by the tests of `PrestoCVIntegration` and of `ServerApplication` by its path, holds them equal.
  - The app does not check again a draft that the server returns. That is [ADR 0020](adr/0020-import.md)'s choice: a field app can hold older word lists than the server, and it cannot send failures back to a model.
- **The lease.** A running job holds a lease, and a job whose lease has expired is taken over by the retry (#161). The lease belongs to the job's lifecycle and to its contract suite, not to the queue adapter.
- **Ports it owns (R3):** the job store, the job queue, the quota, the device registry (#170), unless #168 gives its port to another target, and the ports that erasing an idle device (#166), sweeping expired challenges (#170) and sweeping address counts (#172) go through, the clock, an identifier generator (R2), a notifier (#180), the log events, and the data-policy port that `GET /v1/policy` reads (#155, #175).
- **The data policy** ([ADR 0015](adr/0015-inference-providers-and-data-policy.md)), beside that port:
  - the types: what a provider declares (whether it keeps prompts, whether it trains on them, the regions it may run in), what a deployment requires, and the policy that `GET /v1/policy` serves: the requirements and the processors, which are the registry's providers named as the published privacy policy names them (#190);
  - the policy's version, derived from everything that endpoint serves, so a provider swap that still meets the requirements changes it. The start request carries the version the app showed the user, Start refuses a different one, the job records it, and the worker refuses to run it under another (#155, #176, #190);
  - the one rule, "a provider meets a policy": it keeps prompts and trains on them only where the policy allows it, and runs only in regions the policy accepts. A provider stricter than the policy meets it. The rule is pure, reads no ambient state (R2) and is tested without I/O.
- **Log events** are typed and never carry a CV, a prompt or a key (#167). The executable bridges the port to swift-log. Adapters log through an injected `Logger` once #167 extends their allow-lists with `Logging`.
- **Typed errors** (R7). It imports no third-party package.

**`ServerInference`** (#154, #155, [ADR 0015](adr/0015-inference-providers-and-data-policy.md))
- The adapters behind the inference port that `Tailoring` owns (#150): the first one speaks the chat-completions API that most providers and local model servers share, with a dialect for each endpoint. A native adapter is written only for a provider with no compatible endpoint.
- **The registry,** built from configuration. It lists the providers in order of preference, each with its dialect, its endpoint, the name of the secret that holds its key (a provider that needs no key declares so), its allowed models with the capabilities of each (whether it supports structured output, its context size), its declaration, its name as the published privacy policy names it (#190), and an alias. The alias is the only name of a provider or model in a result, a log or a report (#156, #176).
- **Building the registry** applies the rule of `ServerApplication`. It fails with the refusal described under the executable when a provider does not meet the policy, so no running registry holds one and no fallback can reach one.
- **Selection and fallback:** the first available provider answers. When it is unavailable or rate-limited, the next one that meets the policy answers instead. No other error triggers a fallback, a refusal for lack of credit included (#165).
- It implements two ports for the tailoring side: the inference port of `Tailoring`, and the data-policy port of `ServerApplication`, so `GET /v1/policy` reaches the policy. The registry's declarations and the data-policy port need no client and no key. For drafts it implements a third, below.
- **The draft job's structurer** (planned, #196, [ADR 0020](adr/0020-import.md)). It also implements `CVDrafting`'s `DocumentStructuring`, over the registry's selection and fallback, so a draft goes through the same registry and policy as a tailoring. It holds the draft's versioned prompt and schema, and decodes the model's reply through one anti-corruption layer (R8). The model a draft uses is configuration, as a tailoring's is.
- **A router's dialect** derives its routing preferences from the deployment's policy (#154). A router's declaration covers the upstreams its routing preferences allow (#154): it keeps prompts, trains on them or runs in a region if it or any of those upstreams does.
- The adapter decodes the endpoint's envelope into the port's reply and errors, with a size cap. The model's text is decoded once: a tailoring's in `Tailoring`, a draft's in the structurer above (R8).
- It never logs a prompt, an answer or a key. It never reads a secret, the environment or a secret store: the executable hands it the keys and the clients.

**`ServerStorePostgres`** (#160, #170, [ADR 0017](adr/0017-hosting-storage-and-cost.md))
- The job store, the quota store and the adapter of the device registry (#170) on Postgres, through PostgresNIO. Hosted, the database is Neon's, in Frankfurt: one project, with one branch per environment.
  - Each branch has its own role and password. No branch is made from another environment's data, and none is reset from its parent.
- Its rows are DTOs of its own, built from the types of `TailoringModel` (R12). What authentication keeps beyond the registry, and whether its tables share this schema, is decided by its own ADR (#168).
- A draft job's rows hold its extracted text and its result, and are erased with it (#196). They are DTOs of the store's own as well, built from the types of `CVDrafting`, which is why it imports it (R12).
- The versioned SQL migrations (R12), in one history for the server's own tables. Only the binary's `migrate` command applies them, never `serve` or `work`.
- **Retention** (#166): it deletes the rows that `ServerApplication`'s erasure names, and marks nothing as deleted. Quota counts go with their device at the latest.

**`ServerQueueCloudTasks`** (#161, [ADR 0017](adr/0017-hosting-storage-and-cost.md))
- The job queue on Cloud Tasks, in `europe-west1` beside the Cloud Run services, over AsyncHTTPClient. A task is named after its job and calls the worker with the queue's own identity.
- A task carries the job's ID and nothing else. The CV and the advert are in the job store only.
- It gets its access token from a token provider that the executable creates and hands in.
- The dispatch deadline is 30 minutes, and retries use backoff.

**`ServerLocalProfile`** (#157, #158)
- The in-memory job store, quota store and device registry (#170), and the in-process queue, of the local profile.
- They are adapters of a profile the executable ships, not test doubles (R14). Each passes the contract suite of its port.

**`ServerHTTP`** (#175, #178)
- The inbound adapter: the Hummingbird routes, the middleware, and the handlers that implement the generated API.
- It maps the generated types to the use cases and back. The generated types never leave it: it imports `PrestoCVAPITypes` and `PrestoCVAPIServer` with `internal import`, so none can appear in its public API.
- It maps the draft job's endpoints the same way, to the use cases and to `CVDrafting`'s types, and validates a request into an `ExtractedDocument` (planned, #196, [ADR 0020](adr/0020-import.md)). A test proves that the spec's bounds equal the type's. `DELETE` cancels a draft or confirms its result, as a tailoring's does.
- It serves the API on Hummingbird through `OpenAPIHummingbird`. `GET /health` is an endpoint of the spec, and `ServerHTTP` serves it in both roles.
- **The worker's routes.** The route the queue calls to run a job, and the one the schedule calls to erase what is due (#166), live here too. They are mounted only in the `work` role, and they are not part of the public API (`openapi.yaml`). The platform admits only the queue's identity before any code runs (#161).
- `PrestoCVAPITypes` and `PrestoCVAPIServer` are targets of the `PrestoCVAPI` package, listed below ([ADR 0016](adr/0016-api-contract.md)).

**The `PrestoCVServer` executable target**
- The executable and the server's composition root (R4). It reads the command line with ArgumentParser and the configuration, picks the profile's adapters, wires them behind the ports of `ServerApplication` and of `Tailoring`, and creates the infrastructure: the database pool, the queue client, the inference providers' HTTP client (in the role that holds the keys), the clock, the identifier generators and the logger.
- It reads the deployment's configuration and refuses to start, with an error that names the cause, when a provider does not meet the data policy, when a model is not allowed, when a secret cannot be read, or when a provider's declaration is incomplete (#155, [ADR 0015](adr/0015-inference-providers-and-data-policy.md)). Nothing is skipped silently.
  - Both roles read one configuration, and each checks the policy and the models.
  - Each role reads the secrets it needs: both read the database's credentials, and `migrate` reads them too; the role that holds the keys also reads the providers' keys and the APNs key, and creates the providers' HTTP client, one per process. It hands the secrets to the adapters.
  - How it reads Secret Manager, mounted into the service or through the API, is #163's choice. The executable does the reading, never an adapter ([ADR 0017](adr/0017-hosting-storage-and-cost.md)).
- It reads the cost limits, the retention periods, the schedule's interval and the queue's retry window from configuration and hands them to the use cases as values ([ADR 0017](adr/0017-hosting-storage-and-cost.md)). It refuses an interval that is not well below the 24 hours (#166).
- It starts as `serve`, as `work`, or, in the local profile, as both. It composes the router per role.
- It shuts down cleanly on SIGTERM: the job in hand is finished or released back to the queue.

**Roles.**
- **`serve`** answers the API. Hosted, it is its own Cloud Run service. It records a job and hands it to the queue. It checks the data policy at start and serves it, and it reads no provider's key.
- **`work`** runs tailorings, and drafts once #196 exists. Hosted, it is its own Cloud Run service, and it is private: only the queue's identity, which the erasure schedule (#166) also uses, may call it, and the platform refuses everyone else before any code runs. Only the worker holds the model providers' keys and the APNs key (#180).
- A tailoring or a draft finishes within the queue's dispatch deadline of 30 minutes.
- The binary has one more command, `migrate` (#160, #162). It is not a role.

**Profiles.** A profile is a set of adapters that the composition root picks from configuration.
- **`hosted`:** the Postgres store, on Neon in Frankfurt, and the Cloud Tasks queue, in `europe-west1` ([ADR 0017](adr/0017-hosting-storage-and-cost.md)).
- **`local`:** the in-memory stores and the in-process queue of `ServerLocalProfile`, with both roles in one process. It is for development only, and it refuses to start on any address but 127.0.0.1.

**Environments.** `local` uses the local profile. `staging` and `production` use the hosted profile, each with its own configuration, database and queue. Staging accepts App Attest's development environment and production only the production one. A merge to `main` deploys to staging, and a tag promotes the same image to production ([ADR 0017](adr/0017-hosting-storage-and-cost.md); the pipeline is #164).

**Where it runs** ([ADR 0017](adr/0017-hosting-storage-and-cost.md)). Hosted, both roles run on Cloud Run in `europe-west1`, with Cloud Tasks and the Cloud Scheduler job that runs erasure (#166) in the same region, and Postgres on Neon in Frankfurt.
- The secrets are in Secret Manager, one set per environment, and each is readable only by the identities that need it: its service, and CI's identity for the Neon credentials it needs (#164).
- The infrastructure is OpenTofu code in `infra/` (#163). It also sets each Cloud Run service's maximum number of instances, the queue's maximum dispatch rate, a log exclusion that drops the public service's platform request logs, which carry the caller's address, and an alert on a failed run of the erasure schedule.
- CI deploys through Workload Identity Federation. No long-lived key and no credential for Neon is stored in GitHub (#164).

**Translation.** On the server, the API's generated types are translated to and from the tailoring and drafting models only in `ServerHTTP`, and never leave it. A translation between two context packages on the server lives in a server target that this file designates for that translation, or needs an ADR (R1). This file designates one: `ServerApplication`, for a draft and its text into the content checks ([ADR 0020](adr/0020-import.md)).

**Dependencies.**
- External packages are imported only by adapters and by the executable, never by `ServerApplication`. Each is pinned in the committed `Package.resolved`. A new one changes this file in the same pull request, and the checker's `--packages` rule holds it.
- The tickets that add logging and metrics (#167, #178) extend the adapters' allow-lists with `Logging` and `Metrics` in this file.
- The package depends on `CVTailoring`, on `CVGeneratorAI` once #196 exists, and on `PrestoCVAPI` once #177 exists. It never depends on `PrestoCVApp` or `PrestoCVCore`.
- It may depend on the Linux targets of `CVPDFExporter` and of `CVGeneratorAI` (`CVDrafting`), which are reusable on a backend ([ADR 0002](adr/0002-cvpdfexporter-standalone-and-portable.md)). The ticket that needs such an edge adds it to this file. #196's edges are listed above ([ADR 0020](adr/0020-import.md)), and #94's is still to come.
- The targets for authentication, logs and notifications are set by their tickets' decisions (#167, #168, #180) and added to this file then.

**Test support.** None yet. The contract suites of the ports (#157) live in a test-support target that #157 adds to this file, as R10 asks. `ServerApplication`'s own tests use the adapters of `ServerLocalProfile`, so there is no second copy of them.

---

## Package `PrestoCVAPI` — the API contract

A package of its own in this repository, which holds the API between the app and the server: the spec, and the code generated from it ([ADR 0016](adr/0016-api-contract.md)). It depends on no PrestoCV package, so the app and the server can both depend on it. It is not a context, and its targets hold generated code only.

The targets are created by #177, from the spec of #176. Until they exist, they are declared not yet implemented in the checker's `rules.json`.

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `PrestoCVAPITypes` | generated | iOS, macOS, Linux ✓ | `OpenAPIRuntime`, Foundation |
| `PrestoCVAPIServer` | generated | macOS, Linux ✓ | `PrestoCVAPITypes`, `OpenAPIRuntime`, `HTTPTypes`, Foundation |
| `PrestoCVAPIClient` | generated | iOS, macOS, Linux ✓ | `PrestoCVAPITypes`, `OpenAPIRuntime`, `HTTPTypes`, Foundation |

**The spec** (#176)
- `openapi.yaml`, in OpenAPI 3.1, is the single source of the API. It sits in the package and is excluded from every target: it is not a SwiftPM resource, so no binary carries it. Its endpoints are versioned in the path (`/v1`).
- Every endpoint, schema, field and error `type` has a description in it. The public reference is generated from them (#182, #183).
- The draft job's endpoints, `POST /v1/drafts`, `GET /v1/drafts/{id}` and `DELETE /v1/drafts/{id}`, are added by #196. They are additive to v1 ([ADR 0020](adr/0020-import.md)).
- Every operation declares a `default` problem+json response, so a client decodes any error as a problem.
- It describes the public API only. The route that the queue calls to run a job is not in it ([ADR 0014](adr/0014-server-modular-monolith.md)).

**`PrestoCVAPITypes`**
- The schemas, and the input and output of each operation.

**`PrestoCVAPIServer`**
- The protocol that the server implements, and its registration on a transport. `ServerHTTP` implements the protocol, and supplies the Hummingbird transport.

**`PrestoCVAPIClient`**
- The client, which calls each operation through the transport it is given. The app runs it on the URLSession transport that its composition root creates.

**Who may import them**
- On the server, only `ServerHTTP`, which imports `PrestoCVAPITypes` and `PrestoCVAPIServer` with `internal import`.
- In the app, only `PrestoCVAPIAdapter`, which imports `PrestoCVAPITypes` and `PrestoCVAPIClient` with `internal import`. The app's composition root alone imports `OpenAPIURLSession`.
- No other production target outside the package imports one. The generated types never leave those two adapters.

**Generated code, held by regeneration (#177)**
- A header marks each generated file, and nobody edits one by hand. The sources are committed, so a change to the spec shows its effect in the pull request, and Xcode needs no plugin.
- CI regenerates the code and fails when it differs from what is committed. It also compares the spec with the one on `main` and fails on a breaking change, which needs a new version in the path.
- Only R1's `exportedImport` detector runs on these targets, since generated code satisfies it. No other detector runs on them, R11's `platformCondition` included: the generator wraps its Foundation imports in `#if os(Linux)`, and nobody may edit generated code, so a finding there could never be fixed. The import allow-lists still apply.
- The checker gets a `generated` target kind for these targets (#177).

**Dependencies.** `OpenAPIRuntime` for the three targets, and `HTTPTypes` for the server and the client. `OpenAPIURLSession` is not a dependency of this package: the app's composition root imports it, to create the URLSession transport (#179). `OpenAPIHummingbird` is a dependency of `ServerHTTP`, not of this package. The runtime and the transports are pinned in the committed `Package.resolved` of what resolves them, the server's package and the app's project. The generator is a tool run by one documented command, not an import. It is pinned in a tool package of its own, not in this package's manifest, so that it and its dependencies never enter the dependency graph of the app and the server (#177).

**Test support.** None yet.

---

## Xcode app target `PrestoCV` (iOS 26, macOS 26)

A native SwiftUI multiplatform target ([ADR 0004](adr/0004-native-multiplatform-app.md)). The checker maps each folder as its own target.

| Folder | Contents | May import |
|---|---|---|
| `App/` | `@main` (holds the composition), scenes and macOS commands; `#if os` allowed here | SwiftUI, `PrestoCVComposition`, `PrestoCVPresentation` |
| `Features/` | SwiftUI views per screen; `NavigationSplitView` navigation; no `#if` | SwiftUI, `PrestoCVPresentation` |
| `DesignSystem/` | tokens and reusable components | SwiftUI |
| `Platform/` | the platform shims: iOS-only modifiers wrapped for `Features/`, HTML and PDF previews, sharing, pasteboard, file import and export, and the capture of a document to import (VisionKit's document camera on iOS, Continuity Camera and the pickers on macOS), which hands bytes to the view model ([ADR 0020](adr/0020-import.md)) | SwiftUI, UIKit, AppKit, WebKit, PDFKit, QuickLook, VisionKit, UniformTypeIdentifiers, `CVRenderingWebKitSupport`, `PrestoCVPresentation` |
| `Resources/` | `Localizable.xcstrings`, sample CV JSON, assets | — |

`VisionKit` is new to `Platform/`'s list: #194 adds `Vision` and `VisionKit` to the checker's list of known frameworks, with a self-test ([ADR 0020](adr/0020-import.md)).

---

## Dependency graph (summary)

```
PrestoCV (app) ─▶ PrestoCVPresentation ─▶ PrestoCVWorkflowPorts ─▶ PrestoCVApplication ─▶ PrestoCVDomain
     │                                     ▲
     │                     PrestoCVIntegration ┴─▶ CVRendering ─┬─▶ CVDocumentModel
     │                                    │                └─▶ CVDesignCatalog
     │                                    ├─▶ CVDrafting
     │                                    └─▶ TailoringModel, AdvertAnalysis, ContentChecks, Provenance
     └────▶ PrestoCVComposition ─▶ (all of the above) + PrestoCVAPIAdapter, PrestoCVPersistence, CVDesignCatalogFileStore,
                                CVBundledDesigns, CVRenderingWebKitSupport, CVRenderingIOS | CVRenderingMacOS,
                                CVRenderingPDFKitInspector, CVDraftingFoundationModels, CVImportVision, CVImportArchive

CVGeneratorAI package: CVDraftingFoundationModels, CVImportVision, CVImportArchive ─▶ CVDrafting

PrestoCVAPIAdapter ─┬─▶ PrestoCVIntegration, TailoringModel, CVDrafting
                └─▶ PrestoCVAPITypes, PrestoCVAPIClient

PrestoCVServer (executable) ─┬─▶ ServerHTTP ─┬─▶ ServerApplication ─▶ TailoringModel, Tailoring, CVDrafting, AdvertAnalysis, ContentChecks, Provenance
                         │               └─▶ TailoringModel, CVDrafting, PrestoCVAPITypes, PrestoCVAPIServer
                         ├─▶ ServerInference ─▶ ServerApplication, Tailoring, TailoringModel, CVDrafting
                         ├─▶ ServerStorePostgres ─▶ ServerApplication, TailoringModel, CVDrafting
                         ├─▶ ServerQueueCloudTasks, ServerLocalProfile ─▶ ServerApplication
                         └─▶ ServerApplication, Tailoring, CVDrafting

PrestoCVAPI package: PrestoCVAPIServer, PrestoCVAPIClient ─▶ PrestoCVAPITypes     (generated; imports no PrestoCV package)

Forbidden: any edge between PrestoCVCore, CVPDFExporter, CVGeneratorAI and CVTailoring.
Forbidden: any edge from a domain, application or port target to an adapter target.
Forbidden: PrestoCVPresentation → PrestoCVIntegration.
Forbidden: any edge from ServerApplication to a third-party package.
Forbidden: CVImportVision and CVImportArchive importing a PrestoCV package other than CVDrafting.
Forbidden: any app target importing Tailoring.
Forbidden: any edge from the server's package to PrestoCVApp or PrestoCVCore.
Forbidden: any import of a PrestoCVAPI target by a production target outside the package, except by ServerHTTP and PrestoCVAPIAdapter.
Forbidden: ServerHTTP importing PrestoCVAPIClient, and PrestoCVAPIAdapter importing PrestoCVAPIServer.
Forbidden: any edge from a PrestoCVAPI target to another package of this repository.
```
