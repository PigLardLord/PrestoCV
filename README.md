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
| `Prototypes/ADRValidation/` | The throwaway prototype that validated the ADRs. It is outside the app's build; its README says how to run it. |

## Building and testing

You need Xcode 27, which reads the project in its JSON format (`PrestoCV.xcodeproj/project.xcproj`), and the iOS 26.5 simulator.

```bash
xcodebuild -project PrestoCV.xcodeproj -scheme PrestoCV -configuration Debug build
xcodebuild test -project PrestoCV.xcodeproj -scheme PrestoCV -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
swift test --package-path PrestoCVCore
Tools/ArchitectureCheck/check.sh
```

Today only the architecture checker and the prototype build and test on Linux. The new targets will too, as the migration creates them. The legacy targets stay Apple-only (ADR 0012).

## Contributing

- **Conventions, reviews, commits and pull requests:** `AGENTS.md`.
- **A change that adds a target or a dependency between targets** updates `docs/architecture/modules.md` and `Tools/ArchitectureCheck/rules.json` in the same pull request.

## License

Copyright © 2024 PrestoCV. All rights reserved.
