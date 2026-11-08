# Architecture rules

These rules are strict on purpose. A change that breaks one does not merge. There are two ways to live with a violation, and both are explicit ([ADR 0006](adr/0006-enforce-architecture-mechanically.md)):

- **Baseline:** temporary. An existing violation is listed in the checker's baseline, which may only shrink.
- **Exception:** permanent. It is an entry in the checker's `rules.json`, and it cites an ADR that explains why. The checker refuses an exception whose ADR does not exist.

Each rule says what is required, why, and what enforces it:

- **compiler**: the SwiftPM target graph, `internal import`, or the Swift 6 language mode rejects the violation.
- **checker**: `Tools/ArchitectureCheck` fails. It parses every file with SwiftSyntax and runs named detectors; the detectors are listed with each rule.
- **test**: a required test fails.
- **review**: nothing automatic can catch it. Kept to a minimum, and marked as such.

The checker applies to **production targets**: domain, application, integration, presentation and adapter targets, and the composition root. Test, test-support and tool targets get the import allow-lists only, plus R16 where a test plan runs them. Legacy targets are exempt until deleted ([ADR 0012](adr/0012-legacy-targets-during-migration.md)), except from R15 and R16, and, for the legacy app and `PrestoCVCore`, from R5 and R17 ([ADR 0025](adr/0025-hold-the-legacy-app-to-the-separation-rules.md)).

---

## R1. Packages are isolated; contexts depend only along documented edges

- **Packages are isolated.** `PrestoCVCore`, `CVPDFExporter` and `CVGeneratorAI` never import one another. Translation between them happens only in `PrestoCVIntegration`. Each may import `DiagnosticLogging`, a leaf package with no product types, and only its port target ([ADR 0030](adr/0030-log-through-one-interface-that-carries-no-cv-content.md)). `PrestoCVCore` and `CVGeneratorAI` may also import the port target of `DiagnosticTrace`, the trace of a test build; only the composition root imports its adapters ([ADR 0032](adr/0032-record-each-step-of-the-ai-draft-and-the-import-in-test-builds.md)).
- **Inside a package, contexts depend only along the edges listed in [modules.md](modules.md).** There are two such edges today, and each goes one way:
  - in `CVPDFExporter`, Document Rendering is downstream of Design Catalog (`CVRendering` imports `CVDesignCatalog`);
  - in `PrestoCVCore`, CV Import is downstream of CV Authoring (`PrestoCVImporting` imports `PrestoCVDomain`), so that it reads the CV's value objects and period rule instead of copying them ([ADR 0027](adr/0027-import-a-cv-from-its-text-with-rules.md)).

  The reverse of either is forbidden.
- **Any other edge** between contexts needs an ADR and an update to [modules.md](modules.md).
- **`@_exported import` is banned.** It would re-export a module to every importer.

**Why.** Today the exporter imports PrestoCVCore for a single adapter, the AI package defines a parallel CV model that a view model translates, and "template" means several different things across packages.

**Enforced by:**
- **compiler:** the target dependencies.
- **checker:** a per-target import allow-list, and the `exportedImport` detector. SwiftPM lets a target import its dependencies' dependencies, so declared dependencies are not enough.
- **checker (`--packages`):** every dependency declared in a `Package.swift` must be an allowed import.

## R2. Pure layers read no ambient state

Domain, application, integration, presentation and workflow-port targets must not use:

- `Bundle`, `FileManager`, `UserDefaults`, `ProcessInfo`, `NotificationCenter`. `Bundle.module`, a package's own resources, is no exception: [R18](#r18-pure-targets-stay-portable-to-android) refuses it, so that the core builds for Android;
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

## R4. One composition root

Only `PrestoCVComposition` creates infrastructure: repositories, stores, renderers, the compiled web-view rule list, the AI adapter, file locations, time sources, identifier generators and loggers.

