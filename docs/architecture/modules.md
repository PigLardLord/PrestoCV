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

A local package next to the Xcode project. The compiler holds the app's layers too, and everything except the composition builds and tests on Linux.

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `PrestoCVWorkflowPorts` | app ports | iOS, macOS, Linux ✓ | `PrestoCVApplication`, `PrestoCVDomain`, Foundation |
| `PrestoCVIntegration` | app application layer | iOS, macOS, Linux ✓ | `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain`, `CVDocumentModel`, `CVDesignCatalog`, `CVRendering`, `CVDrafting`, `TailoringModel`, `AdvertAnalysis`, `ContentChecks`, Foundation |
| `PrestoCVPresentation` | inbound adapter | iOS, macOS, Linux ✓ | `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain` (both `internal import`), Observation, Foundation |
| `PrestoCVComposition` | composition root | iOS, macOS | everything above, plus `PrestoCVPersistence`, `CVDesignCatalogFileStore`, `CVBundledDesigns`, `CVRenderingIOS` (iOS only), `CVRenderingMacOS` (macOS only), `CVRenderingWebKitSupport`, `CVRenderingPDFKitInspector`, `CVDraftingFoundationModels` |

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

**`PrestoCVPresentation`**
- `@Observable @MainActor` view models whose public API holds presentation types only: status enums, and no domain types.
- **Saves** are serialised and coalesced, and every caller waits for its own edits to land.
- **Save and export** each have their own status, reset when a new intent starts.
- **Conflict** offers reload or save as a copy; **deleted elsewhere** offers save as a copy.
- **View-model initialisers do no I/O.** Loading happens in the view's `.task`, so the factory can be called on every view init.

**`PrestoCVComposition`**
- The app's composition root, and the only place in the app that creates infrastructure (R4). The `@main` App type holds it in a `static let`. It owns:
  - file locations under Application Support;
  - one `FileCVRepository` and one `FileDesignStore`;
  - the web-view rule list, compiled once;
  - the platform renderer and the PDFKit inspector;
  - the AI adapter, `TimeSource`, `IDGenerator` and logger;
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

