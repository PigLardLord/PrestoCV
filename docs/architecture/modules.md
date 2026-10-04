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
- **Applications** ([ADR 0019](adr/0019-applications.md)): what a tailoring produces and the user keeps.
  - **`Application`**, the aggregate:
    - a typed identity (`ApplicationID`);
    - `revision`, `createdAt` (when the user kept it) and `updatedAt`, settable only inside the package;
    - its tailored `CV`, which is part of the aggregate: it keeps its own `CVID`, which is given when the application is created and never replaced, is never listed among the user's CVs, and has no revision or timestamps of its own, because the application's are its. `CV.canBeSaved` holds for it on create and on every change. An edit of it is conditional on the application's revision, and so is an edit of its letter, so the two conflict (#191);
    - its `CoverLetter`, and the `Advert`: the advert's company, role and text;
    - its `ApplicationProvenance`.
    The CV and the letter change through `setCV`, which refuses another identity and a CV that cannot be saved, and `setLetter`; the fields are read-only.
  - **`ApplicationProvenance`**: plain values that Authoring stores, bounds and gives back, and does not interpret, never Tailoring's types (R1). It holds:
    - the job's identifier (`JobID`), an opaque value, which the repository reads under its lock so that create is idempotent per job (#188);
    - the source CV's `CVID`, and the snapshot the tailoring used, as the statements of each experience;
    - the report: the one argument the CV makes, and what was cut, moved and reworded;
    - the questions, each as a code, its values, its scope (an experience, the skills, the summary or a letter field) and the user's answer, which a skipped question lacks. Tailoring's codes are worded at the edge (R13);
    - the override of the letter defaults the tailoring was made with, and the letter defaults as the snapshot held them, after the override;
    - the prompt version and the aliases of the attempt that passed, never the name of a provider or a model;
    - the statement and answer references of each tailored line, as positions into the stored snapshot's statements and into the questions.
    It describes the result as produced, not the CV after the user's edits. Positions that point into the snapshot or the answers must point inside them, and the defaults must say what the override set; the positions of a tailored line are only non-negative, because the user's edits move them.
  - **`CoverLetter`**: the letter the user keeps and edits. It holds a `LetterRecipient` (company, contact name, `FormOfAddress` `ms`, `mr` or `neutral`, title, surname, role and address lines), the reference, the position, the subject, the opening, the body paragraphs, the closing and the attachments. Its parts are value objects that validate on creation, and an edit is a new letter. It stores no salutation and no valediction: the page writes them (#187).
  - **`LetterDefaults`**: the person's salary expectation, start date and note, as the user's own text, bounded and trimmed. An empty text is a default that is not set. They belong to the person, not to a CV. A tailoring's override is a `LetterDefaults` too, and `applying(override:)` is the one rule that combines it with the person's: a field that the override sets wins, and an override cannot clear one. `PrestoCVIntegration` applies it when it builds the questions and the snapshot, so the override is entered before the questions are built. Nothing re-reads the defaults for a kept application. **`StoredLetterDefaults`** is the defaults as a store holds them, with the revision a save is conditional on.
  - **Texts** of an application, a letter and the defaults go through one rule (`ApplicationTextRule`): trimmed, bounded in UTF-8 bytes, and free of control characters (a line break only where a text spans lines) and of bidirectional overrides, as strict as `CVDocumentValidator`. A refusal is an `ApplicationError`, a code that names the field (`ApplicationField`).
  - **Refuse, and normalise at the entry.** The domain refuses hostile characters in an application's texts and does not clean them. The entry points normalise: the tailoring's model already refuses them, and the editor's text rules (#129) normalise what the user types.
  - **The bounds are per field,** so an application with every field at its bound is larger than the file's 5 MiB cap. Such a save fails as `tooLarge`, at the read-back check, and the property of #188, that every result the gate accepts maps to an application whose file stays within the cap, carries it. The bounds themselves are set so that Authoring accepts everything that Tailoring's model accepts (ADR 0019's property): a letter line and paragraph hold 10,000 bytes, a letter 20 attachments, a line of the tailored CV 200 sources, and the report 10,000 bytes per text. #188's property test holds the two sets of bounds together, and fails when one moves without the other.

**`PrestoCVApplication`**
- **Ports:**
  - `CVRepository`: create, conditional update, load, list, conditional delete. Typed `RepositoryError`, not cancellable.
  - `CVStoreMaintenance`: restore from quarantine, erase every copy, purge quarantine.
  - `SampleCVSource`, `IDGenerator`, `TimeSource`. `TimeSource` is so named to avoid shadowing `Swift.Clock`.
  - For applications ([ADR 0019](adr/0019-applications.md)):
    - `ApplicationRepository`: create, conditional update, load, list, conditional delete. Typed `ApplicationRepositoryError`, not cancellable, like `CVRepository`. Create for a job it already holds returns that application, the repository checking the job's identifier under its lock. Update and delete are conditional on the application's revision, which its CV and its letter share. Listing returns the healthy applications, ordered by last change, plus the store's `StoreIssue`s;
    - `ApplicationStoreMaintenance`: restore from quarantine, erase every copy, purge quarantine;
    - `LetterDefaultsStore`: load, save conditional on a revision (the first save expects revision 0, no file), and erase the person's defaults. Typed `LetterDefaultsError`, not cancellable. Defaults never saved load as `StoredLetterDefaults.unsaved`, and a store that cannot be read is an error, never empty defaults. `PrestoCVIntegration` reads it, applies the tailoring's override, and hands the defaults to the question builder (#153, #186);
    - `LetterDefaultsMaintenance`: restore and purge from the defaults' quarantine, beside the store so that a use case that only loads and saves never sees them;
    - an erase-all on each maintenance port, so that a file no listing returns goes too (planned, #91).
- **Use cases:**
  - `NewCV`, `SaveCV` (create or conditional update, errors translated to `AuthoringError`, including `tooLarge`), `LoadCV`;
  - list (by last change), rename, duplicate, delete, start from a sample, determine onboarding.
  - For applications: `CreateApplication`, `ListApplications`, `LoadApplication`, `UpdateApplicationCV`, `UpdateApplicationLetter` and `DeleteApplication`; and `LoadLetterDefaults` and `SaveLetterDefaults`. `CreateApplication` takes `ApplicationValues`, never Tailoring's types: the tailored CV's content with no identity, the letter, the advert and the provenance. It assigns the application's identity and its CV's through `IDGenerator`, and, for a job the store already holds, returns that application. A store's failures are translated once into `AuthoringError`: `invalid` carries the `ApplicationError` of a value the domain refuses, `corrupt` and `upgradeRequired` tell a defaults file that stands in quarantine from a newer one, and a write that would not read back is `tooLarge`.
  - **Erase-all** (planned, #91): it erases every CV, every application and the letter defaults, with their quarantined copies, each store under its own lock. A partial failure is a typed outcome that names what remains. Erasing a CV does not erase the applications made from it.
- **Listing** returns the healthy CVs plus `StoreIssue`s: `corrupt`, `upgradeRequired`, `unreadable`, `tooLarge`, `quarantineFailed`.

**`PrestoCVPersistence`**
- `FileCVRepository`:
  - one `CVFileV1` file per CV, named from its id;
  - atomic writes with `complete` protection, and a read-back check before every write;
  - every mutation under an exclusive `flock` on the store;
  - reads classified as described in R12;
  - `Quarantine/` with validated restore, erase and purge.
- `DirectorySampleCVSource`: sample CVs from an injected directory, in the same v1 format and through the store's own reader. The app ships them in `PrestoCV/Resources/Samples/`.
- For applications ([ADR 0019](adr/0019-applications.md)):
  - `FileApplicationRepository`: one `ApplicationFileV1` file per application (`<id>.application.json`), in a directory of its own with its own lock and `Quarantine/`. It gives the file every guarantee that `FileCVRepository` gives a CV: R12's every outcome, atomic writes, the read-back check, mutations under `flock`, and validated restore, erase and purge. The envelope is stored once, so the tailored CV inside has none of its own, and `cv` holds its `CVID` beside its content. The CV's content goes through `CVContentV1`, the DTO that `CVFileV1` writes too, so `Period.make` and the size caps exist once. Create peeks each stored application for its job under the lock and reads a match strictly, so a file that it cannot read, or that names the job and fails the strict read, does not hold it, and keeping a result is never refused because of another file. Create and list cost a pass over the store, O(applications × size): a peek per file for create, a strict read per file for list.
  - `FileLetterDefaultsStore`: the person's defaults in one `LetterDefaultsFileV1` file (`letter-defaults.json`), in a directory of its own with its own lock and `Quarantine/`. The envelope is `schemaVersion`, `revision` and `updatedAt`, with the three texts at the same level. It follows R12 in full. A save is conditional on a revision, and a stale save is a conflict. A missing file is empty defaults, and any other failure is an error, never an empty store. A corrupt file is moved to `Quarantine/` and reported with its reason, and the store remembers it by the copy that stands there: while a copy stands and no file replaces it, every load reports `corrupt`, until the user restores the copy or saves new defaults. A corrupt file that cannot be moved aside is reported as `quarantineFailed` and stays where it is. Only entries named like a copy of the defaults count as one.
  - The stores share their mechanics, `StoreDirectory` and `StoredFile`: the lock, the reading of a store that may not be there, the quarantine and its retention, the erasure of every copy, and the write that must read back. Erasure removes the stored file first and every copy that it can, even when the quarantine cannot be used or another copy cannot be removed, and fails with the first it could not remove. Each store keeps its names, its schema and its identity.
  - **A corrupt file is reported with a stable code** for its reason, never with printed text. For the application and the letter defaults it is the domain error's case and the field (`tooLong.subject`, `invalidReference.statementReference`), built by an exhaustive `switch`, or one of a few fixed codes (`version`, `revision`, `not canonical`). The reasons that `CVContentV1` gives for a CV's content are unchanged.
  - Erasing a CV leaves the applications made from it. The erase-all removes the CVs, the applications and the letter defaults, with their quarantined copies, each store under its own lock (planned, #91).

**Test support and tests.**
- `PrestoCVCoreTestSupport` may import `PrestoCVApplication`, `PrestoCVDomain`, Foundation, Synchronization. It holds:
  - `InMemoryCVRepository`, `SteppingClock`, `SequentialIDGenerator`;
  - the **`CVRepository` contract suite**: round trip with timestamps, create twice, update bumps the revision, stale update and stale delete, 50 concurrent updates from one revision leave exactly one success, update after delete, listing order.
- File-store behaviour that an in-memory store cannot have is tested in the Core tests, not in the contract: mixed directory, unreadable, oversized and hostile files, restore, erase, purge, and two instances racing.
- For applications ([ADR 0019](adr/0019-applications.md)): the same target holds `InMemoryApplicationRepository`, `InMemoryLetterDefaultsStore`, the failing doubles that the use cases' error translation is tested with, the fixtures that populate every field (`FixtureApplication`, `FixtureLetter`, `FixtureProvenance`), and two contract suites:
  - the **`ApplicationRepository` contract suite**, modelled on the `CVRepository` one: round trip with timestamps and the CV's identity, create twice, update bumps the revision, stale update and stale delete, update after delete, listing order, 50 concurrent updates from one revision, an edit of the CV and an edit of the letter from one revision conflicting, creating twice from one job returning the first, and concurrent creates for one job leaving one;
  - the **`LetterDefaultsStore` contract suite**: a first save over no file, a stale save, a cleared default, concurrent saves from one revision, and erase.

  The in-memory adapters and the file adapters pass them. The file stores' own cases, for applications and for the letter defaults, are tested in the Core tests, and so is the erase-all (#91): hostile, oversized and newer files, quarantine and restore, erasure of every copy, two instances racing, the read-back check, and the bytes of each file type, pinned.

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
- **`LetterDocument`** (planned, #187, [ADR 0019](adr/0019-applications.md)), a second published document type, beside `CVDocument`: the sender, the recipient and their form of address, the place and date, the reference and subject, the body, the closing, the name, the attachments and the `language`. The salutation and the valediction are the page's, not the document's (below). Plain values, no PrestoCV type. It carries a `schemaVersion`, and a letter that arrives as JSON passes a validator of its own, beside `CVDocumentValidator` (R8).

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
- **The cover letter** (planned, #187, [ADR 0019](adr/0019-applications.md)):
  - the letter's markup is a structure of its own, specified in [markup-contract.md](markup-contract.md) beside the CV's and pinned by a golden HTML file. Its classes are not in the table of what a design may select, and a design's CSS cannot select them;
  - one built-in stylesheet renders a `LetterDocument`, with the typed builder, for every design. It is not a design: it is not in the catalog, so no design choice can select it. It passes the same tokenizer and property allow-list as a design's, checked against the letter structure's selectors. Its colours and fonts are its own fixed values;
  - the page writes the salutation, the valediction and the date, in the document's language. The language conventions, the date format, the salutations and the valedictions, are data for the six languages: one JSON file per language and an index, with a completeness test (R13);
  - the letter is one A4 page, and one that does not fit is an error, never a truncated page. The PDF is checked against the builder's text nodes, as for a CV.

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

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `CVDrafting` | domain + application | iOS, macOS, Linux ✓ | Foundation |
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

---

## Package `CVTailoring` — CV Tailoring

Standalone, like `CVPDFExporter`. It depends on no PrestoCV package ([ADR 0013](adr/0013-cv-tailoring-context.md)): the app and the server each map their own types into its model. The targets are empty until the tickets named below fill them.

In the app, `PrestoCVIntegration` may import `TailoringModel`, `AdvertAnalysis` and `ContentChecks` only: the loop runs on the server. No type shares its module's name, so a qualified name always means the module (the loop is not a type called `Tailoring`, nor the gate one called `Provenance`).

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
- Language detection.
- The questions asked before a tailoring: required terms the CV does not evidence, and the letter fields the advert asks for that the defaults do not give (#153).

**`ContentChecks`** (#139)
- Spans that stay true, and figures as the CV writes them.

**`Provenance`** (#140, #141)
- The gate for the tailored CV and for the cover letter.
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
| `PrestoCVIntegration` | app application layer | iOS, macOS, Linux ✓ | `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain`, `CVDocumentModel`, `CVDesignCatalog`, `CVRendering`, `CVDrafting`, `TailoringModel`, `AdvertAnalysis`, `ContentChecks`, Foundation |
| `PrestoCVPresentation` | inbound adapter | iOS, macOS, Linux ✓ | `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain` (both `internal import`), Observation, Foundation |
| `PrestoCVAPIAdapter` | outbound adapter | iOS, macOS, Linux ✓ | `PrestoCVIntegration`, `TailoringModel`, `PrestoCVAPITypes`, `PrestoCVAPIClient` (both `internal import`), `OpenAPIRuntime`, `HTTPTypes`, Foundation |
| `PrestoCVComposition` | composition root | iOS, macOS | `PrestoCVIntegration`, `PrestoCVPresentation`, `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain`, `PrestoCVAPIAdapter`, `PrestoCVPersistence`, `CVDocumentModel`, `CVDesignCatalog`, `CVDesignCatalogFileStore`, `CVBundledDesigns`, `CVRendering`, `CVRenderingWebKitSupport`, `CVRenderingIOS` (iOS only), `CVRenderingMacOS` (macOS only), `CVRenderingPDFKitInspector`, `CVDrafting`, `CVDraftingFoundationModels`, `TailoringModel`, `AdvertAnalysis`, `ContentChecks`, `OpenAPIURLSession`, Foundation |

**`PrestoCVWorkflowPorts`**
- The ports that view models consume: `CVEditing` (new, save, load) and `CVExporting` (untyped `throws`, so cancellation passes through).
- App value types: `ExportOutcome`, `ExportFailure`.

**`PrestoCVIntegration`**
- **Workflows**, implementing the ports:
  - `EditCVWorkflow`;
  - `ExportCVWorkflow`: from the editor snapshot, with the document language, through the renderer, then the completeness check on the actual PDF;
  - `BrowseDesigns`;
  - `DraftCVWithAI`: availability, then draft, then an unsaved CV plus its gaps.
- **Mappers:** `CV → CVDocument` and `CVDraft → CV`. They are exhaustive and deterministic, with typed dates. The draft mapper uses `Period.make` and reports every gap.
  - `CV → SourceCV` (planned, #179).
  - The person's `LetterDefaults`, with a tailoring's override applied → the question builder's defaults and the snapshot's letter defaults (planned, #153, #179).
  - The tailoring result → the values that create takes: the tailored CV's content with no identity, the `CoverLetter`, the advert's company, role and text, and the provenance (planned, #188, [ADR 0019](adr/0019-applications.md)).
  - `CoverLetter` plus the person's details, which are those of the application's own CV, and its language → `LetterDocument` (planned, #187). It works on unsaved values too: the review's letter preview renders a letter before it is kept (#189).
  - Two modules each export a `CoverLetter` and a `LetterDefaults`, Tailoring's and Authoring's. The mappers name the module. Nothing maps an `Application` back into Tailoring's types.
- **The tailoring workflow and the application screens** (planned, #188, #191): the tailoring workflow saves the result as an application, and only then confirms to the server. The application workflows open its CV in the same editor, saving through the application's update, and its letter in an editor of its own, and export both PDFs.
- **Outbound ports that reach the server,** owned here (R3): the tailoring workflow's (start, read, cancel and confirm), the policy's (#190) and the push token's (#181). They speak the tailoring model and the workflow's typed errors, never a generated type. `PrestoCVAPIAdapter` implements them (planned, #179, #188).
- **The attestation port,** owned here (R3), not by `PrestoCVAPIAdapter` that calls it, so that no edge joins two adapters: it signs the encoded body of a start and proves the installation (#174). `PrestoCVAPIAdapter` calls it. The App Attest adapter of #174, a target that the ADR of #168 adds to this file, implements it and never calls the API.

**`PrestoCVPresentation`**
- `@Observable @MainActor` view models whose public API holds presentation types only: status enums, and no domain types.
- **Saves** are serialised and coalesced, and every caller waits for its own edits to land.
- **Save and export** each have their own status, reset when a new intent starts.
- **Conflict** offers reload or save as a copy; **deleted elsewhere** offers save as a copy.
- **View-model initialisers do no I/O.** Loading happens in the view's `.task`, so the factory can be called on every view init.

**`PrestoCVAPIAdapter`** (planned, #179, [ADR 0016](adr/0016-api-contract.md))
- The outbound adapter that implements the ports that reach the server. It is the app's only client of the API, for every endpoint the app calls: the tailorings, the policy, the push token, and the challenges, registration and sessions. It is the only target of the app that imports the API's generated client and types, and it imports both with `internal import`, so no generated type appears in its public API.
- It maps the tailoring model to the request, and the result back, exhaustively and under test ([ADR 0007](adr/0007-each-package-owns-its-model.md)). It maps each documented problem `type` to a typed error of the workflow (R7): "update the app", "try again at this time", "no provider meets the policy", and "consent again" for a policy version that is not the current one (#190). A `type` it does not know, or a response the spec does not document for that operation, becomes a generic typed error, and an enum value it does not know becomes a typed "unknown" case.
- It opens and renews the session, and signs the encoded body of a start through the attestation port, which `PrestoCVIntegration` owns and the App Attest adapter of #174 implements. The attestation adapter never calls the API.
- It offers one read of a job per call, and it sends the `DELETE` that confirms a saved result when the workflow asks (#166). The workflow drives the polling, which ends when the job is final, and its caller cancels it when the app leaves the foreground (R3: cancellation passes through). The backoff goes through an injected clock or sleeper (R2, R10).
- The composition root creates it, and the URLSession transport it runs on (R4). It carries R4's detectors, and the checker's `infrastructureTypes` lists `URLSessionTransport` once it exists. Until `URLSessionTransport` is listed in `infrastructureTypes`, review holds it.
- It imports the runtime's modules, `OpenAPIRuntime` and `HTTPTypes`, which the middleware that signs a start and sends the session needs. How the transport reaches its initialiser is #179's. If that needs more, #179 extends this table, without a new ADR.

**`PrestoCVComposition`**
- The app's composition root, and the only place in the app that creates infrastructure (R4). The `@main` App type holds it in a `static let`. It owns:
  - file locations under Application Support;
  - one `FileCVRepository`, one `FileApplicationRepository`, one `FileLetterDefaultsStore` and one `FileDesignStore`, which R4's `infrastructureTypes` lists;
  - the web-view rule list, compiled once;
  - the platform renderer and the PDFKit inspector;
  - the AI adapter, `TimeSource`, `IDGenerator` and logger;
  - the API adapter, with the URLSession transport it runs on (planned, #179);
  - the `ScreenFactory`.
- **UI tests and previews** use the production `FileCVRepository` on a temporary directory seeded from fixture JSON. A launch argument selects it. No production target depends on a test-support target.

**Test support.** `PrestoCVAppTestSupport` holds fakes for the workflow ports.

---

## Package `PrestoCVServer` — the server

A package of its own, next to the app's, in this repository ([ADR 0014](adr/0014-server-modular-monolith.md)). It is an integration and composition package, like `PrestoCVApp`, and not one of the isolated context packages (R1). It builds and tests on Linux, and runs on macOS for development.

The targets are created by #158 and the tickets named below. Until the targets exist, they are declared not yet implemented in the checker's `rules.json`.

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `ServerApplication` | application | Linux ✓, macOS | `TailoringModel`, `Tailoring`, Foundation |
| `ServerInference` | outbound adapter | Linux ✓, macOS | `ServerApplication`, `Tailoring`, `TailoringModel`, `AsyncHTTPClient`, Foundation |
| `ServerStorePostgres` | outbound adapter | Linux ✓, macOS | `ServerApplication`, `TailoringModel`, `PostgresNIO`, Foundation |
| `ServerQueueCloudTasks` | outbound adapter | Linux ✓, macOS | `ServerApplication`, `AsyncHTTPClient`, Foundation |
| `ServerLocalProfile` | outbound adapter | Linux ✓, macOS | `ServerApplication`, Foundation |
| `ServerHTTP` | inbound adapter | Linux ✓, macOS | `ServerApplication`, `TailoringModel`, `PrestoCVAPITypes`, `PrestoCVAPIServer` (both `internal import`), `Hummingbird`, `OpenAPIRuntime`, `OpenAPIHummingbird`, Foundation |
| `PrestoCVServer` | executable and composition root | Linux ✓, macOS | `ServerApplication`, `ServerInference`, `ServerStorePostgres`, `ServerQueueCloudTasks`, `ServerLocalProfile`, `ServerHTTP`, `Tailoring`, `Hummingbird`, `AsyncHTTPClient`, `PostgresNIO`, `ArgumentParser`, `Logging`, `ServiceLifecycle`, Foundation |

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
- It implements both ports: the inference port of `Tailoring`, and the data-policy port of `ServerApplication`, so `GET /v1/policy` reaches the policy. The registry's declarations and that port need no client and no key.
- **A router's dialect** derives its routing preferences from the deployment's policy (#154). A router's declaration covers the upstreams its routing preferences allow (#154): it keeps prompts, trains on them or runs in a region if it or any of those upstreams does.
- The adapter decodes the endpoint's envelope into the port's reply and errors, with a size cap. The model's text is decoded once, in `Tailoring` (R8).
- It never logs a prompt, an answer or a key. It never reads a secret, the environment or a secret store: the executable hands it the keys and the clients.

**`ServerStorePostgres`** (#160, #170, [ADR 0017](adr/0017-hosting-storage-and-cost.md))
- The job store, the quota store and the adapter of the device registry (#170) on Postgres, through PostgresNIO. Hosted, the database is Neon's, in Frankfurt: one project, with one branch per environment.
  - Each branch has its own role and password. No branch is made from another environment's data, and none is reset from its parent.
- Its rows are DTOs of its own, built from the types of `TailoringModel` (R12). What authentication keeps beyond the registry, and whether its tables share this schema, is decided by its own ADR (#168).
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
- **`work`** runs tailorings. Hosted, it is its own Cloud Run service, and it is private: only the queue's identity, which the erasure schedule (#166) also uses, may call it, and the platform refuses everyone else before any code runs. Only the worker holds the model providers' keys and the APNs key (#180).
- A tailoring finishes within the queue's dispatch deadline of 30 minutes.
- The binary has one more command, `migrate` (#160, #162). It is not a role.

**Profiles.** A profile is a set of adapters that the composition root picks from configuration.
- **`hosted`:** the Postgres store, on Neon in Frankfurt, and the Cloud Tasks queue, in `europe-west1` ([ADR 0017](adr/0017-hosting-storage-and-cost.md)).
- **`local`:** the in-memory stores and the in-process queue of `ServerLocalProfile`, with both roles in one process. It is for development only, and it refuses to start on any address but 127.0.0.1.

**Environments.** `local` uses the local profile. `staging` and `production` use the hosted profile, each with its own configuration, database and queue. Staging accepts App Attest's development environment and production only the production one. A merge to `main` deploys to staging, and a tag promotes the same image to production ([ADR 0017](adr/0017-hosting-storage-and-cost.md); the pipeline is #164).

**Where it runs** ([ADR 0017](adr/0017-hosting-storage-and-cost.md)). Hosted, both roles run on Cloud Run in `europe-west1`, with Cloud Tasks and the Cloud Scheduler job that runs erasure (#166) in the same region, and Postgres on Neon in Frankfurt.
- The secrets are in Secret Manager, one set per environment, and each is readable only by the identities that need it: its service, and CI's identity for the Neon credentials it needs (#164).
- The infrastructure is OpenTofu code in `infra/` (#163). It also sets each Cloud Run service's maximum number of instances, the queue's maximum dispatch rate, a log exclusion that drops the public service's platform request logs, which carry the caller's address, and an alert on a failed run of the erasure schedule.
- CI deploys through Workload Identity Federation. No long-lived key and no credential for Neon is stored in GitHub (#164).

**Translation.** On the server, the API's generated types are translated to and from the tailoring model only in `ServerHTTP`, and never leave it. A translation between two context packages on the server lives in a server target that this file designates for that translation, or needs an ADR (R1).

**Dependencies.**
- External packages are imported only by adapters and by the executable, never by `ServerApplication`. Each is pinned in the committed `Package.resolved`. A new one changes this file in the same pull request, and the checker's `--packages` rule holds it.
- The tickets that add logging and metrics (#167, #178) extend the adapters' allow-lists with `Logging` and `Metrics` in this file.
- The package depends on `CVTailoring`, and on `PrestoCVAPI` once #177 exists. It never depends on `PrestoCVApp` or `PrestoCVCore`.
- It may depend on the Linux targets of `CVPDFExporter` and of `CVGeneratorAI` (`CVDrafting`), which are reusable on a backend ([ADR 0002](adr/0002-cvpdfexporter-standalone-and-portable.md)). The ticket that needs such an edge adds it to this file, for example #94 or #196.
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
| `Platform/` | the platform shims: iOS-only modifiers wrapped for `Features/`, HTML and PDF previews, sharing, pasteboard, file import and export | SwiftUI, UIKit, AppKit, WebKit, PDFKit, QuickLook, UniformTypeIdentifiers, `CVRenderingWebKitSupport`, `PrestoCVPresentation` |
| `Resources/` | `Localizable.xcstrings`, sample CV JSON, assets | — |

---

## Dependency graph (summary)

```
PrestoCV (app) ─▶ PrestoCVPresentation ─▶ PrestoCVWorkflowPorts ─▶ PrestoCVApplication ─▶ PrestoCVDomain
     │                                     ▲
     │                     PrestoCVIntegration ┴─▶ CVRendering ─┬─▶ CVDocumentModel
     │                                    │                └─▶ CVDesignCatalog
     │                                    ├─▶ CVDrafting
     │                                    └─▶ TailoringModel, AdvertAnalysis, ContentChecks
     └────▶ PrestoCVComposition ─▶ (all of the above) + PrestoCVAPIAdapter, PrestoCVPersistence, CVDesignCatalogFileStore,
                                CVBundledDesigns, CVRenderingWebKitSupport, CVRenderingIOS | CVRenderingMacOS,
                                CVRenderingPDFKitInspector, CVDraftingFoundationModels

PrestoCVAPIAdapter ─┬─▶ PrestoCVIntegration, TailoringModel
                └─▶ PrestoCVAPITypes, PrestoCVAPIClient

PrestoCVServer (executable) ─┬─▶ ServerHTTP ─┬─▶ ServerApplication ─▶ TailoringModel, Tailoring
                         │               └─▶ TailoringModel, PrestoCVAPITypes, PrestoCVAPIServer
                         ├─▶ ServerInference ─▶ ServerApplication, Tailoring, TailoringModel
                         ├─▶ ServerStorePostgres ─▶ ServerApplication, TailoringModel
                         ├─▶ ServerQueueCloudTasks, ServerLocalProfile ─▶ ServerApplication
                         └─▶ ServerApplication, Tailoring

PrestoCVAPI package: PrestoCVAPIServer, PrestoCVAPIClient ─▶ PrestoCVAPITypes     (generated; imports no PrestoCV package)

Forbidden: any edge between PrestoCVCore, CVPDFExporter, CVGeneratorAI and CVTailoring.
Forbidden: any edge from a domain, application or port target to an adapter target.
Forbidden: PrestoCVPresentation → PrestoCVIntegration.
Forbidden: any edge from ServerApplication to a third-party package.
Forbidden: any edge from the server's package to PrestoCVApp or PrestoCVCore.
Forbidden: any import of a PrestoCVAPI target by a production target outside the package, except by ServerHTTP and PrestoCVAPIAdapter.
Forbidden: ServerHTTP importing PrestoCVAPIClient, and PrestoCVAPIAdapter importing PrestoCVAPIServer.
Forbidden: any edge from a PrestoCVAPI target to another package of this repository.
```
