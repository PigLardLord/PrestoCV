# 0010. View models live in a UI-framework-free package target

- **Status:** Accepted
- **Date:** 2026-09-28
- **Related:** R5, R11, R13, [ADR 0004](0004-native-multiplatform-app.md), [ADR 0008](0008-single-composition-root.md), issues #14, #29, #48, #49

## Context

Today view models are `ObservableObject` classes inside the app target. Nothing stops them from importing SwiftUI or any package:
- `CVEditorViewModel` returns a SwiftUI `Color`.
- `AIGenerationViewModel` holds about 270 lines of cross-context mapping.
- Views contain business rules and build view models.

Several view models have no tests. They can be tested only through the app target, so only on a Mac.

On 2026-09-27 it was verified that the `Observation` module and `@Observable @MainActor` classes build and run with Swift 6.3.3 on Linux.

## Decision

- **Where view models live.** In `PrestoCVPresentation`, in the `PrestoCVApp` package.
- **What they depend on:**
  - `PrestoCVWorkflowPorts`, for the protocols of the workflows;
  - `PrestoCVDomain` and `PrestoCVApplication` through `internal import`, so the compiler forbids any domain type in their public API;
  - `Observation` and Foundation.

  They never depend on `PrestoCVIntegration` (the implementations), a UI framework, or a `CVPDFExporter` or `CVGeneratorAI` module.
- **Their shape.** View models are `@Observable` and `@MainActor`. They expose presentation state and **status enums**, such as `SaveStatus` and `ExportStatus`, and views turn these into localised text.
- **Overlapping intents on the same resource are serialised and coalesced.** A save requested while one is running becomes one more save with the latest edits. Every caller waits until its own edits have landed or failed, and edits made during a save are kept.
- **Save and export have separate statuses**, and each is reset when a new intent starts.
  - `CancellationError` returns the export status to idle. It is never a failure.
  - After a `conflict`, the view model offers `reload()` or `saveAsCopy()`; after `deletedElsewhere`, it offers `saveAsCopy()`.
- **Views own their view model** with `@State`, created from the `ScreenFactory`. The factory may be called on every view init, so view-model initialisers do no I/O; loading happens in the view's `.task`.
- **Tests run on Linux and macOS** without a simulator.

## Consequences

- R5 is enforced by the compiler plus the checker, not by review.
- Views get thinner. Any logic left in a view is visible as a smell, because it has nowhere to hide.
- Localisation keys live next to the views that use them. Presentation tests assert on message enums, not on strings.
- There is one more package in the repository.

## Validation

The validation prototype, commit `90533fb` of its own repository (`PigLardLord/PrestoCV-adr-prototype`, #65) (Swift 6.3.3, Linux), not yet in this repository; it is committed under `Prototypes/ADRValidation/` once it passes review. 15 App tests pass.

**Passed**
- **Presentation builds on Linux.** It imports only `Observation`, Foundation, `PrestoCVWorkflowPorts`, and the domain and application through `internal import`.
- **The compiler enforces R5.** Adding `public var leak: CV` to the view model fails with "property cannot be declared public because its type uses an internal type".
- **Overlapping saves.** One save is held by a gated fake while the name is edited and a second save is requested. Result: exactly one create, then one update with the latest name, and the second caller returns only after the update has landed.
  - Swapping in the original save loop fails this test with two creates. The waits are bounded, and a timeout records an issue instead of hanging.
- **A save requested as the save loop finishes** is stored before its caller returns. The loop clears itself in the same main-actor turn as its last check. A sweep of the request across the loop's end failed before the fix, and passed 20 repeated runs after it (review round 3).
- **Conflict.** A stale save gives `conflict`, and the other window's data is not overwritten. `reload()` takes the stored version; a later save succeeds.
- **Deleted elsewhere.** `deletedElsewhere`, then `saveAsCopy()`, stores the edits as a new CV.
- **Save statuses** include `tooLarge`, for a CV the store refuses to write.
- **Export statuses:**
  - export works from the unsaved snapshot;
  - truncation is reported with its page counts;
  - an unsupported language gives `unsupportedLanguage`, not English headings;
  - a PDF missing a field, or missing a date, gives `incomplete`;
  - a cancelled export returns to idle.

**Found**
- The previous save loop let a coalesced caller return before its edits were stored, and one message slot mixed save and export results (internal Swift review).
- The previous view model exposed `CV` publicly, so a view could read domain types without importing the domain.
- `String(localized:)` does not compile on Linux, which confirms that status enums are the right boundary ([R13](../rules.md#r13-localisation-happens-at-the-edges)).
- SwiftPM's incremental build twice reused a stale object when a file was restored within the same second as the previous compile. Mutation checks force a rebuild.

## Alternatives considered

- **Keep view models in the app target and rely on review.** Rejected: this is the current state.
- **The Composable Architecture or a similar framework.** Rejected for now: it would add a large dependency and a learning curve. The rules above give the separation needed with plain Swift.
