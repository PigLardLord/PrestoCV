# 0004. The app is native SwiftUI on iOS and macOS

- **Status:** Accepted
- **Date:** 2026-09-27
- **Related:** [ADR 0003](0003-one-pdf-renderer-per-platform.md), [ADR 0010](0010-ui-free-presentation-package.md), R5, R11

## Context

The app will ship on macOS as well as iOS. The current app target is iOS-only and uses UIKit-only APIs in shared views:
- `UIViewRepresentable` in `HTMLPreviewView` and `DocumentPreview`;
- `UIPasteboard`;
- iOS-only modifiers: `keyboardType`, `textInputAutocapitalization`, `navigationBarTitleDisplayMode`.

Navigation is a single `NavigationStack`, which suits a phone and not a Mac window.

## Decision

- The app is one native SwiftUI target with iOS 26 and macOS 26 destinations. It does not use Mac Catalyst.
- Navigation is built on `NavigationSplitView`, with the CV list as the sidebar and the editor as the detail view. On iPhone it collapses into a stack, and iPad gets a proper layout for free.
- Platform-specific UI lives only in the app's `Platform/` folder: preview representables, sharing, pasteboard, file import and export, and shims that wrap iOS-only modifiers for `Features/`. Views in `Features/` contain no `#if os`. `App/` may use `#if os` for scenes and macOS commands.
- Persistence uses Application Support on both platforms. The location is decided in the composition root.
- App, `PrestoCVCore` and `CVGeneratorAI` target iOS 26 and macOS 26, because FoundationModels requires them. `CVPDFExporter` keeps lower minimums for reuse.
- CI builds and tests both destinations.

## Consequences

- Every screen is designed for both size classes and for pointer and keyboard input.
- The macOS sandbox applies: files live inside the app container, and sharing goes through `ShareLink` or the save panel.
- Tests of view models do not depend on the platform ([ADR 0010](0010-ui-free-presentation-package.md)).

## Validation

Not verifiable on Linux: SwiftUI, Xcode targets and the macOS and iOS SDKs are required. It must be checked on a Mac when the app target is created, with the same bar as the rest:
- the app builds for both destinations;
- `NavigationSplitView` collapses correctly on iPhone;
- `Features/` contains no `#if os`, which the architecture checker enforces.

The part of this decision that could be tested did pass: view models with no platform dependency. See [ADR 0010](0010-ui-free-presentation-package.md).

## Alternatives considered

- **Mac Catalyst.** Rejected: it would let the iOS renderer run on the Mac, but it goes against one renderer per platform and gives a less native Mac app.
- **A separate macOS app target.** Rejected: it would duplicate the views, while the platform differences are small enough for the `Platform/` folder.
