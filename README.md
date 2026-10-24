# PrestoCV

A SwiftUI app for iOS and macOS. You write your CV once and export it as a PDF in any of several designs. AI drafting on the device is optional.

## Name

The app is called PrestoCV on the App Store ("PrestoCV: CV & Resume Maker"), under the bundle identifier `com.PigLardLord.prestocv`. Everything the user, the store or the signing sees says PrestoCV: the display name, the localized texts, the PDF metadata and the icon. So do the internal names: the targets, the schemes, the Swift modules and types, the folders and the project file (`PrestoCV.xcodeproj`), and the data folder `Application Support/PrestoCV`.

## Status

Pre-production. The code is being rebuilt on a target architecture that is enforced mechanically, before the backlog bugs are fixed (ADR 0001):
- the architecture is in `docs/architecture/`;
- the order of work is issue #98.

The current app and packages are the legacy code the migration replaces, one context at a time.

## Where things are

| Path | What it is |
|---|---|
| `docs/product/` | The product vision: for whom PrestoCV is, its principles (including scaling with use and paying with revenue), the business model and the release plan. |
| `docs/architecture/` | The target architecture: overview and migration strategy, rules R1–R18, modules and allowed imports, glossary, ADRs. |
| `PrestoCV/`, `PrestoCVTests/`, `PrestoCVUITests/` | The app and its tests (legacy, being replaced). |
| `PrestoCVCore/`, `CVPDFExporter/`, `CVGeneratorAI/` | The current packages (legacy, being replaced). |
| `CVPDFExporter/Docs/` | The document markup contract that designs follow, which the exporter's tests hold the code to. |
| `Tools/ArchitectureCheck/` | The checker that enforces the rules, and its pre-commit hook. |
| `Tools/SourceChecks/` | The checks of source text: the string catalog, the rules the app's views follow, release hygiene. They read the repository, so they run with `swift test`, not in the test plans. |
| `Tools/Localization/` | `l10n_manager.py`, which adds, reads, lists, checks and updates the texts of the string catalog. Run it from the repository root. |
| `ci_scripts/`, `TestPlans/`, `docs/release/` | The releases: Xcode Cloud's build scripts, the test plans, the settings of its workflows, and the App Store listing in every language with the notes for App Review (`docs/release/store-listing.md`, checked by `Tools/Release/check-store-listing.py`). |
| `Prototypes/ADRValidation/` | The throwaway prototype that validated the ADRs. It is outside the app's build; its README says how to run it. |

## Building and testing

You need Xcode 27, which reads the project in its JSON format (`PrestoCV.xcodeproj/project.xcproj`), and the iOS 26.5 simulator.

```bash
xcodebuild -project PrestoCV.xcodeproj -scheme PrestoCV -configuration Debug build
xcodebuild test -project PrestoCV.xcodeproj -scheme PrestoCV -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
xcodebuild test -project PrestoCV.xcodeproj -scheme PrestoCV -testPlan CI -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
swift test --package-path PrestoCVCore
swift test --package-path Tools/SourceChecks
Tools/ArchitectureCheck/check.sh
```

The scheme has two test plans. `PrestoCV`, the default, runs every test: the app's, the exporter package's simulator tests, and `PrestoCVUITests`. `CI` leaves out `PrestoCVUITests`, Xcode's template launch tests, which take most of an hour and check nothing.

On Linux, the packages contain only the new targets. They build today and stay empty until the migration fills them; the architecture checker, the source checks and the prototype also build and test there. The legacy targets are declared only on Apple hosts (ADR 0012).

## Development data

