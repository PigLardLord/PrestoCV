# Architecture rules

These rules are strict on purpose. A change that breaks one does not merge. There are two ways to live with a violation, and both are explicit ([ADR 0006](adr/0006-enforce-architecture-mechanically.md)):

- **Baseline:** temporary. An existing violation is listed in the checker's baseline, which may only shrink. The size, shape and comment rules (`CleanFunctions`, `CleanTypes`, `ISP`, `CleanComments`) are never baselined: the checker refuses such an entry, and a finding is fixed.
- **Exception:** permanent. It is an entry in the checker's `rules.json`, and it cites an ADR that explains why. The checker refuses an exception whose ADR does not exist.

The rules are **SOLID**, **Clean Architecture** and **Clean Code**, and five rules of this project named by topic ([ADR 0021](adr/0021-solid-and-clean-rules.md)). Every rule is cited by its name, such as `SRP` or `ValidatingBoundary`, never by a number.

Each rule says what is required, why, and what enforces it:

- **compiler**: the SwiftPM target graph, `internal import`, or the Swift 6 language mode rejects the violation.
- **checker**: `Tools/ArchitectureCheck` fails. It parses every file with SwiftSyntax and runs named detectors; the detectors are listed with each rule.
- **test**: a required test fails.
- **review**: nothing automatic can catch it. Kept to a minimum, and marked as such.

A target's list of rules in `rules.json` names the rules whose **detectors** run on it. The size, shape and comment rules (`CleanFunctions`, `CleanTypes`, `ISP`, `CleanComments`) are the exception: their detectors run on every production target by kind, listed or not, so a new target cannot forget them. The rules held by the compiler, tests or review apply to every production target, listed or not.

The checker applies to **production targets**: domain, application, integration, presentation and adapter targets, workflow ports and the composition root. Test, test-support and tool targets get the import allow-lists only, and are held to Clean Code by review. Legacy targets are exempt until deleted ([ADR 0012](adr/0012-legacy-targets-during-migration.md)).

---

## SOLID

### SRP: a type, a function and a target have one reason to change

- **A type does one job.** It holds the state of one concept and the behaviour that keeps that state valid. A type that parses, validates, formats and stores is four types.
- **A function does one thing,** at one level of abstraction. A function that reads, decides and writes is three.
- **A target owns one concern** of its context, as [modules.md](modules.md) describes it.
- **Views render; view models present; neither decides** (`HumbleViews`).

**Why.** A type with several reasons to change changes for each of them, and every change risks the others. The size thresholds of `CleanFunctions` and `CleanTypes` are where a second responsibility shows first.

**Enforced by:** checker (the thresholds of `CleanFunctions` and `CleanTypes`) and review.

### OCP: behaviour is extended by adding, not by editing what works

- **New behaviour arrives as a new type or new data:** a new adapter behind an existing port, a new design package, a new word-list file, a new case of a closed enumeration handled where the enumeration is mapped once.
- **A decision about a closed set lives in one place.** The `switch` over a closed enumeration appears once, behind a function, and the compiler checks it is exhaustive; it is not repeated across files.
- **What varies by language, design or provider is data,** loaded through one validated boundary, never code with one branch per case.

**Why.** Editing working code to add a case breaks it more often than adding a type next to it, and repeated switches drift apart.

**Enforced by:** review.

### LSP: every adapter can stand in for its port

- **Every adapter passes its port's contract.** The contract is a test suite in the port's test support, run against every adapter, the in-memory ones included. All PDF renderers run the same contract suite, on their real platform.
- **A test double keeps the contract too.** A fake that accepts what the real adapter refuses, or never fails where it can fail, makes the tests lie.
- **A subtype strengthens nothing it promised and weakens nothing it requires:** no new error a caller does not expect, no precondition the protocol does not state.

**Why.** A caller written against a port must work with whatever the composition root installs.

**Enforced by:** test (the contract suites) and review.

### ISP: ports are small and shaped for one consumer

- **A protocol declared in a production target has at most five requirements.**
- **A consumer that needs part of a port gets its own port.** A repository read by one use case and written by another can be two ports.
- **A port speaks its consumer's language** (`DIP`), so it carries no requirement its consumer does not call.

**Why.** A fat port couples every consumer to every other, and its fakes grow with it.

**Enforced by:** checker (detector `protocolSize`) and review.

### DIP: ports belong to the consumer; one composition root creates the infrastructure

**Ports.** An outbound port is declared by the layer that needs it and implemented in an adapter target that imports that layer, never the other way round. A port:

