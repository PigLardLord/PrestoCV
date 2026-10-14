# PrestoCV

A SwiftUI app for iOS and macOS. You write your CV once and export it as a PDF in any of several designs. AI drafting on the device is optional.

## Status

Pre-production. The code is being rebuilt on a target architecture that is enforced mechanically, before the backlog bugs are fixed (ADR 0001):
- the architecture is in `docs/architecture/`;
- the order of work is issue #98.

The current app and packages are the legacy code the migration replaces, one context at a time.

## Where things are

| Path | What it is |
|---|---|
| `docs/architecture/` | The target architecture: overview and migration strategy, rules R1–R14, modules and allowed imports, document markup contract, glossary, ADRs. |
| `PrestoCV/`, `PrestoCVTests/`, `PrestoCVUITests/` | The app and its tests (legacy, being replaced). |
| `PrestoCVCore/`, `CVPDFExporter/`, `CVGeneratorAI/` | The current packages (legacy, being replaced). |
| `Tools/ArchitectureCheck/` | The checker that enforces the rules, and its pre-commit hook. |
| `ci_scripts/`, `TestPlans/`, `docs/release/` | The Xcode Cloud side of the releases: its build scripts, the test plans, and the settings of its workflows. |
| `Prototypes/ADRValidation/` | The throwaway prototype that validated the ADRs. It is outside the app's build; its README says how to run it. |

## Building and testing

You need Xcode 27, which reads the project in its JSON format (`PrestoCV.xcodeproj/project.xcproj`), and the iOS 26.5 simulator.

```bash
xcodebuild -project PrestoCV.xcodeproj -scheme PrestoCV -configuration Debug build
xcodebuild test -project PrestoCV.xcodeproj -scheme PrestoCV -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
xcodebuild test -project PrestoCV.xcodeproj -scheme PrestoCV -testPlan CI -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
swift test --package-path PrestoCVCore
Tools/ArchitectureCheck/check.sh
```

The scheme has two test plans. `PrestoCV`, the default, runs every test: the app's, the exporter package's simulator tests, and `PrestoCVUITests`. `CI` leaves out `PrestoCVUITests`, Xcode's template launch tests, which take most of an hour and check nothing.

On Linux, the packages contain only the new targets. They build today and stay empty until the migration fills them; the architecture checker and the prototype also build and test there. The legacy targets are declared only on Apple hosts (ADR 0012).

## Development data

- **Saved CVs.** Version 1 ships the legacy app (ADR 0022), so the CVs it saves in `Application Support/PrestoCV/CVs` are a released format. When the app switches to the new persistence (schema 1, ADR 0009), a one-time importer reads them. CVs saved by development builds before version 1, in `Documents`, are not migrated.
- **Samples.** The sample CVs offered on first run are in `PrestoCV/Resources/Samples/`, in schema 1, read by `DirectorySampleCVSource` through the store's own reader. The legacy app still reads the old samples, `PrestoCV/Resources/*_cv.json`, until the switch; they go with the legacy code (#47).

## Releasing

Xcode Cloud tests version 1, archives it, signs it and uploads it to TestFlight ([ADR 0024](docs/architecture/adr/0024-run-apple-ci-and-releases-on-xcode-cloud.md)). It runs three workflows:
- **Pull Request:** a pull request to `main` runs the `CI` test plan on an iPhone and an iPad simulator. GitHub shows the result in the pull request.
- **Main:** a merge to `main` tests, archives and uploads a build to TestFlight for the internal testers.
- **Release:** a GitHub Release with a tag such as `v1.2.3`, or a push to a branch such as `release/1.2.3`, tests that commit, archives version 1.2.3 and uploads it to TestFlight.

Nothing submits a build for App Review: the owner does it in App Store Connect, with Add for Review.

The repository side is `ci_scripts/` (it sets an archive's version from its tag or branch, checks the archive with `Tools/Release/check-archive.sh` before the upload, and runs the architecture check, the package tests and the package builds), `TestPlans/`, and the `DEVELOPMENT_TEAM` of the project. Xcode Cloud signs the build itself, so the repository holds no key and no secret. `docs/release/xcode-cloud.md` has the exact settings of the three workflows, the one-time setup, and the steps to cut a release.

## Contributing

- **Conventions, reviews, commits and pull requests:** `AGENTS.md`.
- **A change that adds a target or a dependency between targets** updates `docs/architecture/modules.md` and `Tools/ArchitectureCheck/rules.json` in the same pull request.

## License

Copyright © 2024 PrestoCV. All rights reserved.
