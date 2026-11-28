# PrestoCV

PrestoCV is a CV and résumé app for iPhone and iPad, written in SwiftUI. You write your CV once and export it as a PDF in any of several designs. Where the device supports Apple's Foundation Models, the app can also write a first draft on the device from a description in your own words. The app is in English, German, Spanish, French, Italian and Portuguese, and so are the headings of the documents it exports. A macOS version is part of the target architecture ([ADR 0004](docs/architecture/adr/0004-native-multiplatform-app.md)).

The source is licensed under the [Apache License 2.0](LICENSE). The name and the icon are not (see [License](#license)).

## Privacy

PrestoCV collects no data. It has no account, no analytics, no advertising and no server of its own:
- the CVs and the unsaved edits stay on the device, in the app's `Application Support/PrestoCV` folder, and go into the device's backups like the data of any app;
- the AI draft is written on the device by Apple's Foundation Models, so the description is not sent anywhere;
- in a release build, a CV leaves the device only as a PDF that the person shares or saves. A TestFlight or Debug build also keeps a trace of each step of the AI draft and the import on the device, and it leaves the device only when the person shares it ([ADR 0032](docs/architecture/adr/0032-record-each-step-of-the-ai-draft-and-the-import-in-test-builds.md)).

The privacy manifest, `PrestoCV/PrivacyInfo.xcprivacy`, declares no tracking and no collected data. A feature that sends data off the device would need its own ADR, and would change this section and the manifest in the same pull request. A privacy or security problem is reported as [SECURITY.md](SECURITY.md) says.

## Name

The app is called PrestoCV on the App Store ("PrestoCV: CV & Resume Maker"), under the bundle identifier `com.PigLardLord.prestocv`. Everything the user, the store or the signing sees says PrestoCV: the display name, the localized texts, the PDF metadata and the icon. So do the internal names: the targets, the schemes, the Swift modules and types, the folders and the project file (`PrestoCV.xcodeproj`), and the data folder `Application Support/PrestoCV`.

## Status

Version 1.0 is for iPhone and iPad. It is the legacy app with its bugs fixed ([ADR 0022](docs/architecture/adr/0022-ship-legacy-app-as-v1.md)). A macOS version comes later.

The code is being rebuilt on a target architecture that is enforced mechanically (ADR 0001), one context at a time. The current app and packages are the legacy code that the migration replaces, and it goes on after version 1:
- the architecture is in `docs/architecture/`;
- the order of work is issue #98.

## Where things are

| Path | What it is |
|---|---|
| `docs/product/` | The product vision: for whom PrestoCV is, its principles (including scaling with use and paying with revenue), the business model and the release plan. |
| `docs/architecture/` | The target architecture: overview and migration strategy, rules R1–R18, modules and allowed imports, glossary, ADRs. |
| `docs/maintainers/` | How the maintainer works: how pull requests are reviewed. |
| `PrestoCV/` | The app's `Info.plist`, icon `PrestoCV/PrestoCV.icon` ([docs/design/app-icon.md](docs/design/app-icon.md)), asset catalog, privacy manifest and sample CVs. |
| `PrestoCVCore/`, `CVPDFExporter/`, `CVGeneratorAI/` | The packages of the three contexts: CV Authoring, the design catalog and document rendering, and AI Drafting. Each holds its legacy targets, being replaced, and the new targets that replace them. |
| `PrestoCVApp/` | The new app package: workflow ports, presentation, integration and the composition root. |
| `PrestoCVNext/`, `PrestoCVNextTests/`, `PrestoCVNextUITests/` | The app's code, which the `PrestoCV` target compiles, its unit tests and its UI tests. |
| `CVPDFExporterExamples/` | The exporter's demos and template viewer, kept apart from the library. |
| `DiagnosticLogging/`, `docs/logging.md` | The diagnostic log (ADR 0030): one interface that carries no CV content, its decorators and its unified log adapter; the guide says how to read the log, what each event holds and how to add one. |
| `DiagnosticTrace/` | The trace of a test build (ADR 0032): each step of the AI draft and the import, with its text, kept on the device in TestFlight and Debug builds only, and shared by the person; `docs/logging.md` says where it is and how to read it. |
| `CVPDFExporter/Docs/` | The document markup contract that designs follow, which the exporter's tests hold the code to. |
| `Tools/ArchitectureCheck/`, `.githooks/` | The checker that enforces the rules, and the pre-commit hook that runs it. |
| `Tools/SourceChecks/` | The checks of source text: the string catalog, the rules the app's views follow, how the tests render views off screen, release hygiene, the deployment targets, and the documents (they are in English, this table matches the repository, and the open-source files are there and linked). They read the repository, so they run with `swift test`, not in the test plans. |
| `Tools/Localization/` | `l10n_manager.py`, which adds, reads, lists, checks and updates the texts of the string catalog. Run it from the repository root. |
| `ci_scripts/`, `TestPlans/`, `docs/release/`, `docs/ci.md` | The releases and the Apple checks: the build scripts that Xcode Cloud and the pull request check run, the test plans, the settings of the workflows and of the check, and the App Store listing in every language with the notes for App Review (`docs/release/store-listing.md`, checked by `Tools/SourceChecks`). |
| `Prototypes/ADRValidation/` | The throwaway prototype that validated the ADRs. It is outside the app's build; its README says how to run it. |
| `PrestoCV.xcodeproj/` | The Xcode project, in its JSON format (`project.xcproj`), and the shared schemes. |
| `.agents/` | The branch policy that the git hooks follow: the protected branches, and the paths that are not code. |
| `.github/` | The GitHub Actions workflow of the Linux checks and the Android build, which runs only when started by hand, and the code owners of the architecture rules. |

## Building and testing

You need Xcode 27.2, whose Swift is the one `.swift-version` pins, and the iOS 26.5 simulator. Xcode 27 reads the project in its JSON format (`PrestoCV.xcodeproj/project.xcproj`). To build the app and run its tests:

```bash
xcodebuild -project PrestoCV.xcodeproj -scheme PrestoCV -configuration Debug build
xcodebuild test -project PrestoCV.xcodeproj -scheme PrestoCV -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

- **Test plans:** `PrestoCV`, the default, runs every test, the app's UI tests (`PrestoCVNextUITests`) among them. `CI` leaves the UI tests out, as they take most of an hour.
- **On Linux:** the packages hold only their new targets, as the legacy ones are declared only on Apple hosts ([ADR 0012](docs/architecture/adr/0012-legacy-targets-during-migration.md)). `Tools/check-linux.sh origin/main` runs what the Linux CI job runs.
- **Before a pull request:** [CONTRIBUTING.md](CONTRIBUTING.md#building-and-testing) lists every command, the package tests, the architecture check and the source checks among them.

## Development data

What the app stores, and what a later version must still read:

- **Saved CVs:** `Application Support/PrestoCV/CVs`. Version 1 ships the legacy app ([ADR 0022](docs/architecture/adr/0022-ship-legacy-app-as-v1.md)), so these files are a released format: when the app switches to the new persistence ([ADR 0009](docs/architecture/adr/0009-persisted-schema-v1.md)), it imports them once. CVs saved by development builds before version 1, in `Documents`, are not migrated.
- **Saving:** the editor saves by itself, a second after the last change, and at once when it is left or the app leaves the foreground (`Autosave`). A change made outside the editor (a rename, a copy, a deletion, a look chosen in the export sheet) waits for the changes before it to the same CV (`StoredCVChangeQueue`), and is decided on the CV as stored at that moment (`ChangeStoredCV`).
- **The look of a CV:** the design, palette and fonts of its PDF, an optional `look` key of its file (`CVLook`). A new CV starts with `CVLook.standard`. A CV saved before the look existed has no key, and shows the design chosen last on the device, from `Application Support/PrestoCV/export-preferences.json`, which nothing writes any more. `ExportLookResolver` and `LookChange` say how a missing or unknown part is shown and kept.
- **Leftover edits:** earlier versions kept unsaved edits in `Application Support/PrestoCV/UnsavedEdits`, one `edits_<uuid>.json` per editing. They are a released format: the next launch stores them once and removes them (`LeftoverEditsImport`).
- **Samples:** version 1 offers five samples, `PrestoCV/Resources/<name>_cv.json` in English and `<name>_cv.<language>.json` in German, Spanish, French, Italian and Portuguese. The schema 1 samples in `PrestoCV/Resources/Samples/` (`DirectorySampleCVSource`) are for the switch, and version 1 does not ship them.

The doc comments of the types named here give the details, and their tests hold them.

## Releasing

Xcode Cloud archives version 1, signs it and uploads it to TestFlight ([ADR 0024](docs/architecture/adr/0024-run-apple-ci-and-releases-on-xcode-cloud.md)), in two workflows:
- **Main:** a merge to `main` archives a build for the internal testers. It runs no tests: the pull request check tested that tree.
- **Release:** a GitHub Release with a tag such as `v1.2.3`, or a push to a branch such as `release/1.2.3`, tests that commit, archives version 1.2.3 and uploads it.

Nothing submits a build for App Review: the maintainer does it in App Store Connect. Xcode Cloud signs the build itself, so the repository holds no key and no secret. [docs/release/xcode-cloud.md](docs/release/xcode-cloud.md) has the settings of the workflows, the one-time setup and the steps to cut a release.

Xcode Cloud checks no pull request: [CONTRIBUTING.md](CONTRIBUTING.md#pull-requests) says how one is checked, and [docs/ci.md](docs/ci.md) describes the checks. A pull request merges when its branch contains the latest `main` and the checks are green on its head.

## Contributing

- **How to contribute:** [CONTRIBUTING.md](CONTRIBUTING.md): building and testing, the architecture rules and the checker, commits, and what a pull request needs.
- **Reviews:** [docs/maintainers/reviews.md](docs/maintainers/reviews.md): how a pull request is reviewed, in rounds by reviewer agents, before the maintainer merges it.
- **Coding agents:** [AGENTS.md](AGENTS.md) points them to the same documents.
- **Code of conduct:** [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
- **Vulnerabilities:** report them privately, as [SECURITY.md](SECURITY.md) says, never in a public issue.

## License

Copyright 2026 Giovanni Trovato. The source is licensed under the [Apache License, Version 2.0](LICENSE).

"PrestoCV" and the app icon are trademarks of Giovanni Trovato and are not licensed under it. The icon's artwork, in `PrestoCV/PrestoCV.icon`, is not under the License either: all rights are reserved, and its files are in the repository only so that the official app can be built. A fork uses its own name and icon. The code of conduct is adapted from the Contributor Covenant and keeps its licence, CC BY 4.0. [NOTICE](NOTICE) has the details and the components the project uses.