- speaks the consumer's language: it does not expose `URL`, `[String: Any]`, `WKWebView`, `Bundle` or framework types unless that is its purpose (a renderer returns `Data`);
- is `Sendable` and not constrained to `Actor` or `AnyObject`;
- is async when the work is async; there is no synchronous wrapper around async code;
- lets `CancellationError` through when the work can be cancelled. Such ports use untyped `throws`. Repository operations are short, synchronous I/O. They are not cancellable, and use typed errors.

A protocol with one implementation exists only if it is a port or has a test double in use. Speculative protocols are deleted.

**One composition root.** Only `PrestoCVComposition` creates infrastructure: repositories, stores, renderers, the compiled web-view rule list, the AI adapter, file locations, time sources, identifier generators and loggers.

- The `@main` App type creates the composition **once**, as a `static let`. That is the only process-wide instance.
- Libraries do not provide `init()`s or default arguments that create infrastructure.
- Libraries contain no containers, service locators or `static let shared` singletons.
- Each stateful resource (the design store, the CV store) exists once per process. Across processes, the file store serialises writers with a lock ([ADR 0009](adr/0009-persisted-schema-v1.md)).

**Why.** Today objects are built in four places, the template subsystem exists three times over the same files, and the export sheet builds its own container every time it opens. Issue #1 is a direct consequence.

**Enforced by:** compiler (target graph), checker (detectors `singleton`, and `infrastructureConstruction` for the adapter types listed in `rules.json` and for `FileManager.default`, `Bundle.main`, `UserDefaults.standard`) and review.

## Clean Architecture

### DependencyRule: packages are isolated; contexts depend only along documented edges

- **Packages are isolated.** `PrestoCVCore`, `CVPDFExporter` and `CVGeneratorAI` never import one another. Translation between them happens only in `PrestoCVIntegration`.
- **Inside a package, contexts depend only along the edges listed in [modules.md](modules.md).** There is exactly one such edge today: in `CVPDFExporter`, Document Rendering is downstream of Design Catalog (`CVRendering` imports `CVDesignCatalog`). The reverse is forbidden.
- **Any other edge** between contexts needs an ADR and an update to [modules.md](modules.md).
- **`@_exported import` is banned.** It would re-export a module to every importer.

**Why.** Today the exporter imports PrestoCVCore for a single adapter, the AI package defines a parallel CV model that a view model translates, and "template" means several different things across packages.

**Enforced by:**
- **compiler:** the target dependencies.
- **checker:** a per-target import allow-list, and the `exportedImport` detector. SwiftPM lets a target import its dependencies' dependencies, so declared dependencies are not enough.
- **checker (`--packages`):** every dependency declared in a `Package.swift` must be an allowed import.

### PureCore: pure layers read no ambient state

Domain, application, integration, presentation and workflow-port targets must not use:

