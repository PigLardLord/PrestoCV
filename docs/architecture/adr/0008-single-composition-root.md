# 0008. A single composition root in the app

- **Status:** Accepted
- **Date:** 2026-09-28
- **Related:** R4, R9, [ADR 0010](0010-ui-free-presentation-package.md), issues #1, #14, #22, #49

## Context

Today objects are built in four places:
- `PrestoCVApp` with Core's `DependencyContainer`;
- `ViewModelFactory`, which bypasses the container for templates and AI;
- `AppRootView`, a View that builds view models and bootstraps templates;
- `CVExportSheetView.init`, which, through default arguments, builds a second container (`PDFExportDependencyContainer`) every time the sheet opens.

The consequences:
- The template subsystem exists three times over the same files, and installation and registration are never connected (#1).
- A mock repository is the production export repository.
- The renderer is created through `MainActor.assumeIsolated`.
- The editor's view model can be recreated mid-edit, because it is built inside `navigationDestination` and held as `@ObservedObject`.
- Two packages declare a public `DependencyContainerProtocol`, and nothing uses either one as a protocol.

## Decision

- `PrestoCVComposition` is the only code that creates infrastructure. It owns:
  - `AppPaths`, computed once under Application Support, in one place;
  - one `FileCVRepository`, one `FileDesignStore` and one bundled-design source per process;
  - the platform renderer, created on the main actor;
  - the AI adapter and its availability port;
  - `Clock`, `IDGenerator` and the logger;
  - a `ScreenFactory` that creates each screen's view model with its ports.
- Design bootstrap, meaning the sync of bundled designs, is started by the composition root. It exposes a ready or failed state, instead of a View's `.task`.
- Libraries contain no containers, service locators, factories that build their own dependencies, or `init()` / default arguments that create infrastructure. `DependencyContainer`, `PDFExportDependencyContainer` and both `DependencyContainerProtocol`s are deleted.
- Each view model is created once per screen and owned by its view (see [ADR 0010](0010-ui-free-presentation-package.md)). A failure while building dependencies becomes an error state, not a `fatalError` or a `try?`.
- **Created once.** The `@main` App type creates the composition once, as a `static let`. That is the only process-wide instance, and nothing in a library can create a second one.
- **Compiled once.** The web-view rule list is compiled once, here, and injected into every renderer and preview.
- **UI tests and previews** use the production `FileCVRepository` on a temporary directory seeded from fixture JSON, selected by a launch argument. No production target depends on a test-support target.

## Consequences

- There is one place to read to understand what runs in production.
- Lifetimes are explicit, and stateful resources are single by construction, without `static let shared`.
- Tests assemble only what they need from the TestSupport targets.

## Validation

The validation prototype, commit `90533fb` of its own repository (`PigLardLord/PrestoCV-adr-prototype`, #65) (Swift 6.3.3, Linux), not yet in this repository; it is committed under `Prototypes/ADRValidation/` once it passes review.

**Passed**
- A single `AppComposition` builds the file repository and the platform renderer, which it selects through conditional target dependencies. The package builds on Linux, where the composition is compiled out.
- **The checker catches construction outside the composition root:**
  - `static let shared` (detector `singleton`);
  - `FileCVRepository(...)` or `FileManager.default` in presentation (detector `infrastructureConstruction`).
- **Two repository instances** on one store lose no update, because of the store lock. The composition root still keeps one instance per process ([ADR 0009](0009-persisted-schema-v1.md)).

**Found, and now part of this decision**
- Selecting the renderer requires `#if os(...)` in `PrestoCVComposition`. R11 allows it there.
- `AppComposition` has a public initialiser, because the app target is another module. "Exactly once" is guaranteed by the App type's `static let`, and review checks it.

## Alternatives considered

- **A DI framework**, such as Factory or swift-dependencies. Rejected for now: hand-written composition is small at this size, has no extra dependency, and is checked by the compiler. It can be reconsidered if the composition root grows too large.
- **Keep one container per package.** Rejected: this is the current state, and it caused the duplication.