**`ServerApplication`** (#157, #155)
- **Use cases:** start a tailoring, run it, get it and delete it, and read the data policy (#155), which `GET /v1/policy` calls.
  - Start checks the caller's quota, records the job under its idempotency key and queues it. The same key returns the same job. It refuses a request that carries another policy version than the current one.
  - Run is the `work` role's use case: it loads the job, runs the loop of `Tailoring`, stores the result or the failure, and notifies the device (#180).
  - Get returns the job to its owner only. Delete erases it.
- **The job lifecycle:** queued, running, succeeded, failed, expired. A job is erased once the app confirms it has saved the result, and 24 hours after the job ends at the latest (#166).
- **The lease.** A running job holds a lease, and a job whose lease has expired is taken over by the retry (#161). The lease belongs to the job's lifecycle and to its contract suite, not to the queue adapter.
- **Ports it owns (R3):** the job store, the job queue, the quota, the clock, an identifier generator (R2), a notifier (#180), the log events, and the data-policy port that `GET /v1/policy` reads (#155, #175).
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
- **A router's dialect** derives its routing preferences from the deployment's policy (#154). A router's declaration covers its upstreams: its regions are its own and those of the upstreams its routing preferences allow, and it keeps prompts if it or any of those upstreams does.
- The adapter decodes the endpoint's envelope into the port's reply and errors, with a size cap. The model's text is decoded once, in `Tailoring` (R8).
- It never logs a prompt, an answer or a key. It never reads a secret, the environment or a secret store: the executable hands it the keys and the clients.

**`ServerStorePostgres`** (#160)
- The job store and the quota store on Postgres, through PostgresNIO. Its rows are DTOs of its own, built from the types of `TailoringModel` (R12).
- The versioned SQL migrations (R12). Only the binary's `migrate` command applies them, never `serve` or `work`.

**`ServerQueueCloudTasks`** (#161)
- The job queue on Cloud Tasks, over AsyncHTTPClient. A task is named after its job and calls the worker with the queue's own identity.
- The dispatch deadline is 30 minutes, and retries use backoff.

**`ServerLocalProfile`** (#157, #158)
- The in-memory job store and quota store, and the in-process queue, of the local profile.
- They are adapters of a profile the executable ships, not test doubles (R14). Each passes the contract suite of its port.

**`ServerHTTP`** (#175, #178)
- The inbound adapter: the Hummingbird routes, the middleware, and the handlers that implement the generated API.
- It maps the generated types to the use cases and back. The generated types never leave it: it imports `PrestoCVAPITypes` and `PrestoCVAPIServer` with `internal import`, so none can appear in its public API.
- It serves the API on Hummingbird through `OpenAPIHummingbird`. `GET /health` is an endpoint of the spec, and `ServerHTTP` serves it in both roles.
- **The worker's route.** The route the queue calls to run a job lives here too. It is mounted only in the `work` role, and it is not part of the public API (`openapi.yaml`). The platform admits only the queue's identity before any code runs (#161).
- `PrestoCVAPITypes` and `PrestoCVAPIServer` are targets of the `PrestoCVAPI` package, which #175 and #177 add to this file.

**The `PrestoCVServer` executable target**
- The executable and the server's composition root (R4). It reads the command line with ArgumentParser and the configuration, picks the profile's adapters, wires them behind the ports of `ServerApplication` and of `Tailoring`, and creates the infrastructure: the database pool, the queue client, the inference providers' HTTP client (in the role that holds the keys), the clock, the identifier generators and the logger.
- It reads the deployment's configuration and refuses to start, with an error that names the cause, when a provider does not meet the data policy, when a model is not allowed, when a secret cannot be read, or when a provider's declaration is incomplete (#155, [ADR 0015](adr/0015-inference-providers-and-data-policy.md)). Nothing is skipped silently.
  - Both roles read one configuration, and each checks the policy and the models.
  - In the role that holds the keys, it reads the secrets, hands them to the adapters and creates the providers' HTTP client, one per process.
- It starts as `serve`, as `work`, or, in the local profile, as both. It composes the router per role.
- It shuts down cleanly on SIGTERM: the job in hand is finished or released back to the queue.

**Roles.**
- **`serve`** answers the API. Hosted, it is its own Cloud Run service. It records a job and hands it to the queue. It checks the data policy at start and serves it, and it reads no secret.
- **`work`** runs tailorings. Hosted, it is its own Cloud Run service, and it is private: only the queue's identity, which the erasure schedule (#166) also uses, may call it, and the platform refuses everyone else before any code runs. Only the worker holds the model providers' keys.
- A tailoring finishes within the queue's dispatch deadline of 30 minutes.
- The binary has one more command, `migrate` (#160, #162). It is not a role.

**Profiles.** A profile is a set of adapters that the composition root picks from configuration.
- **`hosted`:** the Postgres store and the Cloud Tasks queue.
- **`local`:** the in-memory stores and the in-process queue of `ServerLocalProfile`, with both roles in one process. It is for development only, and it refuses to start on any address but 127.0.0.1.

**Environments.** `local` uses the local profile. `staging` and `production` use the hosted profile, each with its own configuration, database and queue. Staging accepts App Attest's development environment and production only the production one. How a change reaches each belongs to the infrastructure layer of #133.

**Translation.** On the server, the API's generated types are translated to and from the tailoring model only in `ServerHTTP`, and never leave it. A translation between two context packages on the server lives in a server target that this file designates for that translation, or needs an ADR (R1).

**Dependencies.**
- External packages are imported only by adapters and by the executable, never by `ServerApplication`. Each is pinned in the committed `Package.resolved`. A new one changes this file in the same pull request, and the checker's `--packages` rule holds it.
- The tickets that add logging and metrics (#167, #178) extend the adapters' allow-lists with `Logging` and `Metrics` in this file.
- The package depends on `CVTailoring`, and on `PrestoCVAPI` once #177 exists. It never depends on `PrestoCVApp` or `PrestoCVCore`.
- It may depend on the Linux targets of `CVPDFExporter` and of `CVGeneratorAI` (`CVDrafting`), which are reusable on a backend ([ADR 0002](adr/0002-cvpdfexporter-standalone-and-portable.md)). The ticket that needs such an edge adds it to this file, for example #94 or #196.
- The targets for authentication, logs and notifications are set by their tickets' decisions (#167, #168, #180) and added to this file then.

**Test support.** None yet. The contract suites of the ports (#157) live in a test-support target that #157 adds to this file, as R10 asks. `ServerApplication`'s own tests use the adapters of `ServerLocalProfile`, so there is no second copy of them.

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
     └────▶ PrestoCVComposition ─▶ (all of the above) + PrestoCVPersistence, CVDesignCatalogFileStore, CVBundledDesigns,
                                CVRenderingWebKitSupport, CVRenderingIOS | CVRenderingMacOS,
                                CVRenderingPDFKitInspector, CVDraftingFoundationModels

PrestoCVServer (executable) ─┬─▶ ServerHTTP ─┬─▶ ServerApplication ─▶ TailoringModel, Tailoring
                         │               └─▶ TailoringModel, PrestoCVAPITypes, PrestoCVAPIServer
                         ├─▶ ServerInference ─▶ ServerApplication, Tailoring, TailoringModel
                         ├─▶ ServerStorePostgres ─▶ ServerApplication, TailoringModel
                         ├─▶ ServerQueueCloudTasks, ServerLocalProfile ─▶ ServerApplication
                         └─▶ ServerApplication, Tailoring

Forbidden: any edge between PrestoCVCore, CVPDFExporter, CVGeneratorAI and CVTailoring.
Forbidden: any edge from a domain, application or port target to an adapter target.
Forbidden: PrestoCVPresentation → PrestoCVIntegration.
Forbidden: any edge from ServerApplication to a third-party package.
Forbidden: any edge from the server's package to PrestoCVApp or PrestoCVCore.
```
