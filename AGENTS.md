# Repository Guidelines

## Project Structure & Module Organization
- `PrestoCV/` hosts the SwiftUI application: `App/` and `Features/` contain screens, `DesignSystem/` centralizes reusable views, `Navigation/` wires routing, and `Resources/` plus `Assets.xcassets` store localized strings and images.
- `PrestoCVCore/` is a Swift Package with domain models and services; use it for shareable logic and keep UI-dependent code in the app target.
- `CVPDFExporter/` is an auxiliary package for generating PDFs; its demos live under `CVPDFExporter/Demo/` and should stay decoupled from app code.
- Unit tests reside in `PrestoCVTests/` (Swift Testing-based) and `PrestoCVCore/Tests/`; UI automation lives in `PrestoCVUITests/`.

## Build, Test, and Development Commands
- `xcodebuild -project PrestoCV.xcodeproj -scheme PrestoCV -configuration Debug build` compiles the iOS app from the command line.
- `xcodebuild test -project PrestoCV.xcodeproj -scheme PrestoCV -destination 'platform=iOS Simulator,name=iPhone 15'` runs app unit + UI tests.
- `swift test --package-path PrestoCVCore` validates the core package in isolation.
- `open PrestoCV.xcodeproj` launches Xcode with the configured schemes; prefer running previews via the `PrestoCV` scheme.

## Coding Style & Naming Conventions
- Follow Swift 5.9+ defaults: four-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for methods, properties, and test doubles.
- Group related declarations with `// MARK:` sections and colocate previews with their views under `#if DEBUG`.
- Use value types (`struct`, `enum`) for feature models and mark async UI logic `@MainActor` as seen in `PrestoCVTests/PrestoCVTests.swift:10`.
- Keep resources organized: asset names mirror feature names (e.g., `Features/Profile` assets) and localization keys follow dot-separated feature scopes.

## Testing Guidelines
- Mirror the existing `@Suite`/`@Test` naming style (`@Test("createFirstCV succeeds and updates state")`) to document intent.
- Prefer lightweight spies like the mocks in `PrestoCVTests/PrestoCVTests.swift:18` and assert with `#expect` to keep diagnostics consistent.
- Aim for full coverage on onboarding and exporting flows before requesting review; add regression tests before modifying core models.
- Run both `swift test` and simulator-based UI tests for changes touching navigation or exporter integrations.

## Commit & Pull Request Guidelines
- Commits use short, imperative summaries (`Restore delete confirmation...`); keep body text for context or follow-up instructions.
- Reference issue numbers or Linear tickets in the body when available and list any follow-up tasks.
- Pull requests include: purpose summary, screenshots for UI-visible changes, validation notes (tests run, simulator device), and mention of localization impacts.
- Run the full test suite before submission and flag any remaining flakiness or simulator prerequisites in the PR description.
