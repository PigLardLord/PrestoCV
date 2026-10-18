# Contributing to PrestoCV

This file says how to build and test PrestoCV, which rules a change follows, and what a pull request needs. The full conventions are in [AGENTS.md](AGENTS.md), and the architecture is in [docs/architecture/](docs/architecture/README.md).

Taking part means following the [Code of Conduct](CODE_OF_CONDUCT.md). A vulnerability is never reported in an issue: see [SECURITY.md](SECURITY.md).

## Before you start

- **Open an issue first** for anything larger than a small fix, so that the approach is agreed before the work. The code is being migrated to a new architecture, and some areas are about to be replaced (see "Status" in the [README](README.md)).
- **New code goes into the new targets.** The legacy targets are exempt from the architecture checker until they are deleted ([ADR 0012](docs/architecture/adr/0012-legacy-targets-during-migration.md)). Version 1 ships them, so a change to them fixes a bug or adds a version 1 feature ([ADR 0022](docs/architecture/adr/0022-ship-legacy-app-as-v1.md)).

## Requirements

- Xcode 27, which reads the project in its JSON format (`PrestoCV.xcodeproj/project.xcproj`), and the iOS 26.5 simulator.
- On Linux, Swift 6.3. It builds and tests the new targets of the packages and runs the architecture checker; the app and the legacy targets need macOS.

## Building and testing

From the repository root:

```bash
xcodebuild -project PrestoCV.xcodeproj -scheme PrestoCV -configuration Debug build
xcodebuild test -project PrestoCV.xcodeproj -scheme PrestoCV -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
xcodebuild test -project PrestoCV.xcodeproj -scheme PrestoCV -testPlan CI -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
swift test --package-path PrestoCVCore
swift test --package-path CVPDFExporter
swift test --package-path CVGeneratorAI
swift build --package-path PrestoCVApp
swift build --package-path CVPDFExporterExamples
Tools/ArchitectureCheck/check.sh
```

- **The `PrestoCV` scheme** builds the app and has two test plans. `PrestoCV`, the default, runs every test: the app's, the exporter package's simulator tests, and `PrestoCVUITests`. `CI` leaves out `PrestoCVUITests`, Xcode's template launch tests, which take most of an hour.
- **`swift test --package-path`** tests a package in isolation. On Linux, run it for `PrestoCVCore` and `CVPDFExporter`, and build `CVGeneratorAI` and `PrestoCVApp`: only the new targets exist there. `CVPDFExporterExamples`, the demos and the template viewer, builds on macOS only.
- **A change to navigation or to the exporter's integration** also runs the simulator tests, not only the package tests.

## Architecture rules and the checker

The rules are strict, and a change that breaks one does not merge ([ADR 0006](docs/architecture/adr/0006-enforce-architecture-mechanically.md)).

- **The rules:** R1–R14 in [rules.md](docs/architecture/rules.md). Every target, its responsibility and the imports it may use are in [modules.md](docs/architecture/modules.md). Decisions are ADRs in [docs/architecture/adr/](docs/architecture/adr/README.md).
- **The checker:** `Tools/ArchitectureCheck/check.sh` must report 0 findings. Its first build takes a few minutes, because it compiles SwiftSyntax. [Its README](Tools/ArchitectureCheck/README.md) explains its options and how to install it as a pre-commit hook.
- **Violations:** a temporary one is a baseline entry, and the baseline may only shrink. A permanent one is an exception in `Tools/ArchitectureCheck/rules.json` that cites an ADR.
- **A new target, or a new dependency between targets,** updates `docs/architecture/modules.md` and `Tools/ArchitectureCheck/rules.json` in the same pull request.
- **Ownership:** changes to `docs/architecture/` and `Tools/ArchitectureCheck/` need the owner's review (`.github/CODEOWNERS`).

## Code

- **Swift 6** language mode with complete concurrency checking (R9). Four-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for methods, properties and test doubles.
- **Views render, view models present, neither decides** (R5). Business rules live in the domain or application layer of their context, never in a view.
- **Structure:** group related declarations with `// MARK:` sections, and keep previews next to their views under `#if DEBUG`.
- **User-facing text** is in the string catalog `PrestoCV/Localizable.xcstrings`, in English, German, Spanish, French, Italian and Portuguese. Keys use dot-separated feature scopes. `Tools/Localization/l10n_manager.py`, run from the repository root, adds, reads, lists, checks and updates them. A pull request says whether it changes any text.

## Tests

- **A pull request that changes code includes tests for the change.** A bug fix starts with a test that fails without the fix (R10). A change to a core model adds its regression tests first.
- **Style:** Swift Testing, with descriptive names in the existing style (`@Test("createFirstCV succeeds and updates state")`), lightweight spies, and `#expect`.
- **Hermetic:** tests use temporary directories and injected time and identifiers. They never touch the user's home, the real Application Support or `Bundle.main`.
- **Test data** uses invented people and reserved domains such as `example.com`. It never holds a real person's data, a credential or a key.

## Commits

- **The summary** is short and imperative, such as `Restore delete confirmation for CVs`. The body gives the context and any follow-up.
- **Issues:** reference them in the body, as in `Refs #123`.
- **No tool traces:** files, commit messages, pull requests and issues do not name the coding assistants or models used to write or review code, and commits carry no attribution trailers for them. Build, test and architecture tools are named as usual.
- **No secrets:** no credentials, keys or personal data, anywhere in the repository.

## Pull requests

- **The description** gives the purpose, screenshots for a change the user can see, the validation (the tests run and the simulator device), and the impact on localization.
- **Before opening one,** run the full test suite and the architecture check. Report any flaky test or simulator prerequisite in the description.
- **CI** runs on every pull request: on GitHub Actions on Linux (the architecture check with its self-test, and the packages' new targets), and on Xcode Cloud on macOS (the check, the package tests, the package builds, and the `CI` test plan on an iPhone and an iPad simulator).
- **Reviews** follow the process in [AGENTS.md](AGENTS.md#reviews).

## Licence

Contributions are licensed under the [Apache License 2.0](LICENSE), as section 5 of the License says; there is no separate agreement to sign. The name "PrestoCV" and the app icon are not licensed under it (see [NOTICE](NOTICE)).
