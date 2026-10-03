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

A local package next to the Xcode project. The compiler holds the app's layers too, and everything except the composition and `PrestoCVAppAttest` builds and tests on Linux. `PrestoCVAppAttest` builds there as an empty target, since every file is wrapped in its platform condition (R11).

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `PrestoCVWorkflowPorts` | app ports | iOS, macOS, Linux ✓ | `PrestoCVApplication`, `PrestoCVDomain`, Foundation |
| `PrestoCVIntegration` | app application layer | iOS, macOS, Linux ✓ | `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain`, `CVDocumentModel`, `CVDesignCatalog`, `CVRendering`, `CVDrafting`, `TailoringModel`, `AdvertAnalysis`, `ContentChecks`, Foundation |
| `PrestoCVPresentation` | inbound adapter | iOS, macOS, Linux ✓ | `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain` (both `internal import`), Observation, Foundation |
| `PrestoCVAPIAdapter` | outbound adapter | iOS, macOS, Linux ✓ | `PrestoCVIntegration`, `TailoringModel`, `PrestoCVAPITypes`, `PrestoCVAPIClient` (both `internal import`), `OpenAPIRuntime`, `HTTPTypes`, Foundation |
| `PrestoCVAppAttest` | outbound adapter | iOS 26, macOS 27 | `PrestoCVIntegration`, `DeviceCheck`, `CryptoKit`, `Security`, Foundation |
| `PrestoCVComposition` | composition root | iOS, macOS | `PrestoCVIntegration`, `PrestoCVPresentation`, `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain`, `PrestoCVAPIAdapter`, `PrestoCVAppAttest`, `PrestoCVPersistence`, `CVDocumentModel`, `CVDesignCatalog`, `CVDesignCatalogFileStore`, `CVBundledDesigns`, `CVRendering`, `CVRenderingWebKitSupport`, `CVRenderingIOS` (iOS only), `CVRenderingMacOS` (macOS only), `CVRenderingPDFKitInspector`, `CVDrafting`, `CVDraftingFoundationModels`, `TailoringModel`, `AdvertAnalysis`, `ContentChecks`, `OpenAPIURLSession`, Foundation |

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
  - `CV → SourceCV`, and the tailoring result into the app's own types (planned, #184, #188).
