# 0025. Hold the legacy app to the separation of views, view models and rules

- **Status:** Accepted
- **Date:** 2026-10-19
- **Related:** [ADR 0006](0006-enforce-architecture-mechanically.md), [ADR 0012](0012-legacy-targets-during-migration.md), [ADR 0022](0022-ship-legacy-app-as-v1.md), [R4](../rules.md#r4-one-composition-root), [R5](../rules.md#r5-views-render-view-models-present-neither-decides), [R6](../rules.md#r6-the-domain-is-rich-and-keeps-its-invariants), R17 (added with the checker), issues #251 and #256

## Context

- **Version 1 is the legacy app** ([ADR 0022](0022-ship-legacy-app-as-v1.md)). It will be on sale for a while before the migration replaces it, so its structure matters now, not only after the migration.
- **ADR 0012 exempts it.** The legacy targets, the app `PrestoCV` and the package target `PrestoCVCore` among them, are exempt from every rule until they are deleted, except R15 and R16. The checker does not look at them, so nothing kept the separation that #254 brought about: it took the logic out of the views, but a view could still make a view model or hold a service the next day.
- **Some rules were still in view models**, where no test outside the simulator reaches them: what makes a CV worth saving, what an export needs and the page it prints on, which details a draft started from an example leaves blank, and how a stored CV is renamed or given a document language.
- **Some rules were wrong or missing.** The e-mail check took `clara.weiss@` for an address; two CVs without a name were both listed as "Untitled CV"; the PDF's file name followed the language of the app, not the CV's; and an export needed an e-mail address, which the owner decided it should not.
- **The legacy `PrestoCVCore` builds only on Apple hosts** ([ADR 0012](0012-legacy-targets-during-migration.md)), so its tests never run on Linux. `PrestoCVDomain` and `PrestoCVApplication` build and test on Linux, and the migration is meant to fill them.
- **Dependencies were hidden in default arguments.** Initialisers made their own services, or read the clock, the locale, the preferred languages, the main bundle, the file system or the launch arguments when the caller passed nothing. A test that forgot an argument used the device's, which is how a test can pass on one machine and fail on another (#247).

## Decision

**The owner decided on 2026-10-19** ("sposta le regole nel core e aggiungi il controllo. usa dependency injection più che puoi": move the rules into the core and add the check; use dependency injection as much as you can). This amends [ADR 0012](0012-legacy-targets-during-migration.md), whose text stays as it was decided.

1. **The rules move into the target modules, as pure code.**
   - Rules on values go into `PrestoCVDomain`; operations that read and write stored CVs go into `PrestoCVApplication`, behind a port the use case owns (R3). They have no side effects and no Apple-only imports, and their tests run on Linux.
   - They read plain values, never the legacy `CVModel`. The legacy app maps its CVs to those values in small adapters (`PrestoCV/Shared/CoreRules/`), which its own tests cover.
   - **A rule exists once** (R6). "Has enough content to be saved" becomes `SaveRule`, which `CV.canBeSaved` reads too; its definition is the one the app ships.
   - **A new edge:** the legacy app target may import `PrestoCVDomain` and `PrestoCVApplication`. It imports each declaration it uses by name (`import struct PrestoCVDomain.ExportPolicy`), because the legacy `PrestoCVCore` declares types with the same names, such as `DocumentLanguage` and `Skill`. Nothing in the new targets depends on a legacy target; that rule of ADR 0012 stands.
   - **Version 1's export rules** (the A4 page, its 43-point margin, the 10-page limit, and what a CV needs before it is exported) are in `PrestoCVDomain` while the app exports through the legacy exporter. When the app switches to the new export workflow (migration step 5), the rendering policy of `CVRendering` takes their place, as R6 and [modules.md](../modules.md) describe.
2. **The owner's rules join them** (UX decisions of 2026-10-19), pure and tested on Linux, and wired into the screens as they are:
   - **Field checks:** an e-mail address and a web address are what `EmailAddress` and `WebLink` accept, and a phone number has a digit. The editor checks a field when the person leaves it, not at every key.
   - **The title of a CV:** its name, otherwise the name of its person ("Lena Hartmann"), otherwise the role it is for, as an example's. "Untitled CV" is left only for a CV with none of the three, such as a blank CV with only a summary. The rows, the rename, the delete confirmation and the editor use it, and the list numbers titles that read alike. A copy is named after the title its CV is shown with, as "Lena Hartmann (Copy)": the app gives the legacy duplicate operation that name.
   - **The PDF's file name** follows the language the CV is printed in.
   - **`ExportReadiness`:** only the name is required. A missing e-mail address or phone number warns, and the export sheet says which field to fix. The legacy exporter stops refusing a document without an e-mail address: this changes a legacy target for a product decision, which ADR 0012 did not foresee.
3. **Every dependency comes in through the initialiser** (R17).
   - No default argument makes a dependency or reads ambient state, in production code. A value may still have a default, such as a page margin or the length of a debounce; so may a closure that does nothing or answers a constant.
   - The composition root makes the real ones: the app's entry point, which reads the device once into an `AppEnvironment`; the `ViewModelFactory`, which hands each view model and service its part; and the legacy `DependencyContainer`.
   - Tests give their own. The test targets hold the initialisers that give the fixed ones they do not vary.
4. **The checker holds the legacy app and the legacy `PrestoCVCore` to R5 and R17:**
   - **`viewDependency` (R5):** a type that conforms to `View`, or an extension of one anywhere in its target, references no use case, repository, service or dependency container, and constructs no view model. Code in the `#if DEBUG` branch, where previews make their view models with fakes, is exempt.
   - **`viewModelImport` (R5):** a file that declares or extends a view model imports no SwiftUI, UIKit, AppKit or WatchKit. Combine and Observation are allowed.
   - **`defaultDependency` (R17):** no default argument makes a dependency, names a service, is a closure or a function that does work, or reads the clock, the locale, the time zone, the calendar, the preferred languages, a bundle other than the package's own, the file system, user defaults, the process or localised text.
   - The legacy targets keep every other exemption of ADR 0012: their imports and the other rules stay unchecked until they are deleted. Every new production target has R17 too.
   - **Existing violations were fixed in the change that added the rules.** None is in the baseline.

## Consequences

- A view that makes a view model, holds a service or reads the device fails CI on Linux and on Xcode Cloud, in the legacy app as in the new targets.
- The rules that moved are tested on Linux in seconds. The Linux job already runs `swift test --package-path PrestoCVCore`, which now includes them.
- Initialisers are longer: a view model takes its clock, its calendar, its language and its waits. Tests either pass them or use the test initialisers that give fixed ones, so that no test reads the device unless it says so.
- The detectors are syntactic. A view is recognised by its conformance and the names of its type and extensions; a service by the suffix of its type's name (`UseCase`, `Repository`, `Service`, `Container`); a dependency in a default by a longer list of suffixes, kept in `rules.json` next to `infrastructureTypes`. A dependency with another name, or reached through a static property of an unlisted type, is not seen: the self-test lists what is covered, and review covers the rest.
- The legacy `PrestoCVCore` keeps its own side effects: its file storage, its template loader and its bundle reader are a separate issue. Only their hidden defaults moved to the composition root.

## Alternatives considered

- **Leave the legacy app exempt until it is deleted.** Version 1 ships it, and #254 showed that its separation erodes without a check.
- **Move the rules into the legacy `PrestoCVCore`.** It is the nearest home, but its tests do not run on Linux, and the rules would have to move a second time during the migration.
- **Make the domain read the legacy `CVModel`.** That would make a new target depend on a legacy one, which ADR 0012 forbids, and couple the domain to a model that is going away.
- **Map R4 onto the legacy app.** R4 also refuses `FileManager.default` and `Bundle.main` anywhere, which the legacy app's adapters use where they belong, at the edge. R17 states the part of R4 about default arguments as a rule of its own, for every production target.