- The `@main` App type creates the composition **once**, as a `static let`. That is the only process-wide instance.
- Libraries do not provide `init()`s or default arguments that create infrastructure. [R17](#r17-dependencies-come-in-through-the-initialiser) extends this to every default argument of production code.
- Libraries contain no containers, service locators or `static let shared` singletons.
- Each stateful resource (the design store, the CV store) exists once per process. Across processes, the file store serialises writers with a lock ([ADR 0009](adr/0009-persisted-schema-v1.md)).

**Why.** Today objects are built in four places, the template subsystem exists three times over the same files, and the export sheet builds its own container every time it opens. Issue #1 is a direct consequence.

**Enforced by:** checker (detectors `singleton`, and `infrastructureConstruction` for the adapter types listed in `rules.json` and for `FileManager.default`, `Bundle.main`, `UserDefaults.standard`) and review.

## R5. Views render; view models present; neither decides

- **Views** (Xcode app target) render presentation state and turn status enums into localised text. They forward user intents to the view model, and never construct view models or hold services. A view is given its view model, made by the composition root; only a preview, in `#if DEBUG`, makes one, with fakes.
- **View models** (`PrestoCVPresentation`) hold presentation state and call workflow ports. Rules:
  - They depend on `PrestoCVWorkflowPorts`, never on `PrestoCVIntegration`.
  - They import `PrestoCVDomain` and `PrestoCVApplication` with `internal import`, so no domain type can appear in their public API.
  - They import no UI framework.
- **Business rules** live in the domain or application layer of their context.

**Why.** The rule for "a CV can be saved" lived in `CVEditorViewModel`, the export-enabled rule in `CVExportSheetView`, the AI-to-CV mapping in `AIGenerationViewModel`, and `AppRootView` was the composition root (#251, #256).

**Enforced by:**
- **compiler:** `internal import`. A public property of type `CV` fails with "property cannot be declared public because its type uses an internal type", as verified.
- **compiler:** target dependencies.
- **checker:** import allow-lists, and the `importAccess` constraint. In `PrestoCVPresentation`, `PrestoCVDomain` and `PrestoCVApplication` must be imported `internal` or narrower. A plain `import` is public in Swift 6, so it fails as well.
- **checker:** the `viewDependency` detector. A type that conforms to `View`, or an extension of one anywhere in its target, references no type whose name ends with one of `serviceSuffixes` in `rules.json` (use cases, repositories, services, containers; another view of the target is not one), and constructs no view model. A view model is constructed by the name of its type, qualified or not (`PrestoCVPresentation.ListViewModel(…)`), or by a contextual `.init(…)` where the syntax shows a view model is expected: the type of a binding, of the property an assignment sets (through `StateObject(wrappedValue:)` and the other property wrappers), of a parameter of a type of the target (overloads are told apart by the labels of the call and of the `.init(…)`), of a `viewModel:` argument, or of a return value, a closure's included. A local or a parameter shadows a property of the same name, unless `self.` names the property. Code in an `#if DEBUG` branch is exempt.
  - **Known limits.** The detector reads syntax only. It does not see a type that inference carries across files beyond what the pre-pass indexes (the stored properties and initialisers of the target's own types), a view model made through a generic factory or an unconstrained `some`/`any` value, or code that a macro writes. When overloads cannot be told apart by labels, it assumes the view model. Review checks R5 in these cases; what a later check finds beyond these limits is recorded, not chased.
- **checker:** the `viewModelImport` detector. A file that declares or extends a type named `…ViewModel` imports no SwiftUI, UIKit, AppKit or WatchKit, in any form.
- The legacy app and `PrestoCVCore` have R5 too ([ADR 0025](adr/0025-hold-the-legacy-app-to-the-separation-rules.md)).
- **review:** whether a view contains a business rule.

## R6. The domain is rich and keeps its invariants

- **Behaviour, not fields.** Aggregates and entities expose behaviour, not `public var` fields. State changes go through methods.
- **Repository-owned state.** The revision and the timestamps are assigned only by repositories (`package` access).
- **Value objects validate on creation.** `SkillLevel` is bounded. `PartialDate` has year or month precision, and only a partial order. `EmailAddress` and `WebLink` are parsed. Identifiers are typed.
- **A rule exists once.** Periods are built only by `Period.make(start:end:current:)`, which both persistence and the AI mapper use. "Has enough content to be saved" is `SaveRule`, which `CV.canBeSaved` and the legacy app's editor both read. The text of a CV is cleaned by `TextRules` and bounded by `CVLimits`, in the one `CV.saveCheck()`. A second copy anywhere is a defect.
- **Two separate validity rules, by design.** "Can be saved" is Authoring's rule. "Can be rendered" is the rendering policy of the published `CVDocument`. A test asserts that every saveable CV maps to a renderable document.

**Why.** Today there are four definitions of "valid CV", three skill scales, three language-level parsers and four period formats.

**Enforced by:** test (each invariant, and the saveable-implies-renderable property) and review.

## R7. Errors are typed per context and translated at the boundary

- **Each context has its own error type.** Errors carry codes and file names, never paths or free-form strings.
- **A failed write keeps its cause,** as a domain and a code (`FailureCause`), so that a failed test and a direct caller of the repository can name it. It applies to the failures a repository maps to `writeFailed`; the other classified outcomes (a read, a lock, a listing, a quarantine) are codes and keep none. The use cases translate it to `AuthoringError.unavailable` and the cause stops there, until a diagnostic boundary records it. The text the user sees does not depend on it.
- **`CancellationError` is always passed through unchanged.**
- **Errors are translated once, where they cross a boundary.** For example, `SaveCV` turns repository errors into `AuthoringError`. Presentation never matches the shape of a port's errors.
- **Nothing swallows an error.** There is no `try?` and no empty `catch` in production code. A tolerated failure is mapped explicitly to a typed outcome with `do`/`catch`.
- **Only a store that does not exist yet is empty.** A store that cannot be read is an error.

**Why.** Today storage failures read as "no CVs" and send users back to onboarding, corrupt files vanish silently, and the renderer turns cancellation into `renderingFailed(String)`.

**Enforced by:** checker (detector `swallowedError`) and review.

## R8. Untrusted input enters through one validating boundary

Untrusted input is: design packages, AI output, persisted files, imported documents (pasted text, PDFs) and the text read from them, and on a backend every request. Each kind enters through one anti-corruption layer that validates it into domain types or rejects it.

- **Design packages** ([ADR 0011](adr/0011-typed-html-builder.md)):
  - validated on the raw bytes: size cap first, then strict decoding (unknown keys and any `htmlContent` key are rejected), identifier `[a-z0-9-]{1,64}`, the supported markup contract version, and a PNG preview within size;
  - **design CSS is parsed and allow-listed, never sanitised.** A CSS tokenizer accepts only the selectors of the [markup contract](../../CVPDFExporter/Docs/markup-contract.md) and an allow-list of properties with bounded values. It then re-serialises the tokens, so the CSS emitted is exactly the CSS validated;
  - rejected outright: `<`, CSS escapes, comments inside tokens, at-rules other than `@media print|screen|all`, pseudo-elements, `:has()` and other functional pseudo-classes, ids, custom properties, `!important`, every resource-bearing function;
  - **not in the allow-list**, so it cannot hide, move, reorder or inject content: `position`, `transform`, `zoom`, `filter`, `mask`, `clip`, `overflow`, `visibility`, `opacity`, `content`, `list-style`, `quotes`, counters, `direction`, `order`;
  - **colours** only through the palette variables. Text can only use `--color-text` or `--color-primary`, and a palette exists only if both have a contrast of at least 4.5:1 on the background, because a design can use either for small text;
  - **fonts** only through `--font-body` and `--font-heading`, from a closed set of system families. Embedding fonts needs its own ADR, with native registration.
- **User values** are escaped per Unicode scalar and never re-parsed.
  - Tag and attribute names are closed enums.
  - The document language must look like a BCP 47 tag; otherwise it becomes `und`.
  - A link is kept only as a parsed `WebLink`, in its parsed form: an allow-listed scheme; for http(s) an ASCII host, no credentials and default ports; no control or format characters; at most 2048 bytes.
- **The web view** has JavaScript off for content and a non-persistent store. Network is blocked by a compiled content rule list: one block rule per network scheme, plus a block on every subresource type. The rule list is compiled once, in the composition root; if it cannot be installed, rendering fails. The view accepts only the initial load, and cancels any later navigation.
- **Completeness.** Every export is checked against its own document. Every text node the builder produced (fields, headings, dates, levels) needs **its own span of the PDF text**, ignoring case and spacing, that no other node uses; longer nodes are placed first. So removing one of two identical entries is detected, so is removing a value that also appears inside another one (a skill named in the summary), and so is a value that only appears across the boundary of two others ("Greg" + "Officer" contains "go"). Link destinations are printed as text ([markup contract](../../CVPDFExporter/Docs/markup-contract.md)), so losing one is detected too, even when the clickable annotation is not part of the PDF. A shortfall fails the export.
- **Installing a design.** A design is stored only after it has been validated and has rendered a fixture document completely. The fixture exercises every section; a truncated render is a failure. The catalog owns the rendering-gate port, and `CVRendering` implements it. The renderer contract runs the same check.
- **Native evidence.** The native renderers must also pass a geometric check, read from the real PDF with PDFKit: each text line inside its page, and at least 6 pt high (`GeometricCompleteness`). The design install gate, the native renderer tests and every export that is not truncated run it ([ADR 0003](adr/0003-one-pdf-renderer-per-platform.md)).
- **Imported documents** ([ADR 0027](adr/0027-import-a-cv-from-its-text-with-rules.md)) enter through `ImportCV`. A PDF's bytes and pages are bounded before any text is read, the characters of a pasted or extracted text before it is analysed, and an empty, encrypted or unreadable document, or one without text, is a typed error. The values it yields are quotes of the text, checked against their spans, and e-mail addresses, phone numbers and links are kept only as the domain's value objects.
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
  - Create, update and delete are conditional on the revision, under an exclusive lock on the store (`flock`), so no update is lost across repository instances or processes. The wait for the lock suspends and is bounded: a lock held elsewhere until the deadline is `storeUnavailable(.lockTimeout)` (ADR 0009).
  - Timestamps are assigned by the repository through the injected `TimeSource`. Listing is ordered by last change.
- **Erasure.** Erasing a CV removes every copy: the stored file whatever its schema, and the quarantined copies. Quarantine is purged after a retention period. Erasing everything also reaches the quarantine, the staged copies, the import ledger and the legacy sources not yet removed, and an import that began before it stores nothing after it; it covers the CV data the app stores today, and a new kind of stored data extends it in the change that adds the data.
- **Migrations.** Schema changes after release ship with a migration and a test for it. Before the first release there is no legacy format to support.

**Enforced by:** test (the repository contract suite, and the file-store tests for every outcome above) and review.

## R13. Localisation happens at the edges

- **Only two places produce user-facing text:**
  - the views of the app target (UI strings);
  - rendering, for document headings in the **document's** language.
- **Every other target returns codes, values, typed errors and status enums.** For example, `SaveStatus.conflict`. A duplicated CV's title is composed by presentation, which knows the language. This also keeps those targets building on Linux, where `String(localized:)` does not exist.
- **Packages that render text own their translations.** They are JSON files, one per language, plus an index. An adapter target of the package ships them as resources and reads them through `Bundle.module` (`CVBundledHeadings`); the rendering receives them through a port, as bytes, and reads no bundle itself ([ADR 0026](adr/0026-keep-the-core-portable-to-android.md)). A test fails if any language lacks a key or has an empty value.
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

## R15. Resource bundles have a layout every platform can sign

A target's resources reach its bundle in one of two ways:

- `.copy` keeps a directory whole, under its last path component, where the bundle keeps its resources: at its root on iOS, in `Contents/Resources` on macOS;
- `.process` flattens a directory's files to the root, so the directory's own name never reaches the bundle.

A copied directory must not take a name of the bundle's own structure: `Contents`, `Resources`, `MacOS` or `_CodeSignature`, in any case. Copy the directory that holds the files (`.copy("Headings")`), not one that only wraps it.

- Legacy targets follow this rule too: their bundles are signed in the same build as the others.
- The path of a copied resource is a string literal without interpolation, so the checker can read its value.

**Why.** An iOS bundle is shallow: its resources sit next to `Info.plist`. A `Resources` or `Contents` directory at its root is the layout of a macOS bundle, and `codesign` rejects the bundle as "bundle format unrecognized, invalid, or unsuitable". A `_CodeSignature` directory at its root is replaced by the signature, and the files in it are lost. `CVRendering` copied a `Resources` directory, and every Xcode Cloud test build failed (#240). No package test showed it: on macOS, SwiftPM makes deep bundles, with the resources under `Contents/Resources`, where a copied `Resources` directory is harmless, and on Linux nothing is signed.

**Enforced by:** checker (detector `bundleLayout` in manifests, in every `#if` branch, legacy declarations included).

## R16. Tests that a test plan runs read only bundles

A test target that a test plan runs, on a simulator or a device, reads files only from bundles. It never locates the source tree with `#filePath`, `#file` or a path built from them.

- **Resources the app ships**, such as the example CVs, are read from the app bundle the tests run in.
- **A package's test resources** are declared in its manifest and read through `Bundle.module`. The markup contract page is one: `CVDesignCatalogTests` copies it.
- **A document that an app test compares with the app**, such as `docs/design/app-icon.md`, is copied into the test bundle by the project.
- **Checks of source text** are tests of the `Tools/SourceChecks` package ([modules.md](modules.md#tools)). `swift test` runs them where the repository is: on the Linux CI job, on the Mac mini's pull request check and on the Xcode Cloud build host. They cover the string catalog, the rules the app's views follow, how the tests render views off screen, release hygiene, the deployment targets and the documents. A check that also needs the app's types or UIKit stays an app test, fed from a bundle.
- `#filePath` and `#file` may still be the default value of a `StaticString` parameter, while the function only forwards it, unchanged, as the `file:` argument of a call. That is how XCTest reports where an assertion failed. Any other use of the parameter is refused: `String(describing:)`, an interpolation, `.description`, `withUTF8Buffer` or a copy into a variable can turn it into a path of the checkout.
- A test that writes into the checkout on purpose, behind an environment variable that only a developer sets, is an exception in `rules.json`. Two exist: the golden file's update ([ADR 0011](adr/0011-typed-html-builder.md)) and the thumbnails of version 1's bundled designs ([ADR 0022](adr/0022-ship-legacy-app-as-v1.md)).

Legacy test targets follow this rule too, since the same test plan runs them.

**Why.** Xcode Cloud builds for testing on one machine, then runs the tests on others that have only the built products, not the repository ([ADR 0024](adr/0024-run-apple-ci-and-releases-on-xcode-cloud.md)). There, a test that finds a file through `#filePath` finds nothing, and 48 tests of the `CI` plan failed on each device (#246). They had passed only because the tests ran next to the sources. A scan of a folder that does not exist finds nothing wrong, so two more of them passed without checking anything.

**Enforced by:**
- **checker:** the `sourceTreePath` detector, in every target whose rules list R16, legacy targets included.
- **checker:** every `.xctestplan` in the repository is read. A target that a plan runs must be in `rules.json` and must have R16.
- **CI:** the Test action of Xcode Cloud's Release workflow, which runs the tests without the repository.

## R17. Dependencies come in through the initialiser

Every dependency of a type is a parameter of its initialiser, or of the function that needs it, and its caller passes it: a service, a repository, a store, a clock, a wait, the calendar, the time zone, the locale and the languages, a bundle, a folder, the launch arguments, a function that does work. Only the composition root makes the real ones: the app's entry point, which reads the device once, and the factories and containers it hands them to.

- **No default argument makes a dependency or reads ambient state** in production code. It may not construct or name a type whose name ends with one of `dependencySuffixes` in `rules.json` or is an infrastructure type, be the default of a parameter of such a type, be a closure or a function that does work, or read the clock, the locale, the time zone, the calendar, the preferred languages, a bundle other than `Bundle.module`, the file system, user defaults, the process or localised text.
- **Values may have defaults:** a margin, a page size, the length of a debounce, an empty list, `nil`, a closure that does nothing or answers a constant (`{ _ in true }`), and an entity's new identity (`id: UUID = UUID()`).
- **Tests pass their own.** A test target may hold initialisers that give the fixed values its tests do not vary; production code may not.

**Why.** Initialisers made their own services and read the clock, the locale, the main bundle and the launch arguments when the caller passed nothing. A test that forgot an argument used the device's, so it passed on one machine and failed on another (#247), and a view could make a whole export stack without anyone seeing it (#251, #256).

**Enforced by:** checker (detector `defaultDependency`, in every production target, and in the legacy app and `PrestoCVCore`, [ADR 0025](adr/0025-hold-the-legacy-app-to-the-separation-rules.md)) and review, for a dependency that the name of its type does not show.

## R18. Pure targets stay portable to Android

([ADR 0026](adr/0026-keep-the-core-portable-to-android.md))

The pure targets, which R2 holds too (the domain, application, published-language, integration, presentation and workflow-port targets), build for Android, where the core will run under a Kotlin interface. In them:

- **No module that only Apple platforms have** is imported, in any form: SwiftUI, UIKit, AppKit, WatchKit, Combine, CryptoKit, `os` and OSLog, NaturalLanguage, FoundationModels, PDFKit, WebKit, Vision, CoreGraphics, UniformTypeIdentifiers, Darwin and the other Apple frameworks. Code that needs one belongs in an adapter, behind a port.
- **No bundle is read:** no `Bundle`, not even `Bundle.module`, and no `#bundle`. An Android app has no SwiftPM resource bundle, and the accessor SwiftPM generates there stops the process when the bundle is missing. The edge reads the resources and passes them in through a port, as `HeadingTableSource` does for the heading tables.
- **An API that needs the full Foundation warns.** The full Foundation, with ICU, weighs tens of megabytes for each ABI of an Android app; `FoundationEssentials` does not have these: `NSRegularExpression`, `NSRange`, `.regularExpression`, `folding`, `replacingOccurrences`, `trimmingCharacters`, `JSONSerialization`, `NSString`, `String(format:)`, Foundation's formatters and the localised comparisons. Whether the core gives up the full Foundation is the owner's decision, after the measurements of the spike in #267. Until then each use is listed as a warning, which never fails and never enters the baseline. Where the standard library does the same, prefer it: Swift `Regex`, `Codable`.

**Why.** The owner's direction for Android (2026-10-20, #267) keeps one core, in Swift. On that day the core cross-compiled for Android except the file stores, which imported the C library as `Glibc`, while the rendering read its headings from a bundle that an Android app does not have. Nothing kept the next Apple-only import or the next `Bundle.module` out of the core.

**Enforced by:**
- **checker:** the detectors `appleOnlyImport` and `bundleAccess`, and `fullFoundation` as a warning (`warningDetectors` in `rules.json`), in every target whose rules list R18. A module-qualified name, such as `Foundation.Bundle`, is checked like a bare one.
- **CI:** the Android job on GitHub Actions builds every target that builds on Linux for `aarch64-unknown-linux-android28`, with the Swift SDK for Android. It catches what no detector sees, such as a C library imported under one platform's name: the file stores import `Glibc`, `Darwin` or `Android`.