- `Bundle` (except `Bundle.module`, a package's own resources), `FileManager`, `UserDefaults`, `ProcessInfo`, `NotificationCenter`;
- `Locale.current`, `TimeZone.current`, `Calendar.current` and their `autoupdatingCurrent` forms;
- `String(localized:)`, `NSLocalizedString`, `LocalizedStringResource`, `LocalizedStringKey`;
- `Date()`, `Date.init()`, `Date.now`, `.now` or `UUID()` / `UUID.init()` to create values. Inject a `TimeSource` or an `IDGenerator` instead;
- `print`, `debugPrint`, `dump`, `NSLog`.

**Why.** Core localises user-facing text through the host app's `Bundle.main`, which is why it does not build on Linux (#27). Adapters create a fresh `UUID()` and `Date()` on every conversion, which is why the preview cache never hits. Hidden globals make behaviour untestable and non-deterministic.

**Enforced by:** checker (detectors `wallClock`, `randomIdentity`, `ambientEnvironment`, `localization`, `printing`).

### HumbleViews: views render; view models present; neither decides

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

### RichDomain: the domain is rich and keeps its invariants

- **Behaviour, not fields.** Aggregates and entities expose behaviour, not `public var` fields. State changes go through methods.
- **Repository-owned state.** The revision and the timestamps are assigned only by repositories (`package` access).
- **Value objects validate on creation.** `SkillLevel` is bounded. `PartialDate` has year or month precision, and only a partial order. `EmailAddress` and `WebLink` are parsed. Identifiers are typed.
- **Two separate validity rules, by design.** "Can be saved" is Authoring's rule. "Can be rendered" is the rendering policy of the published `CVDocument`. A test asserts that every saveable CV maps to a renderable document.

**Why.** Today there are four definitions of "valid CV", three skill scales, three language-level parsers and four period formats.

**Enforced by:** test (each invariant, and the saveable-implies-renderable property) and review.

## Clean Code

### CleanNames: names say what a thing is, or what a function does

- **Intention-revealing and searchable.** No abbreviations except the domain's own terms, no single letters outside a short closure, no encodings or type prefixes.
- **Types and properties are nouns; functions are verbs** or, for a query without side effects, the noun of what they return.
- **One word for one concept,** the word of the [glossary](glossary.md). A concept the glossary names is called by that name in code, docs and tests.
- **A name is as long as its scope needs:** short in a three-line function, explicit in a public API.

**Why.** With functions of at most twenty lines, the names carry the design: a reader understands a function from the names of the ones it calls.

**Enforced by:** review.

### CleanFunctions: functions are small and do one thing

In production targets:

- **At most 20 lines** of code in a function's, initialiser's, accessor's or closure's body. Blank lines, comment lines and lines holding only a brace do not count; a closure or a nested function is measured on its own.
- **At most 3 parameters.** Behaviour that needs more inputs takes a value that groups them. A **data initialiser** is exempt, and [ADR 0021](adr/0021-solid-and-clean-rules.md) (c) says exactly when an initialiser is one. In short, it:
  - only stores each parameter in the stored property of the same name, or only delegates its parameters unchanged to data initialisers of the same type in the same file;
  - has no variadic parameter, and its default values are literals or constants;
  - leaves no stored property, assigned or not, starting with anything but a literal or a constant (a `lazy` one excepted);
  - does not belong to a class with an inheritance clause.

  A property with an attribute, or with accessors other than `willSet` and `didSet`, is not stored. Resolution stops at the file: an overload that another file declares is not seen, and review is the backstop for that.
- **Nesting of at most 2 levels** of `if`, `guard`, `switch`, `for`, `while`, `repeat`, `do` and closures. A `guard` that only exits is no level.
- **Cyclomatic complexity of at most 5:** one, plus one for each `if`, `guard`, `while`, `for`, `repeat`, `catch`, `&&`, `||`, `??` and ternary, and one for each condition after the first in a condition list (`if a, b`), which is an `&&` written with a comma. A `switch` counts once, whatever its cases.
- **One thing, at one level of abstraction.** A function reads like a paragraph of calls to well-named smaller ones.
- **No flag arguments.** A `Bool` parameter that selects between two behaviours is two functions.
- **The caps are not to be evaded.** A function that is cut into nested functions or closures, or whose statements are joined with `;`, only to stay under a cap is still one function with several jobs. The checker measures each nested function and closure on its own and counts a line, not a statement, so review is the backstop: every piece is a named thing with one job.
- **No hidden side effects,** and a function either answers a question or changes state, not both (command-query separation).

**Why.** Small functions with few branches can be read whole, named precisely, and tested one behaviour at a time.

**Enforced by:** checker (detectors `functionLength`, `parameterCount`, `nestingDepth`, `cyclomaticComplexity`) and review.

### CleanTypes: types and files are small and cohesive

In production targets:

- **A type's declaration, and each extension, holds at most 200 lines** of code, counted as for functions.
- **A file holds at most 300 lines** of code.
- **Cohesion.** A type's functions use its state; a function that uses none of it belongs elsewhere.
- **Data structures and objects stay apart.** A value that only carries data exposes it; an object hides its state behind behaviour (`RichDomain`).

**Why.** A long type almost always holds more than one responsibility (`SRP`).

**Enforced by:** checker (detectors `typeLength`, `fileLength`) and review.

### CleanComments: a comment explains why, never what

- **A comment explains why:** a constraint, a non-obvious decision, the source of a rule (a ticket, an ADR, cv-giovanni's file), a known gap. It never restates what the code does; a comment that does is replaced by a better name or a smaller function.
- **Public API keeps full doc comments:** what it does, its parameters, its errors, and an example where it helps.
- **No history.** A comment says what is true now, not what changed; history lives in the commits.
- **No commented-out code.**
- **A rule is cited by its name,** never by a number.

**Why.** A comment that restates the code goes stale the first time the code changes, and then it lies.

**Enforced by:** checker (detector `ruleNumberCitation`, in the comments of production sources and in the documents) and review.

### CleanErrors: errors are typed per context and translated at the boundary

- **Each context has its own error type.** Errors carry codes and file names, never paths or free-form strings.
- **`CancellationError` is always passed through unchanged.**
- **Errors are translated once, where they cross a boundary.** For example, `SaveCV` turns repository errors into `AuthoringError`. Presentation never matches the shape of a port's errors.
- **Nothing swallows an error.** There is no `try?` and no empty `catch` in production code. A tolerated failure is mapped explicitly to a typed outcome with `do`/`catch`.
- **Only a store that does not exist yet is empty.** A store that cannot be read is an error.

**Why.** Today storage failures read as "no CVs" and send users back to onboarding, corrupt files vanish silently, and the renderer turns cancellation into `renderingFailed(String)`.

**Enforced by:** checker (detector `swallowedError`) and review.

### CleanTests: tests are fast, hermetic and at the right level

- **Rules without I/O.** Domain rules and use cases are tested without I/O, using the in-memory adapters from `…TestSupport` targets.
- **Golden tests.** Rendering compares a fixture document against a **committed golden HTML file**. Changing that file is reviewed like code.
- **Mapper completeness.** A Mirror-based test proves that every populated `CV` field reaches the `CVDocument`.
- **Hermetic.** Tests use temporary directories and injected time and identifiers. They never touch the user's home, the real Application Support or `Bundle.main`.
- **Doubles and waits.** Test doubles use `Mutex`, not `@unchecked Sendable`. Waits are bounded and record an issue when they time out.
- **Bug fixes start with a failing test.** For key tests, swapping the old implementation back in must make them fail. This was done for the escaping, save-serialisation and golden tests.

Each test is **fast, independent, repeatable, self-validating and timely**, checks **one concept**, and reads as arrange, act, assert. Its name states the behaviour it holds. A test bounds its cost by counted work, never by the wall clock alone; a clock is only a backstop against a hang.

**Enforced by:** CI (tests) and review.

### NoDuplication: every piece of knowledge has one home

- **A rule exists once.** Periods are built only by `Period.make(start:end:current:)`, which both persistence and the AI mapper use. A second copy anywhere is a defect.
- **No copied code.** Two pieces of code that say the same thing become one function; two that look alike but mean different things keep different names.
- **Data before code.** A list of words, a table of conventions or a mapping lives in one data file or one `switch`, and every reader reads that one.

**Why.** Two copies of a rule drift apart, and then the code has two rules.

**Enforced by:** test (where two readers must agree, a test holds them to one table) and review.

### NoDeadCode: no dead code, no demos in libraries, no test doubles in production

- Library targets contain only code reachable from their public API or used by it.
- Demo and example executables live in a separate package that depends on the library.
- Mocks, fakes, stubs and fixtures live in `…TestSupport` targets that production targets never depend on.
- A production type that is not implemented yet throws a typed "unavailable" error. It never returns an empty or fake result.
- Logging goes through an injected logger. There is no `print`.

**Why.** About 45% of `CVPDFExporter` is unreachable from the app, `MockExportRepository` is the production export repository, and a fake "John Doe" document is returned on bad input.

**Enforced by:** checker (detectors `testDouble` for `Mock…`, `Fake…`, `Stub…`, `Test…`, `Spy…`, `Dummy…` declared or referenced in production, and `printing`) and review.

## This project's rules

These are neither SOLID nor Clean, but each serves one of them: the boundary of untrusted input and the persisted schema are Clean Architecture's boundaries, strict concurrency has the compiler prove that layers share no unguarded state, platform code in adapters is the Dependency Rule applied to platforms, and localisation at the edges keeps the core pure.

### ValidatingBoundary: untrusted input enters through one validating boundary

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
- **Persisted files**: see `PersistedSchema`.

**Why.** See issue #9 and the security review of 2026-09-27: a regex deny-list let 34 of 34 content-hiding constructs through, and could be bypassed with CSS comments and strings. On a backend, a `<style>` breakout would be server-side request forgery.

**Enforced by:** test (one per attack, listed in the Design Catalog and Rendering tests) and the type system (`ValidatedStylesheet` can only be created by the validator).

### StrictConcurrency: Swift 6, complete concurrency checking, no escape hatches

Every production target builds in the Swift 6 language mode with complete concurrency checking. **No manifest** may use `swiftLanguageMode(.v5)` or `unsafeFlags`, except for legacy targets ([ADR 0012](adr/0012-legacy-targets-during-migration.md)).

Production code does not use:
- `@unchecked Sendable` (in any spelling), `nonisolated(unsafe)`, `MainActor.assumeIsolated`;
- `DispatchSemaphore` or any other blocking wait on async work;
- `fatalError`, `precondition`, `preconditionFailure`, `try!`, `as!`, force unwraps.

Continuations resume exactly once, time out where they wait on the outside world, and support cancellation (review).

**Enforced by:** compiler, checker (detectors `escapeHatch` in sources; `swift5Mode` and `unsafeFlags` in manifests, where only the declaration of a legacy target is exempt; with `--packages`, the effective language mode of every target that is not legacy must be Swift 6) and review for continuations. Module-qualified names (`Swift.fatalError`, `Foundation.Date()`) are checked like bare ones.

### PlatformAdapters: platform code lives only in adapters

`#if os(...)`, `#if canImport(...)`, `#if targetEnvironment(...)`, `#if arch(...)`, `#available` and `@available` appear only in:

- adapter targets (the renderers, the WebKit support, the PDFKit inspector, the AI adapter, the file store's lock);
- `PrestoCVComposition`, which picks the platform renderer;
- the app's `App/` folder (scenes and commands) and `Platform/` folder;
- test targets.

Domain, application, integration, presentation and workflow-port targets contain none.

A platform-only target wraps **every file** entirely in its platform condition. Without that, `swift build` of the whole package fails on Linux ([ADR 0003](adr/0003-one-pdf-renderer-per-platform.md#validation)). If shared code needs a platform check, a port is missing.

**Enforced by:** checker (detector `platformCondition`, which visits every `#if` branch, including those inactive on the host), and the Linux CI job.

### PersistedSchema: persisted data has an explicit, versioned schema

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

### LocalisationAtEdges: localisation happens at the edges

- **Only two places produce user-facing text:**
  - the views of the app target (UI strings);
  - rendering, for document headings in the **document's** language.
- **Every other target returns codes, values, typed errors and status enums.** For example, `SaveStatus.conflict`. A duplicated CV's title is composed by presentation, which knows the language. This also keeps those targets building on Linux, where `String(localized:)` does not exist.
- **Packages that render text own their translations.** They are JSON resource files, one per language, plus an index, loaded through `Bundle.module`. A test fails if any language lacks a key or has an empty value.
- **Language lookup uses BCP 47:** the full tag, then the full primary language subtag. An unsupported language is a typed error, never a silent fallback to English.
- **The app catalog** marks an entry translated only when it is.

**Enforced by:** checker (detector `localization` outside the app target) and test (heading tables complete; unsupported languages rejected).

## Former numbers

The merged ADRs 0001 to 0012 cite the rules by the numbers they had then ([ADR 0021](adr/0021-solid-and-clean-rules.md)):

| Former | Now |
|---|---|
| R1 | `DependencyRule` |
| R2 | `PureCore` |
| R3 | `DIP` and `ISP` |
| R4 | `DIP` |
| R5 | `HumbleViews` |
| R6 | `RichDomain` and `NoDuplication` |
| R7 | `CleanErrors` |
| R8 | `ValidatingBoundary` |
| R9 | `StrictConcurrency` |
| R10 | `CleanTests` and `LSP` |
| R11 | `PlatformAdapters` |
| R12 | `PersistedSchema` |
| R13 | `LocalisationAtEdges` |
| R14 | `NoDeadCode` |

## Review checklist

Every review, dimension or final gate, answers each question with the place it found, or "none":

- **SRP:** does a type, a function or a target do more than one job?
- **OCP:** does adding a case edit working code that a new type or new data could have left alone? Is a decision about a closed set repeated?
- **LSP:** does every adapter, and every test double, pass its port's contract?
- **ISP:** does a consumer depend on requirements it never calls?
- **DIP:** does a port speak its consumer's language? Is infrastructure created anywhere but the composition root?
- **HumbleViews:** does a view decide, build a view model or a service, or hold a business rule? Does a view model import a UI framework or expose a domain type?
- **RichDomain:** is a field public and mutable, is state changed outside a method, or is a value built without validation?
- **CleanNames:** is every name intention-revealing, in the glossary's words?
- **CleanFunctions:** does a function do more than one thing, mix levels of abstraction, take a flag, or hide a side effect? Is it cut into nested functions, closures or `;`-joined statements only to stay under a cap? (Size, parameters, nesting and complexity are the checker's.)
- **CleanTypes:** does a function use none of its type's state? Does a type mix data and behaviour? (Size is the checker's.)
- **CleanComments:** does a comment restate the code, carry history, or cite a rule by number? Does public API lack a doc comment?
- **CleanErrors:** is an error swallowed, untyped, or translated more than once?
- **CleanTests:** does a test check more than one concept, depend on another test or the clock, or hide what it asserts?
- **NoDuplication:** is a rule, a list or a block of code written twice?
- **NoDeadCode:** is anything unreachable, a demo in a library, or a double in production?
- **The project's rules:** `ValidatingBoundary`, `StrictConcurrency`, `PlatformAdapters`, `PersistedSchema`, `LocalisationAtEdges`, where the change touches them.
