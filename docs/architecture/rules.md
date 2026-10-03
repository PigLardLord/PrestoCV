# Architecture rules

These rules are strict on purpose. A change that breaks one does not merge. There are two ways to live with a violation, and both are explicit ([ADR 0006](adr/0006-enforce-architecture-mechanically.md)):

- **Baseline:** temporary. An existing violation is listed in the checker's baseline, which may only shrink.
- **Exception:** permanent. It is an entry in the checker's `rules.json`, and it cites an ADR that explains why. The checker refuses an exception whose ADR does not exist.

Each rule says what is required, why, and what enforces it:

- **compiler**: the SwiftPM target graph, `internal import`, or the Swift 6 language mode rejects the violation.
- **checker**: `Tools/ArchitectureCheck` fails. It parses every file with SwiftSyntax and runs named detectors; the detectors are listed with each rule.
- **test**: a required test fails.
- **review**: nothing automatic can catch it. Kept to a minimum, and marked as such.

The checker applies to **production targets**: domain, application, integration, presentation and adapter targets, and the composition roots. Test, test-support and tool targets get the import allow-lists only. Legacy targets are exempt until deleted ([ADR 0012](adr/0012-legacy-targets-during-migration.md)).

---

## R1. Packages are isolated; contexts depend only along documented edges

- **Packages are isolated.** `PrestoCVCore`, `CVPDFExporter`, `CVGeneratorAI` and `CVTailoring` never import one another. Translation between packages happens only in `PrestoCVIntegration`, in the app, and in `ServerHTTP`, in the server ([ADR 0014](adr/0014-server-modular-monolith.md)).
- **The server's package is not one of them.** `PrestoCVServer` is an integration and composition package, like `PrestoCVApp`. It imports the context packages it serves, and never `PrestoCVApp`, `PrestoCVCore` or `CVGeneratorAI`. It may import `CVPDFExporter`, which is reusable on a backend ([ADR 0002](adr/0002-cvpdfexporter-standalone-and-portable.md)), once [modules.md](modules.md) lists that edge.
- **Inside a package, contexts depend only along the edges listed in [modules.md](modules.md).** There is exactly one such edge today: in `CVPDFExporter`, Document Rendering is downstream of Design Catalog (`CVRendering` imports `CVDesignCatalog`). The reverse is forbidden.
- **Any other edge** between contexts needs an ADR and an update to [modules.md](modules.md).
- **`@_exported import` is banned.** It would re-export a module to every importer.

**Why.** Today the exporter imports PrestoCVCore for a single adapter, the AI package defines a parallel CV model that a view model translates, and "template" means several different things across packages.

**Enforced by:**
- **compiler:** the target dependencies.
- **checker:** a per-target import allow-list, and the `exportedImport` detector. SwiftPM lets a target import its dependencies' dependencies, so declared dependencies are not enough.
- **checker (`--packages`):** every dependency declared in a `Package.swift` must be an allowed import.

## R2. Pure layers read no ambient state

Domain, application, integration, presentation and workflow-port targets must not use:

