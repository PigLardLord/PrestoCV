# Repository Guidelines

## Architecture (target)
- The target architecture and its rules are in `docs/architecture/`: start from `docs/architecture/README.md`, then `rules.md` (R1–R14) and `modules.md` (targets and allowed imports). Decisions are recorded as ADRs in `docs/architecture/adr/`.
- New code follows the target architecture, not the current structure described below. The migration is in progress (see the migration strategy in `docs/architecture/README.md`); where this file and `docs/architecture/` disagree, `docs/architecture/` wins.
- A change that needs a new target or a new dependency between targets updates `modules.md` in the same pull request. A permanent exception to a rule is an entry in the checker's `rules.json` that cites an ADR; a temporary one is a baseline entry, and the baseline may only shrink.
- Proposed ADRs describe the target and guide new code; a rule becomes binding when its ADR is Accepted and merged.

## Project Structure & Module Organization (current, being migrated)
- `PrestoCV/` hosts the SwiftUI application: `App/` and `Features/` contain screens, `DesignSystem/` centralizes reusable views, `Navigation/` wires routing, and `Resources/` plus `Assets.xcassets` store localized strings and images.
- `PrestoCVCore/` is a Swift Package with domain models and services; use it for shareable logic and keep UI-dependent code in the app target.
- `CVPDFExporter/` is an auxiliary package for generating PDFs; its demos and template viewer live in the separate `CVPDFExporterExamples/` package and should stay decoupled from app code.
- `CVTailoring/` is the CV Tailoring package (ADR 0013); it depends on no other PrestoCV package and builds on Linux.
- Unit tests reside in `PrestoCVTests/` (Swift Testing-based) and `PrestoCVCore/Tests/`; UI automation lives in `PrestoCVUITests/`.

## Build, Test, and Development Commands
- `xcodebuild -project PrestoCV.xcodeproj -scheme PrestoCV -configuration Debug build` compiles the iOS app from the command line.
- `xcodebuild test -project PrestoCV.xcodeproj -scheme PrestoCV -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` runs app unit + UI tests.
- `swift test --package-path PrestoCVCore` validates the core package in isolation.
- `Tools/ArchitectureCheck/check.sh` runs the architecture checker on the whole repository (see `Tools/ArchitectureCheck/README.md`).
- CI (`.github/workflows/ci.yml`) runs on every pull request:
  - on Linux, the architecture check (with the baseline compared to the base branch) and its self-test;
  - on macOS, on a self-hosted runner on the owner's Mac, the same checks plus the package tests and the app tests on the iOS simulator.
- `open PrestoCV.xcodeproj` launches Xcode with the configured schemes; prefer running previews via the `PrestoCV` scheme.

## Coding Style & Naming Conventions
- Swift 6 language mode with complete concurrency checking (R9); four-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for methods, properties, and test doubles.
- Group related declarations with `// MARK:` sections and colocate previews with their views under `#if DEBUG`.
- Use value types (`struct`, `enum`) for feature models and mark async UI logic `@MainActor` as seen in `PrestoCVTests/PrestoCVTests.swift:10`.
- Keep resources organized: asset names mirror feature names (e.g., `Features/Profile` assets) and localization keys follow dot-separated feature scopes.

## Testing Guidelines
- Mirror the existing `@Suite`/`@Test` naming style (`@Test("createFirstCV succeeds and updates state")`) to document intent.
- Prefer lightweight spies like the mocks in `PrestoCVTests/PrestoCVTests.swift:18` and assert with `#expect` to keep diagnostics consistent.
- Aim for full coverage on onboarding and exporting flows before requesting review; add regression tests before modifying core models.
- Run both `swift test` and simulator-based UI tests for changes touching navigation or exporter integrations.

## Reviews
- **Delta only.** Each review round covers only what changed since the last reviewed commit. Record that commit locally as `refs/reviewed/<branch>`, and list the reviewed commits in the pull request so another machine can continue. A full-branch review happens twice at most: the first one and the final gate. Commit before reviewing, because reviews read commits, not the working tree.
- **Reviewer by role:**
  - dimension reviews (security, concurrency, accessibility, code quality) and fix-check rounds use a mid-tier model;
  - only the final gate uses the strongest model.

  Never use a priority or "fast" tier for reviews.
- **Batched rounds:** fix every finding of a round before the next one, and run the dimension reviews before an adversarial round. After three rounds without convergence, stop and report the open findings to the owner.
- **Ported prototype code:** code ported from the validation prototype is new code. It gets the full review, including the final gate, in the pull request that ports it (see the migration strategy in `docs/architecture/README.md`).
- **No coding-assistant traces in the repository:** no names of coding assistants, AI agents or their models (the tools that write or review code) in files, commit messages, pull requests or issues. Build, test and architecture tools are named as usual. No credentials, keys or personal data.

## Commit & Pull Request Guidelines
- Commits use short, imperative summaries (`Restore delete confirmation...`); keep body text for context or follow-up instructions.
- Reference issue numbers or Linear tickets in the body when available and list any follow-up tasks.
- Pull requests include: purpose summary, screenshots for UI-visible changes, validation notes (tests run, simulator device), and mention of localization impacts.
- Run the full test suite before submission and flag any remaining flakiness or simulator prerequisites in the PR description.