- **Outbound ports that reach the server,** owned here (R3): the tailoring workflow's (start, read, cancel and confirm), the policy's (#190) and the push token's (#181). They speak the tailoring model and the workflow's typed errors, never a generated type. `PrestoCVAPIAdapter` implements them (planned, #179, #188).
- **The attestation port,** owned here (R3), not by `PrestoCVAPIAdapter` that calls it, so that no edge joins two adapters ([ADR 0018](adr/0018-app-attest.md)). It creates a key, attests it against a challenge and signs the encoded body of a start (#174). Its typed errors include "unavailable" (no App Attest here) and "invalid key" (Apple says the key is no longer valid). `PrestoCVAPIAdapter` calls it. `PrestoCVAppAttest` implements it and never calls the API.
  - An adapter of the port that throws "unavailable" lives here too, beside the port. It holds no platform code and no infrastructure, and the composition root installs it on macOS 26, where `PrestoCVAppAttest` cannot run (R14: never a fake success).

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

**`PrestoCVAppAttest`** (planned, #174, [ADR 0018](adr/0018-app-attest.md))
- The outbound adapter that implements the attestation port of `PrestoCVIntegration`. It never calls the API, and its allow-list holds no target of `PrestoCVAPI` and no other adapter: `PrestoCVAPIAdapter` fetches the challenge, registers the device, opens and renews the session, and signs a start through the port.
- It keeps the `isSupported` gate, the key and its Keychain entry, the attestation of a key against a challenge, and the fresh assertion over a body.
  - The key's ID lives in the Keychain, inside the adapter and available only on this device. Only this adapter uses it, so no port holds it.
  - Where Apple's service reports that it is unsupported, or that the key is invalid, it says so through the port's typed errors.
  - Apple's service and the Keychain sit behind seams internal to the target, so that a fake of each tests it.
- It imports `DeviceCheck` for Apple's service, `CryptoKit` for the hash of the body that an assertion signs, and `Security` for the Keychain.
- Its platforms are iOS 26 and later, and macOS 27 and later: the adapter is marked available from those versions, and every file is wrapped entirely in its platform condition (R11). The checker's `platformCondition` detector holds it.

**`PrestoCVComposition`**
- The app's composition root, and the only place in the app that creates infrastructure (R4). The `@main` App type holds it in a `static let`. It owns:
  - file locations under Application Support;
  - one `FileCVRepository` and one `FileDesignStore`;
  - the web-view rule list, compiled once;
  - the platform renderer and the PDFKit inspector;
  - the AI adapter, `TimeSource`, `IDGenerator` and logger;
  - the API adapter, with the URLSession transport it runs on (planned, #179);
  - the attestation adapter: `PrestoCVAppAttest` where the operating system has App Attest, and the "unavailable" adapter of `PrestoCVIntegration` where it has not (planned, #174);
  - in a debug build only, the development token, read from the Xcode scheme's environment (planned, #173);
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
| `ServerAuth` | application | Linux ✓, macOS | `ServerApplication`, Foundation |
| `ServerInference` | outbound adapter | Linux ✓, macOS | `ServerApplication`, `Tailoring`, `TailoringModel`, `AsyncHTTPClient`, Foundation |
| `ServerAttestApple` | outbound adapter | Linux ✓, macOS | `ServerAuth`, `Crypto`, `X509`, `SwiftASN1`, Foundation |
| `ServerSessionJWT` | outbound adapter | Linux ✓, macOS | `ServerAuth`, `JWTKit`, Foundation |
| `ServerStorePostgres` | outbound adapter | Linux ✓, macOS | `ServerApplication`, `ServerAuth`, `TailoringModel`, `PostgresNIO`, Foundation |
| `ServerQueueCloudTasks` | outbound adapter | Linux ✓, macOS | `ServerApplication`, `AsyncHTTPClient`, Foundation |
| `ServerLocalProfile` | outbound adapter | Linux ✓, macOS | `ServerApplication`, `ServerAuth`, Foundation |
| `ServerHTTP` | inbound adapter | Linux ✓, macOS | `ServerApplication`, `ServerAuth`, `TailoringModel`, `PrestoCVAPITypes`, `PrestoCVAPIServer` (both `internal import`), `Hummingbird`, `OpenAPIRuntime`, `OpenAPIHummingbird`, Foundation |
| `PrestoCVServer` | executable and composition root | Linux ✓, macOS | `ServerApplication`, `ServerAuth`, `ServerInference`, `ServerAttestApple`, `ServerSessionJWT`, `ServerStorePostgres`, `ServerQueueCloudTasks`, `ServerLocalProfile`, `ServerHTTP`, `Tailoring`, `Hummingbird`, `AsyncHTTPClient`, `PostgresNIO`, `JWTKit`, `ArgumentParser`, `Logging`, `ServiceLifecycle`, Foundation |

**`ServerApplication`** (#157, #155, #165, #166)
- **Use cases:** start a tailoring, run it, get it, erase (#166), and read the data policy (#155), which `GET /v1/policy` calls.
  - Start checks the caller's cost limits, records the job under its idempotency key and queues it. A known key returns its job before any limit is checked, and counts nothing more. It refuses a request that carries another policy version than the current one.
  - Run is the `work` role's use case: it loads the job, runs the loop of `Tailoring`, stores the result or the failure, and notifies the device (#180).
  - Get returns the job to its owner only. It compares the job's owner with the caller's `DeviceID`, and a job that another device owns gets the same "not found" as a job that does not exist ([ADR 0018](adr/0018-app-attest.md)).
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
- **Ports it owns (R3):** the job store, the job queue, the quota, the ports that erasing an idle device (#166), sweeping expired challenges (#170) and sweeping address counts (#172) go through, the clock, an identifier generator (R2), a notifier (#180), the log events, and the data-policy port that `GET /v1/policy` reads (#155, #175).
  - The ports of erasure and of the sweeps name a time and nothing of how a device was proven. The device registry's port is not among them: it is `ServerAuth`'s ([ADR 0018](adr/0018-app-attest.md)).
- **The data policy** ([ADR 0015](adr/0015-inference-providers-and-data-policy.md)), beside that port:
  - the types: what a provider declares (whether it keeps prompts, whether it trains on them, the regions it may run in), what a deployment requires, and the policy that `GET /v1/policy` serves: the requirements and the processors, which are the registry's providers named as the published privacy policy names them (#190);
  - the policy's version, derived from everything that endpoint serves, so a provider swap that still meets the requirements changes it. The start request carries the version the app showed the user, Start refuses a different one, the job records it, and the worker refuses to run it under another (#155, #176, #190);
  - the one rule, "a provider meets a policy": it keeps prompts and trains on them only where the policy allows it, and runs only in regions the policy accepts. A provider stricter than the policy meets it. The rule is pure, reads no ambient state (R2) and is tested without I/O.
- **Log events** are typed and never carry a CV, a prompt or a key (#167). The executable bridges the port to swift-log. Adapters log through an injected `Logger` once #167 extends their allow-lists with `Logging`.
- **`DeviceID`** is the caller's identity type, which jobs, quotas and retention share. `ServerAuth` produces it, and the use cases take it as an argument. `ServerApplication` never imports `ServerAuth` ([ADR 0018](adr/0018-app-attest.md)).
- **Typed errors** (R7). It imports no third-party package.

**`ServerAuth`** (#168, #169, #170, #171, #172, [ADR 0018](adr/0018-app-attest.md))
- The server's authentication layer, in the application layer. It imports `ServerApplication`, for `DeviceID`, the clock and the identifier generator, and no third-party package and no adapter. The invariant of [ADR 0014](adr/0014-server-modular-monolith.md) holds for it as for `ServerApplication`.
- **Use cases:**
  - issue a challenge, which is random, single-use and valid for 5 minutes;
  - register a device: verify an attestation, then record the key ID, the public key, the counter and App Attest's environment;
  - open a session: verify an assertion over a challenge, then issue a token, which is valid for 15 minutes;
  - check the assertion over the body of a start.
- **The counter rule:** an assertion's counter must be greater than the stored one, and it is stored in the same transaction that accepts the assertion, so of two assertions that arrive at once with the same counter, exactly one is accepted. The rule is in the registry port's contract suite (#170).
- **Ports it owns (R3):** the challenge store, the device registry (which also holds the push token, #180, and when the device was created and last used), the session signer, the session verifier, the verifier of attestations and assertions, the counts of unauthenticated requests per address (#172), and the verifier of the development token (#173). It uses the clock and the identifier generator of `ServerApplication`.
- **Typed errors** (R7). None echoes an attestation, an assertion or a token. A device the registry does not know gets the one that tells the app to register again.
- Its log events are the typed events of `ServerApplication`'s port, and none carries a token, an assertion, an attestation or an address (#167).

**`ServerInference`** (#154, #155, [ADR 0015](adr/0015-inference-providers-and-data-policy.md))
- The adapters behind the inference port that `Tailoring` owns (#150): the first one speaks the chat-completions API that most providers and local model servers share, with a dialect for each endpoint. A native adapter is written only for a provider with no compatible endpoint.
- **The registry,** built from configuration. It lists the providers in order of preference, each with its dialect, its endpoint, the name of the secret that holds its key (a provider that needs no key declares so), its allowed models with the capabilities of each (whether it supports structured output, its context size), its declaration, its name as the published privacy policy names it (#190), and an alias. The alias is the only name of a provider or model in a result, a log or a report (#156, #176).
- **Building the registry** applies the rule of `ServerApplication`. It fails with the refusal described under the executable when a provider does not meet the policy, so no running registry holds one and no fallback can reach one.
- **Selection and fallback:** the first available provider answers. When it is unavailable or rate-limited, the next one that meets the policy answers instead. No other error triggers a fallback, a refusal for lack of credit included (#165).
- It implements both ports: the inference port of `Tailoring`, and the data-policy port of `ServerApplication`, so `GET /v1/policy` reaches the policy. The registry's declarations and that port need no client and no key.
- **A router's dialect** derives its routing preferences from the deployment's policy (#154). A router's declaration covers the upstreams its routing preferences allow (#154): it keeps prompts, trains on them or runs in a region if it or any of those upstreams does.
- The adapter decodes the endpoint's envelope into the port's reply and errors, with a size cap. The model's text is decoded once, in `Tailoring` (R8).
- It never logs a prompt, an answer or a key. It never reads a secret, the environment or a secret store: the executable hands it the keys and the clients.

**`ServerAttestApple`** (#169, [ADR 0018](adr/0018-app-attest.md))
- The adapter behind `ServerAuth`'s verifier of attestations and assertions, for Apple's App Attest. It is the only target that imports the cryptographic packages: `Crypto`, `X509` and `SwiftASN1`, which #169 may extend here without a new ADR.
- It decodes an attestation object with a small CBOR decoder of its own, checks the certificate chain against Apple's App Attest root, and checks the challenge's value, the key ID, the app ID, the counter and the environment. It verifies the new checks of iOS 27 and macOS 27 whenever they are present. It verifies an assertion's signature and app ID.
- It is the boundary for Apple's bytes (R8): a size cap first, then a typed error for anything it does not understand, never a crash and never an echo of the input (R7).
- Apple's root is fixed in this target and passed to the verifier as a parameter, so tests use a root of their own. The app ID and the environments the deployment accepts are configuration, which the executable hands in.

**`ServerSessionJWT`** (#171, [ADR 0018](adr/0018-app-attest.md))
- The adapter behind `ServerAuth`'s session signer and session verifier. It imports `JWTKit`, and so does the executable, which builds the key collection.
- A token is a JWT signed with Ed25519 and valid for 15 minutes. It accepts EdDSA only, so any other algorithm, `none` included, is refused. Each key has an ID, and two keys verify during a rotation. A token is verified without the database.
- It never reads a secret store: the executable hands it the keys.

**`ServerStorePostgres`** (#160, #170, #172, [ADR 0017](adr/0017-hosting-storage-and-cost.md), [ADR 0018](adr/0018-app-attest.md))
- The job store and the quota store, behind ports of `ServerApplication`, and what authentication keeps, behind ports of `ServerAuth`: the device registry, the challenge store and the per-address counts (#170, #172). They are on Postgres, through PostgresNIO. The adapter also implements the ports of `ServerApplication` that erasure and the sweeps go through, beside them, so one transaction does each. It imports `ServerAuth` for this. Hosted, the database is Neon's, in Frankfurt: one project, with one branch per environment.
  - Each branch has its own role and password. No branch is made from another environment's data, and none is reset from its parent.
- Its rows are DTOs of its own, built from the types of `TailoringModel` (R12). Authentication keeps the registry, the challenges and the counts, and nothing else ([ADR 0018](adr/0018-app-attest.md)).
- The versioned SQL migrations (R12), in one history for the server's tables, those of authentication included ([ADR 0018](adr/0018-app-attest.md)). Only the binary's `migrate` command applies them, never `serve` or `work`.
- **Retention** (#166): it deletes the rows that `ServerApplication`'s erasure names, and marks nothing as deleted. Quota counts go with their device at the latest.

**`ServerQueueCloudTasks`** (#161, [ADR 0017](adr/0017-hosting-storage-and-cost.md))
- The job queue on Cloud Tasks, in `europe-west1` beside the Cloud Run services, over AsyncHTTPClient. A task is named after its job and calls the worker with the queue's own identity.
- A task carries the job's ID and nothing else. The CV and the advert are in the job store only.
- It gets its access token from a token provider that the executable creates and hands in.
- The dispatch deadline is 30 minutes, and retries use backoff.

**`ServerLocalProfile`** (#157, #158, #170, #173)
- The in-memory job store and quota store, and the in-process queue, of the local profile. It also holds the in-memory device registry, challenge store and address counts, the in-memory adapters of the ports that erasure and the sweeps go through, and the verifier of the development token ([ADR 0018](adr/0018-app-attest.md)).
- They are adapters of a profile the executable ships, not test doubles (R14). Each passes the contract suite of its port.
- **The development token** is compared in constant time. The executable reads its file and hands the token in, so the profile reads no file (R4). The executable installs the verifier only in the local profile, and refuses to start when a hosted configuration accepts a development token (#173).

**`ServerHTTP`** (#175, #178)
- The inbound adapter: the Hummingbird routes, the middleware, and the handlers that implement the generated API.
- **The authentication middleware** ([ADR 0018](adr/0018-app-attest.md)). It imports `ServerAuth`. It checks the bearer token through the session verifier, without the database, and answers 401 to a missing or invalid one. For a start, it also hands the body, under its size cap (R8), and the assertion to `ServerAuth`. It carries the caller to the handlers in a task-local value, and passes it to each use case as an argument (#171). It guards the public API only: the worker's routes are admitted by the platform, as below.
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
- **Authentication** ([ADR 0018](adr/0018-app-attest.md)). `serve` reads the session signing keys, and they are readable by its identity alone ([ADR 0017](adr/0017-hosting-storage-and-cost.md)). The executable builds `JWTKit`'s key collection from them and hands it to `ServerSessionJWT`. It reads the App Attest configuration, the app ID and the environments the deployment accepts. In the local profile it reads the development token's file. It hands all of it in, and installs the development token's verifier only in the local profile.
- It starts as `serve`, as `work`, or, in the local profile, as both. It composes the router per role.
- It shuts down cleanly on SIGTERM: the job in hand is finished or released back to the queue.

**Roles.**
- **`serve`** answers the API. Hosted, it is its own Cloud Run service. It records a job and hands it to the queue. It checks the data policy at start and serves it, and it reads no provider's key. It authenticates the devices, and alone reads the session signing keys.
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
- The targets for logs and notifications are set by their tickets' decisions (#167, #180) and added to this file then. Authentication's are `ServerAuth`, `ServerAttestApple` and `ServerSessionJWT` ([ADR 0018](adr/0018-app-attest.md)).
- The cryptographic packages are imported only by `ServerAttestApple`, and `JWTKit` only by `ServerSessionJWT` and the executable.

**Test support.** None yet. The contract suites of the ports (#157, and #170 for the registry and the challenge store) live in a test-support target that #157 adds to this file, as R10 asks. `ServerApplication`'s own tests use the adapters of `ServerLocalProfile`, so there is no second copy of them.

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
     └────▶ PrestoCVComposition ─▶ (all of the above) + PrestoCVAPIAdapter, PrestoCVAppAttest, PrestoCVPersistence, CVDesignCatalogFileStore,
                                CVBundledDesigns, CVRenderingWebKitSupport, CVRenderingIOS | CVRenderingMacOS,
                                CVRenderingPDFKitInspector, CVDraftingFoundationModels

PrestoCVAPIAdapter ─┬─▶ PrestoCVIntegration, TailoringModel
                └─▶ PrestoCVAPITypes, PrestoCVAPIClient

PrestoCVAppAttest ─▶ PrestoCVIntegration     (iOS 26, macOS 27; DeviceCheck, CryptoKit, Security)

PrestoCVServer (executable) ─┬─▶ ServerHTTP ─┬─▶ ServerApplication ─▶ TailoringModel, Tailoring
                         │               ├─▶ ServerAuth ─▶ ServerApplication
                         │               └─▶ TailoringModel, PrestoCVAPITypes, PrestoCVAPIServer
                         ├─▶ ServerInference ─▶ ServerApplication, Tailoring, TailoringModel
                         ├─▶ ServerAttestApple, ServerSessionJWT ─▶ ServerAuth
                         ├─▶ ServerStorePostgres ─▶ ServerApplication, ServerAuth, TailoringModel
                         ├─▶ ServerLocalProfile ─▶ ServerApplication, ServerAuth
                         ├─▶ ServerQueueCloudTasks ─▶ ServerApplication
                         └─▶ ServerApplication, ServerAuth, Tailoring, JWTKit

PrestoCVAPI package: PrestoCVAPIServer, PrestoCVAPIClient ─▶ PrestoCVAPITypes     (generated; imports no PrestoCV package)

Forbidden: any edge between PrestoCVCore, CVPDFExporter, CVGeneratorAI and CVTailoring.
Forbidden: any edge from a domain, application or port target to an adapter target.
Forbidden: PrestoCVPresentation → PrestoCVIntegration.
Forbidden: any edge from ServerApplication to a third-party package.
Forbidden: any edge from ServerApplication to ServerAuth, and any edge from ServerAuth to a third-party package or an adapter.
Forbidden: the cryptographic packages imported outside ServerAttestApple, and JWTKit outside ServerSessionJWT and the executable.
Forbidden: PrestoCVAppAttest importing PrestoCVAPIAdapter or a target of PrestoCVAPI, and DeviceCheck imported outside PrestoCVAppAttest.
Forbidden: any edge from the server's package to PrestoCVApp or PrestoCVCore.
Forbidden: any import of a PrestoCVAPI target by a production target outside the package, except by ServerHTTP and PrestoCVAPIAdapter.
Forbidden: ServerHTTP importing PrestoCVAPIClient, and PrestoCVAPIAdapter importing PrestoCVAPIServer.
Forbidden: any edge from a PrestoCVAPI target to another package of this repository.
```
