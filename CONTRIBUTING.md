# Contributing to PrestoCV

This file says how to build and test PrestoCV, which rules a change follows, and what a pull request needs. The full conventions are in [AGENTS.md](AGENTS.md), and the architecture is in [docs/architecture/](docs/architecture/README.md).

Taking part means following the [Code of Conduct](CODE_OF_CONDUCT.md). A vulnerability is never reported in an issue: see [SECURITY.md](SECURITY.md).

## Before you start

- **Open an issue first** for anything larger than a small fix, so that the approach is agreed before the work. The code is being migrated to a new architecture, and some areas are about to be replaced (see "Status" in the [README](README.md)).
- **New code goes into the new targets.** The legacy targets are exempt from the architecture checker until they are deleted ([ADR 0012](docs/architecture/adr/0012-legacy-targets-during-migration.md)). Version 1 ships them ([ADR 0022](docs/architecture/adr/0022-ship-legacy-app-as-v1.md)). From its submission until the app switches to the new stack, a change to them only fixes a bug of the published version, starting from a failing test, or keeps the app building; a new feature goes into the new targets ([ADR 0033](docs/architecture/adr/0033-change-the-legacy-app-only-to-fix-the-published-version.md)).

## Requirements

- Xcode 27.2, whose Swift is the one `.swift-version` pins, and the iOS 26.5 simulator. Xcode 27 reads the project in its JSON format (`PrestoCV.xcodeproj/project.xcproj`).
- On Linux, the Swift that `.swift-version` pins (6.4.2), the one that every CI job and Xcode Cloud build with ([ADR 0026](docs/architecture/adr/0026-keep-the-core-portable-to-android.md)). With [swiftly](https://www.swift.org/install/linux/), `swiftly install` in the repository installs it, and swiftly then picks it from that file. It builds and tests the new targets of the packages and runs the architecture checker and the source checks; the app and the legacy targets need macOS.
- On a computer set to a language other than English, Swift Build 6.4 cannot read the banner of the linker ([swiftlang/swift-build#1934](https://github.com/swiftlang/swift-build/issues/1934)): run `swift build` and `swift test` with `LC_ALL=C`, as the CI container does. `Tools/check-linux.sh` and the architecture check set it themselves.

## Building and testing

From the repository root:

```bash
xcodebuild -project PrestoCV.xcodeproj -scheme PrestoCV -configuration Debug build
xcodebuild test -project PrestoCV.xcodeproj -scheme PrestoCV -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
xcodebuild test -project PrestoCV.xcodeproj -scheme PrestoCV -testPlan CI -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
swift test --package-path DiagnosticLogging
swift test --package-path DiagnosticTrace
swift test --package-path PrestoCVCore
swift test --package-path CVPDFExporter
swift test --package-path CVGeneratorAI
swift test --package-path Tools/SourceChecks
swift build --package-path PrestoCVApp
swift build --package-path CVPDFExporterExamples
xcodebuild build -project PrestoCV.xcodeproj -scheme PrestoCVNext -destination 'generic/platform=iOS Simulator' -destination 'generic/platform=macOS'
Tools/ArchitectureCheck/check.sh
Tools/ArchitectureCheck/selftest.sh
Tools/check-linux.sh origin/main
```

- **The `PrestoCV` scheme** builds the app and has two test plans. `PrestoCV`, the default, runs every test: the app's, the exporter package's simulator tests, and `PrestoCVUITests`, the app's UI tests. `CI` leaves out `PrestoCVUITests`, which take most of an hour; the pull request check runs them in a step of their own.
- **The `PrestoCVNext` scheme** builds the second app target, where the new app grows until the switch, for iOS and macOS. Its test plan, `Next`, runs `PrestoCVNextTests` (unit tests hosted in the app) and `PrestoCVNextUITests`.
- **`swift test --package-path`** tests a package in isolation. On Linux, run it for `DiagnosticLogging`, `DiagnosticTrace`, `PrestoCVCore`, `CVPDFExporter` and `Tools/SourceChecks`, and build `CVGeneratorAI` and `PrestoCVApp`: only the new targets exist there. `CVPDFExporterExamples`, the demos and the template viewer, builds on macOS only.
- **`Tools/check-linux.sh`** runs, on Linux, the Linux CI job's steps with the same script: the Swift against `.swift-version` (`Tools/check-toolchain.sh`, which the Mac check and Xcode Cloud run too), the architecture check against the baseline of the base ref you give, which may only shrink, its self-test, the source checks, and the build and tests of the new targets. It names each failed step and ends with a count.
- **`Tools/SourceChecks`** reads the repository, so it runs with `swift test`, not in the test plans. Besides the string catalog and the rules the views follow, it checks the documents: every tracked Markdown file is in English, the paths in the README's table exist and every top-level folder is in it, and the open-source files are there and linked.
- **A change to navigation or to the exporter's integration** also runs the simulator tests, not only the package tests.

## Architecture rules and the checker

The rules are strict, and a change that breaks one does not merge ([ADR 0006](docs/architecture/adr/0006-enforce-architecture-mechanically.md)).

- **The rules:** R1–R18 in [rules.md](docs/architecture/rules.md). Every target, its responsibility and the imports it may use are in [modules.md](docs/architecture/modules.md). Decisions are ADRs in [docs/architecture/adr/](docs/architecture/adr/README.md).
- **The checker:** `Tools/ArchitectureCheck/check.sh` must report 0 findings. Its first build takes a few minutes, because it compiles SwiftSyntax. [Its README](Tools/ArchitectureCheck/README.md) explains its options and how to install it as a pre-commit hook.
- **Violations:** a temporary one is a baseline entry, and the baseline may only shrink. A permanent one is an exception in `Tools/ArchitectureCheck/rules.json` that cites an ADR.
- **A new target, or a new dependency between targets,** updates `docs/architecture/modules.md` and `Tools/ArchitectureCheck/rules.json` in the same pull request.
- **Ownership:** changes to `docs/architecture/` and `Tools/ArchitectureCheck/` need a code owner's review (`.github/CODEOWNERS`).

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
- **Documentation** is part of the change. A pull request that changes behaviour, a command or a path updates the documents that describe it, in the same pull request, and in English.
- **CI** runs on every pull request: on Linux (`Tools/check-linux.sh`: the Swift against `.swift-version`, the architecture check with its self-test, the source checks, the packages' new targets; and their build for Android), through a script run on a Linux computer, outside the repository, that writes the commit statuses `Linux (local) · CI` and `Android (local) · CI` (the GitHub Actions workflow with the same two jobs runs only when started by hand, so that the repository stays on GitHub's free plan), and on the maintainer's Mac mini on macOS ([ADR 0029](docs/architecture/adr/0029-check-pull-requests-on-the-mac-mini.md): the Swift against `.swift-version`, the `CI` test plan on an iPhone and an iPad simulator, the package tests and builds, the source checks, the architecture check and the self-tests of the release scripts in `Tools/Release/`, then `PrestoCVUITests` on the iPhone unless every changed file is a Markdown file or lies in `docs/`, `Tools/`, `ci_scripts/` or `.github/`). Xcode Cloud checks no pull request; it builds the releases.
- **Reviews** follow the process in [AGENTS.md](AGENTS.md#reviews).

## Licence

Contributions are licensed under the [Apache License 2.0](LICENSE), as section 5 of the License says; there is no separate agreement to sign. The name "PrestoCV" and the app icon are not licensed under it (see [NOTICE](NOTICE)).
