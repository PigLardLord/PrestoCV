# 0039. Keep long work off the main actor

- **Status:** Proposed
- **Date:** 2026-11-23
- **Related:** [ADR 0006](0006-enforce-architecture-mechanically.md), [R5](../rules.md#r5-views-render-view-models-present-neither-decides), [R9](../rules.md#r9-swift-6-complete-concurrency-checking-no-escape-hatches), R19 (added with this decision), issue #333

## Context

- **The released app froze while it read a pasted CV.** In 1.0 the import's view model read the text on the main actor (#333). A text inside the import's work budget can take up to about 3 s in a debug build, and the app does not respond meanwhile. The new app reads it off the main actor, but only because of how it is written today: nothing requires it.
- **What keeps work off the main actor today is a default.** A `nonisolated` `async` function runs on the shared pool of threads, not on its caller's actor, because no target turns on `NonisolatedNonsendingByDefault`. Swift 6.2 added that setting ([SE-0461](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0461-async-function-isolation.md)); Xcode turns it on in new projects ("Approachable Concurrency"), and a later language mode may make it the default. With it on, the same function runs on the caller's actor: called from a view model, on the main actor. Swift 6.2 also added `@concurrent`, which says in the code that a function leaves its caller's actor whatever the setting. It compiles with the pinned Swift 6.4.2 in a package whose tools version is 6.1, and an `@concurrent` function can implement a plain `async` requirement of a protocol (checked on Linux, 2026-11-23).
- **Two other ways keep long work on the main actor without any warning:**
  - a synchronous call from main-actor code, such as a view model, to a synchronous function that does long work;
  - a `Task { … }` started in main-actor code, which inherits the main actor: synchronous long work inside it still blocks the interface.
- **Swift 6's complete checking (R9) does not catch any of them.** They are correct Swift: the compiler checks data races, not time.
- **The maintainer's direction (2026-11-23):** a new rule; check where long work can block the interface, and move it off the main actor.
- **Today's cases:** see [the audit of 2026-11-23](#todays-cases) below.

## Decision

1. **Long work never runs on the main actor.** Long work is work whose time grows with the person's data or waits on the outside world:
   - reading or writing files, including copying a file received from Files or another app;
   - reading an imported text or PDF;
   - rendering, printing or reading a PDF;
   - encoding or decoding the stored CVs;
   - detecting a language;
   - the on-device model, the network, and image work;
   - sorting or searching that grows with the data.
2. **Main-actor code starts long work only by awaiting an `async` port, in a task the view model can cancel.** Main-actor code means the views, the view models and the main-actor parts of the composition root. It publishes the result back on the main actor (R5).
3. **Every function requirement of a workflow port is `async`.** The workflow ports are the boundary that main-actor code calls through. A synchronous requirement is allowed only when it is quick: it builds a value in memory, does no I/O, and its time does not grow with the person's data. Each one is listed by name in the checker's `rules.json` under `quickRequirements`, with that reason.
4. **The code that implements the workflow ports leaves the caller's actor explicitly.** In the integration target and the adapters that implement a workflow port, every `async` function that no actor isolates is marked `@concurrent`. Turning on `NonisolatedNonsendingByDefault` later then moves nothing onto the main actor.
5. **Main-actor targets call no known blocking API outside a `@concurrent` function or an actor.** The presentation target, the composition root and the app's targets call none of the APIs listed in `rules.json` under `longWorkCalls`:
   - Foundation's synchronous file reads and writes, and `FileManager`'s changes to files and folders;
   - the JSON and property-list coders;
   - opening a PDF document;
   - NaturalLanguage;
   - sleeping.

   The core's synchronous entry points need no list: these targets reach the core only through the workflow ports, which point 3 makes `async`, except the composition root, which builds the core's objects and calls none of them.
6. **Work that an Apple framework allows only on the main thread** (WebKit's web views, UIKit's printing) stays on the main actor in steps that await between them. Each case is an exception in `rules.json` that cites this ADR. Its cost on the main actor is measured.
7. **A test shows that each workflow's long part runs off the main thread.** The test calls the workflow from the main actor, and a test double of the long step records that it did not run on the main thread.

## Consequences

- **The checker refuses the three shapes mechanically:**
  - a synchronous requirement of a workflow port that is not listed (`synchronousPortRequirement`);
  - an `async` function without `@concurrent` in a target that implements the ports (`concurrentByDefault`);
  - a listed blocking call in main-actor targets, outside a `@concurrent` function or an actor (`mainActorLongWork`).

  Today's violations enter the baseline, and the fixes shrink it.
- **Review still catches what no list names:** a new kind of long work, and the test of point 7.
- **`@concurrent` changes nothing at run time today.** Without `NonisolatedNonsendingByDefault`, a nonisolated `async` function already leaves its caller's actor, so marking it adds no new requirement for `Sendable` values and no new hop. What it adds is a guarantee that survives the setting.
- **A new synchronous port requirement needs a written reason** in `rules.json`. This costs one line, and makes a reviewer ask whether the work is quick.
- **The lists can fall behind the code.** A blocking API that is missing from `longWorkCalls` passes the checker. Review and the tests of point 7 are the second line.

## Alternatives considered

- **Forbid `NonisolatedNonsendingByDefault` in the manifests and the Xcode project instead of requiring `@concurrent`.** It is simpler: one manifest detector. It lost because it blocks the setting that Swift is moving towards, and it says nothing in the code where the work leaves the main actor.
- **A watchdog of the main thread in the UI tests, which fails a test when the interface stalls.** It measures the real thing, but on time: on a loaded Mac (the gates' load reached 494 on 2026-11-22) it would fail with no defect in the code, and a red gate with no defect is what the rules forbid. The hang reports that the system collects on devices (MetricKit) are a better source; reading them into the trace of a test build is a possible follow-up.
- **Review only.** #333 shows what review alone gives: the case was found after release.

## Today's cases

An audit of `main` (5204fb86) and the open pull requests on 2026-11-23 found:

- **Long work on the main actor today:**
  - four synchronous requirements of the workflow ports that do I/O or NaturalLanguage: `ImportFileReading.receive(_:)` and `release(_:)` (system calls on a file from Files or another app, which can wait on its provider), `ExportFileSharing.remove(_:)` (deletes the shared PDF, also from a `deinit`), and `CVLanguageDetecting.language(of:among:)` (loads the language model on its first call). The view models call them on the main actor;
  - the launch: the composition root creates the app's folders, reads and decodes the heading tables and deletes the export's leftovers on the main actor;
  - the PDF check after the print (`CGPDFDocument`), which needs no main thread, runs inside the main-actor print engine.
- **Main-actor work that stays:** WebKit's page load and UIKit's print layout and drawing in the print engine (point 6).
- **Off the main actor only by today's default:** every workflow and adapter `async` function, among them the import of a pasted text (#333) and of a PDF, the read of a received file, the export's write and render, and the launch's design sync and legacy import. None is marked `@concurrent`.
- **Quick synchronous requirements**, listed in `quickRequirements`: `CVBrowsing.startFromSample(_:)` and `CVEditing.new()` (build a CV in memory), `CVEditing.autosaveWriter(startingFrom:)` (makes an actor, no I/O), and `LookOptionsProviding.options()` (returns a list built once).

Today's violations enter the baseline with this decision; the fixes that move them off the main actor shrink it.