- `Bundle` (except `Bundle.module`, a package's own resources), `FileManager`, `UserDefaults`, `ProcessInfo`, `NotificationCenter`;
- `Locale.current`, `TimeZone.current`, `Calendar.current` and their `autoupdatingCurrent` forms;
- `String(localized:)`, `NSLocalizedString`, `LocalizedStringResource`, `LocalizedStringKey`;
- `Date()`, `Date.init()`, `Date.now`, `.now` or `UUID()` / `UUID.init()` to create values. Inject a `TimeSource` or an `IDGenerator` instead;
- `print`, `debugPrint`, `dump`, `NSLog`.

**Why.** Core localises user-facing text through the host app's `Bundle.main`, which is why it does not build on Linux (#27). Adapters create a fresh `UUID()` and `Date()` on every conversion, which is why the preview cache never hits. Hidden globals make behaviour untestable and non-deterministic.

**Enforced by:** checker (detectors `wallClock`, `randomIdentity`, `ambientEnvironment`, `localization`, `printing`).

## R3. Ports belong to the consumer; adapters live in their own targets

An outbound port is declared by the layer that needs it and implemented in an adapter target that imports that layer, never the other way round. A port:

- speaks the consumer's language: it does not expose `URL`, `[String: Any]`, `WKWebView`, `Bundle` or framework types unless that is its purpose (a renderer returns `Data`);
- is `Sendable` and not constrained to `Actor` or `AnyObject`;
- is async when the work is async; there is no synchronous wrapper around async code;
- lets `CancellationError` through when the work can be cancelled. Such ports use untyped `throws`. Repository operations are short, synchronous I/O. They are not cancellable, and use typed errors.

A protocol with one implementation exists only if it is a port or has a test double in use. Speculative protocols are deleted.

**Enforced by:** compiler (target graph) and review.

## R4. One composition root per executable

Each executable has one composition root, and only that root creates infrastructure. The app's root is `PrestoCVComposition`. The server's root is the `PrestoCVServer` executable target ([ADR 0014](adr/0014-server-modular-monolith.md)). Infrastructure is: repositories, stores, renderers, the compiled web-view rule list, the AI adapter, file locations, time sources, identifier generators and loggers. On the server it also includes the database pool, the queue client and the inference providers' clients.

- Each executable creates its composition **once**: the app's `@main` App type as a `static let`, the server's `@main` command at start. That is the only process-wide instance.
- Libraries do not provide `init()`s or default arguments that create infrastructure.
- Libraries contain no containers, service locators or `static let shared` singletons.
- Each stateful resource (the design store, the CV store) exists once per process. Across processes, the file store serialises writers with a lock ([ADR 0009](adr/0009-persisted-schema-v1.md)).

**Why.** Today objects are built in four places, the template subsystem exists three times over the same files, and the export sheet builds its own container every time it opens. Issue #1 is a direct consequence.

**Enforced by:** checker (detectors `singleton`, and `infrastructureConstruction` for the adapter types listed in `rules.json` and for `FileManager.default`, `Bundle.main`, `UserDefaults.standard`) and review.

## R5. Views render; view models present; neither decides

- **Views** (Xcode app target) render presentation state and turn status enums into localised text. They forward user intents to the view model, and never construct view models or services.
- **View models** (`PrestoCVPresentation`) hold presentation state and call workflow ports. Rules:
  - They depend on `PrestoCVWorkflowPorts`, never on `PrestoCVIntegration`.
  - They import `PrestoCVDomain` and `PrestoCVApplication` with `internal import`, so no domain type can appear in their public API.
  - They import no UI framework.
- **Business rules** live in the domain or application layer of their context.

**Why.** Today the rule for "a CV can be saved" lives in `CVEditorViewModel`, the export-enabled rule in `CVExportSheetView`, the AI-to-CV mapping in `AIGenerationViewModel`, and `AppRootView` is the composition root.

**Enforced by:**
- **compiler:** `internal import`. A public property of type `CV` fails with "property cannot be declared public because its type uses an internal type", as verified.
- **compiler:** target dependencies.
- **checker:** import allow-lists, and the `importAccess` constraint. In `PrestoCVPresentation`, `PrestoCVDomain` and `PrestoCVApplication` must be imported `internal` or narrower. A plain `import` is public in Swift 6, so it fails as well.
- **review:** whether a view contains a business rule.

## R6. The domain is rich and keeps its invariants

- **Behaviour, not fields.** Aggregates and entities expose behaviour, not `public var` fields. State changes go through methods.
- **Repository-owned state.** The revision and the timestamps are assigned only by repositories (`package` access).
- **Value objects validate on creation.** `SkillLevel` is bounded. `PartialDate` has year or month precision, and only a partial order. `EmailAddress` and `WebLink` are parsed. Identifiers are typed.
- **A rule exists once.** Periods are built only by `Period.make(start:end:current:)`, which both persistence and the AI mapper use. A second copy anywhere is a defect.
- **Two separate validity rules, by design.** "Can be saved" is Authoring's rule. "Can be rendered" is the rendering policy of the published `CVDocument`. A test asserts that every saveable CV maps to a renderable document.

**Why.** Today there are four definitions of "valid CV", three skill scales, three language-level parsers and four period formats.

**Enforced by:** test (each invariant, and the saveable-implies-renderable property) and review.

## R7. Errors are typed per context and translated at the boundary

- **Each context has its own error type.** Errors carry codes and file names, never paths or free-form strings.
- **`CancellationError` is always passed through unchanged.**
- **Errors are translated once, where they cross a boundary.** For example, `SaveCV` turns repository errors into `AuthoringError`. Presentation never matches the shape of a port's errors.
- **Nothing swallows an error.** There is no `try?` and no empty `catch` in production code. A tolerated failure is mapped explicitly to a typed outcome with `do`/`catch`.
- **Only a store that does not exist yet is empty.** A store that cannot be read is an error.

**Why.** Today storage failures read as "no CVs" and send users back to onboarding, corrupt files vanish silently, and the renderer turns cancellation into `renderingFailed(String)`.

**Enforced by:** checker (detector `swallowedError`) and review.

## R8. Untrusted input enters through one validating boundary

Untrusted input is: design packages, AI output, persisted files, and on a backend every request. Each kind enters through one anti-corruption layer that validates it into domain types or rejects it.

- **Design packages** ([ADR 0011](adr/0011-typed-html-builder.md)):
  - validated on the raw bytes: size cap first, then strict decoding (unknown keys and any `htmlContent` key are rejected), identifier `[a-z0-9-]{1,64}`, the supported markup contract version, and a PNG preview within size;
  - **design CSS is parsed and allow-listed, never sanitised.** A CSS tokenizer accepts only the selectors of the [markup contract](markup-contract.md) and an allow-list of properties with bounded values. It then re-serialises the tokens, so the CSS emitted is exactly the CSS validated;
  - rejected outright: `<`, CSS escapes, comments inside tokens, at-rules other than `@media print|screen|all`, pseudo-elements, `:has()` and other functional pseudo-classes, ids, custom properties, `!important`, every resource-bearing function;
  - **not in the allow-list**, so it cannot hide, move, reorder or inject content: `position`, `transform`, `zoom`, `filter`, `mask`, `clip`, `overflow`, `visibility`, `opacity`, `content`, `list-style`, `quotes`, counters, `direction`, `order`;
  - **colours** only through the palette variables. Text can only use `--color-text` or `--color-primary`, and a palette exists only if text contrast is at least 4.5:1 and primary contrast at least 3:1;
  - **fonts** only through `--font-body` and `--font-heading`, from a closed set of system families. Embedding fonts needs its own ADR, with native registration.
- **User values** are escaped per Unicode scalar and never re-parsed.
  - Tag and attribute names are closed enums.
  - The document language must look like a BCP 47 tag; otherwise it becomes `und`.
  - A link is kept only as a parsed `WebLink`, in its parsed form: an allow-listed scheme; for http(s) an ASCII host, no credentials and default ports; no control or format characters; at most 2048 bytes.
- **The web view** has JavaScript off for content and a non-persistent store. Network is blocked by a compiled content rule list: one block rule per network scheme, plus a block on every subresource type. The rule list is compiled once, in the composition root; if it cannot be installed, rendering fails. The view accepts only the initial load, and cancels any later navigation.
- **Completeness.** Every export is checked against its own document. Every text node the builder produced (fields, headings, dates, levels) needs **its own span of the PDF text**, ignoring case and spacing, that no other node uses; longer nodes are placed first. So removing one of two identical entries is detected, so is removing a value that also appears inside another one (a skill named in the summary), and so is a value that only appears across the boundary of two others ("Greg" + "Officer" contains "go"). Link destinations are printed as text ([markup contract](markup-contract.md)), so losing one is detected too, even when the clickable annotation is not part of the PDF. A shortfall fails the export.
- **Installing a design.** A design is stored only after it has been validated and has rendered a fixture document completely. The fixture exercises every section; a truncated render is a failure. The catalog owns the rendering-gate port, and `CVRendering` implements it. The renderer contract runs the same check.
- **Native evidence.** The native renderers must also pass a geometric check: each field inside the page, and legible. It is pending until they exist ([ADR 0003](adr/0003-one-pdf-renderer-per-platform.md)).
- **Documents** arriving as JSON (backend) pass `CVDocumentValidator`: supported version, required name, bounded text and counts, valid dates and ratings.
- **Persisted files**: see R12.

**Why.** See issue #9 and the security review of 2026-09-27: a regex deny-list let 34 of 34 content-hiding constructs through, and could be bypassed with CSS comments and strings. On a backend, a `<style>` breakout would be server-side request forgery.

**Enforced by:** test (one per attack, listed in the Design Catalog and Rendering tests) and the type system (`ValidatedStylesheet` can only be created by the validator).

## R9. Swift 6, complete concurrency checking, no escape hatches

Every production target builds in the Swift 6 language mode with complete concurrency checking. **No manifest** may use `swiftLanguageMode(.v5)` or `unsafeFlags`, except for legacy targets ([ADR 0012](adr/0012-legacy-targets-during-migration.md)).

Production code does not use:
- `@unchecked Sendable` (in any spelling), `nonisolated(unsafe)`, `MainActor.assumeIsolated`;
- `DispatchSemaphore` or any other blocking wait on async work;
- `fatalError`, `precondition`, `preconditionFailure`, `try!`, `as!`, force unwraps.

Continuations resume exactly once, time out where they wait on the outside world, and support cancellation (review).

**Enforced by:** compiler, checker (detectors `escapeHatch` in sources; `swift5Mode` and `unsafeFlags` in manifests, where only the declaration of a legacy target is exempt; with `--packages`, the effective language mode of every target that is not legacy must be Swift 6) and review for continuations. Module-qualified names (`Swift.fatalError`, `Foundation.Date()`) are checked like bare ones.

## R10. Tests are fast, hermetic and at the right level

- **Rules without I/O.** Domain rules and use cases are tested without I/O, using the in-memory adapters from `…TestSupport` targets.
- **Contract tests.** Every adapter passes the contract tests of its port. All PDF renderers run the same contract suite, on their real platform.
- **Golden tests.** Rendering compares a fixture document against a **committed golden HTML file**. Changing that file is reviewed like code.
- **Mapper completeness.** A Mirror-based test proves that every populated `CV` field reaches the `CVDocument`.
- **Hermetic.** Tests use temporary directories and injected time and identifiers. They never touch the user's home, the real Application Support or `Bundle.main`.
- **Doubles and waits.** Test doubles use `Mutex`, not `@unchecked Sendable`. Waits are bounded and record an issue when they time out.
- **Bug fixes start with a failing test.** For key tests, swapping the old implementation back in must make them fail. This was done for the escaping, save-serialisation and golden tests.

**Enforced by:** CI (tests) and review.

## R11. Platform code lives only in adapters

`#if os(...)`, `#if canImport(...)`, `#if targetEnvironment(...)`, `#if arch(...)`, `#available` and `@available` appear only in:

- adapter targets (the renderers, the WebKit support, the PDFKit inspector, the AI adapter, the file store's lock);
- `PrestoCVComposition`, which picks the platform renderer;
- the app's `App/` folder (scenes and commands) and `Platform/` folder;
- test targets.

Domain, application, integration, presentation and workflow-port targets contain none.

A platform-only target wraps **every file** entirely in its platform condition. Without that, `swift build` of the whole package fails on Linux ([ADR 0003](adr/0003-one-pdf-renderer-per-platform.md#validation)). If shared code needs a platform check, a port is missing.

**Enforced by:** checker (detector `platformCondition`, which visits every `#if` branch, including those inactive on the host), and the Linux CI job.

## R12. Persisted data has an explicit, versioned schema

([ADR 0009](adr/0009-persisted-schema-v1.md))

- **DTO, not the domain.** What is written to disk is a DTO, separate from the domain type. Its envelope is frozen: `schemaVersion` is a top-level integer in every future version.
- **Strict decoding.** Required fields are required. The revision is bounded. Periods pass `Period.make`. Text and list sizes are capped.
- **Every failure has its own outcome:**
  - a file from a newer schema is left untouched and reported (`upgradeRequired`);
  - an I/O failure or a symbolic link is left untouched and reported (`unreadable`);
  - an oversized file is reported without being read (`tooLarge`);
  - only a decoding failure of a supported version is corrupt. It is moved to `Quarantine/`, reported with its reason, and can be restored;
  - a failed quarantine is reported, and the listing continues.
- **Writes.**
  - Writes are atomic, with `complete` file protection on Apple platforms.
  - **Nothing is written that could not be read back.** Before replacing a file, the repository encodes it, checks the size cap, and decodes it through the same strict path as a read. A failure is a typed `wouldNotReadBack` error, and the previous version stays.
  - Timestamps are stored with whole-second precision.
  - Create, update and delete are conditional on the revision, under an exclusive lock on the store (`flock`), so no update is lost across repository instances or processes.
  - Timestamps are assigned by the repository through the injected `TimeSource`. Listing is ordered by last change.
- **Erasure.** Erasing a CV removes every copy: the stored file whatever its schema, and the quarantined copies. Quarantine is purged after a retention period.
- **Migrations.** Schema changes after release ship with a migration and a test for it. Before the first release there is no legacy format to support.

**Enforced by:** test (the repository contract suite, and the file-store tests for every outcome above) and review.

## R13. Localisation happens at the edges

- **Only two places produce user-facing text:**
  - the views of the app target (UI strings);
  - rendering, for document headings in the **document's** language.
- **Every other target returns codes, values, typed errors and status enums.** For example, `SaveStatus.conflict`. A duplicated CV's title is composed by presentation, which knows the language. This also keeps those targets building on Linux, where `String(localized:)` does not exist.
- **Packages that render text own their translations.** They are JSON resource files, one per language, plus an index, loaded through `Bundle.module`. A test fails if any language lacks a key or has an empty value.
- **Language lookup uses BCP 47:** the full tag, then the full primary language subtag. An unsupported language is a typed error, never a silent fallback to English.
- **The app catalog** marks an entry translated only when it is.

**Enforced by:** checker (detector `localization` outside the app target) and test (heading tables complete; unsupported languages rejected).

## R14. No dead code, no demos in libraries, no test doubles in production

- Library targets contain only code reachable from their public API or used by it.
- Demo and example executables live in a separate package that depends on the library.
- Mocks, fakes, stubs and fixtures live in `…TestSupport` targets that production targets never depend on.
- A production type that is not implemented yet throws a typed "unavailable" error. It never returns an empty or fake result.
- Logging goes through an injected logger. There is no `print`.

**Why.** About 45% of `CVPDFExporter` is unreachable from the app, `MockExportRepository` is the production export repository, and a fake "John Doe" document is returned on bad input.

**Enforced by:** checker (detectors `testDouble` for `Mock…`, `Fake…`, `Stub…`, `Test…`, `Spy…`, `Dummy…` declared or referenced in production, and `printing`) and review.