- **Saved CVs.** Version 1 ships the legacy app (ADR 0022), so the CVs it saves in `Application Support/PrestoCV/CVs` are a released format. When the app switches to the new persistence (schema 1, ADR 0009), a one-time importer reads them. CVs saved by development builds before version 1, in `Documents`, are not migrated.
- **Saving.** The editor saves by itself (`Autosave`, in PrestoCVApplication): a second after the last change, and at once when the editor is left or the app leaves the foreground. A CV that has not changed is never written, so its edit time stays. A blank CV or an example is stored once it is changed and holds enough to save; an AI draft and an imported CV are stored as they are. The writes of an editor go one at a time; when one fails, the editor says so, keeps the edits, and stores the CV with the next change or when the person tries again, and the cause is logged. Back is the editor's own: it stores what the editor shows first, and when it cannot, the editor stays open with its failure, so that nobody leaves their edits behind. The edge swipe leaves at once only when no write runs and the store holds what the form shows, and goes through Back otherwise: a write that runs can still put something else in the store. While Try Again writes, the failure stays shown, and "Saved on this device" comes back only once a write has succeeded. However an editor is left, the list and the editors wait for its last save before they read the store. "Open in PrestoCV" over an open editor saves it first, and opens the import only once the CV is stored. In the list, a CV with no name, person or role is called "Untitled CV", then "Untitled CV 2", in the words of each language (`CVTitle.labels`).
- **The look of a CV.** The design, color palette and font of a CV's PDF are kept with the CV, as an optional `look` key of its file (`CVLook`: the ids `design`, `palette` and `fonts`, in the pattern of `DesignChoice`). The export sheet starts from it (`ExportLookResolver`) and keeps each change: the editor's form saves it, and the list stores it (`ChangeStoredCV.setLook`) once nothing has been chosen for a quarter of a second, so that a design, a palette and a font tried in turn make one write and one read of the list, or at once when the sheet is closed or the app leaves the foreground. A sheet opened again before the write has gone through starts from the choices made (`ExportChoices`), not from the row, which is a save behind. A CV that was exported and opened again, or one that was exported after another, shows its own choice. A part that is missing, or that the app no longer knows, shows its default (the first design, professional colors, classic fonts) and stays in the file until the person chooses that part: a choice hands over the parts the person changed (`LookChange`) and the look the sheet showed, and a stored CV takes only the changed parts, so choosing a palette keeps the design id of a newer build; a CV without a look takes the whole look the sheet showed. A `look` key of the wrong shape (a list, a number, an id that is not text) reads as no look: the rest of the CV is read as strict as before, the CV stays in the list, and reading does not change the file. The changes made to a stored CV outside its editor (a language or a look chosen in the list's export sheet, a rename, a copy, a deletion) go one at a time for each CV (`StoredCVChangeQueue`): each is registered the moment it is made (a choice in an export sheet, before its pause), starts when the ones before it for that CV have ended and when the editors that were left have stored theirs, and reads the CV as they left it, so that none undoes another. Every value a change takes from the CV, and every decision whether to change it, is taken on the CV as stored at that moment, never on the row of the list, which can be a change behind: a copy is named after the title the stored CV has then, and choosing the look the CV has already is no change (nothing is written, the modification date stays and the row stays where it is), while a look chosen otherwise is an edit like any other (it updates the date and moves the row to the top). The editor of a CV reads it only once its line is empty, so that its first save cannot undo a choice that was on its way. A new CV, whether a blank one, an example, an AI draft or an imported CV, starts with the standard look (`CVLook.standard`: the exporter's own defaults), never with the look of another CV; a duplicate keeps the look it copies. A CV saved before the look existed has no key, is not rewritten when it is opened, and is shown with the design chosen last on the device (`Application Support/PrestoCV/export-preferences.json`, which earlier versions kept for the whole app and nothing writes any more), or the defaults when there is none.
- **Leftover edits.** Earlier versions kept the edits nobody had saved in `Application Support/PrestoCV/UnsavedEdits`, one `edits_<uuid>.json` per editing, apart from the CVs. They are a released format, so the next launch stores them once, without a question, the oldest first, and removes them (`LeftoverEditsImport`). Edits update the stored CV they were made on if it has not been saved again since, and are otherwise stored as a separate copy, marked as recovered, whose id comes from the edits; edits the CV or their copy already holds are only removed. Once stored, edits are marked as stored before they are removed, in `StoredUnsavedEdits` beside their folder: edits whose removal fails are only removed at the next launches, whatever the person did with the CV since, so an edited CV gets no copy and a deleted one does not come back. Edits that cannot be stored stay for the next launch, and if the folder cannot be reached, the app opens without them.
- **Samples.** Version 1 offers the five legacy samples on the first run and on the New CV screen: `PrestoCV/Resources/<name>_cv.json` in English and `<name>_cv.<language>.json` in German, Spanish, French, Italian and Portuguese. The app reads the set of the language it is shown in, and the English one where there is none. They go with the legacy code (#47). The schema 1 samples in `PrestoCV/Resources/Samples/`, read by `DirectorySampleCVSource` through the store's own reader, are for the switch: the app target leaves them out until then, so version 1 does not ship them.

## Releasing

Xcode Cloud tests version 1, archives it, signs it and uploads it to TestFlight ([ADR 0024](docs/architecture/adr/0024-run-apple-ci-and-releases-on-xcode-cloud.md)). It runs three workflows:
- **Pull Request:** a pull request to `main` runs the `CI` test plan on an iPhone and an iPad simulator. GitHub shows the result in the pull request.
- **Main:** a merge to `main` tests, archives and uploads a build to TestFlight for the internal testers.
- **Release:** a GitHub Release with a tag such as `v1.2.3`, or a push to a branch such as `release/1.2.3`, tests that commit, archives version 1.2.3 and uploads it to TestFlight.

Nothing submits a build for App Review: the owner does it in App Store Connect, with Add for Review.

The repository side is `ci_scripts/` (it sets an archive's version from its tag or branch, checks the archive with `Tools/Release/check-archive.sh` before the upload, and runs the architecture check, the package tests, the source checks and the package builds), `TestPlans/`, and the `DEVELOPMENT_TEAM` of the project. Xcode Cloud signs the build itself, so the repository holds no key and no secret. `docs/release/xcode-cloud.md` has the exact settings of the three workflows, the one-time setup, and the steps to cut a release.

## Contributing

- **Conventions, reviews, commits and pull requests:** `AGENTS.md`.
- **A change that adds a target or a dependency between targets** updates `docs/architecture/modules.md` and `Tools/ArchitectureCheck/rules.json` in the same pull request.

## License

Copyright © 2024 PrestoCV. All rights reserved.
