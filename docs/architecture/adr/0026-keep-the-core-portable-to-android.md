# 0026. Keep the core portable to Android

- **Status:** Accepted
- **Date:** 2026-10-20
- **Related:** [ADR 0002](0002-cvpdfexporter-standalone-and-portable.md), [ADR 0006](0006-enforce-architecture-mechanically.md), [ADR 0012](0012-legacy-targets-during-migration.md), [ADR 0023](0023-ground-the-ai-draft-in-the-description.md), [ADR 0024](0024-run-apple-ci-and-releases-on-xcode-cloud.md), [R2](../rules.md#r2-pure-layers-read-no-ambient-state), [R11](../rules.md#r11-platform-code-lives-only-in-adapters), [R13](../rules.md#r13-localisation-happens-at-the-edges), R18 (added with this decision), issue #267

## Context

- **The direction.** PrestoCV will need an Android app, after version 1 for iOS and its first updates. The owner's direction for it (2026-10-20, #267): one shared core and two native interfaces, SwiftUI on iOS and Jetpack Compose with Material on Android. The core stays in Swift, compiled for Android with the Swift SDK for Android, official since Swift 6.3, and called from Kotlin. Kotlin Multiplatform is only the fallback, if that hits a blocking problem.
- **The analysis for #267** found that the new targets, which already build and test on Linux, are close to building for Android, and that nothing keeps them there while the migration fills them. Cross-compiling them on 2026-10-20 with Swift 6.4.0, its SDK for Android and the NDK r30, for `aarch64-unknown-linux-android28`, showed:
  - **The file stores do not compile.** `PrestoCVPersistence` and `CVDesignCatalogFileStore` lock with `flock`, and import the C library as `Glibc` or `Darwin`. On Android the module is called `Android`, and Foundation does not re-export it there, so `open`, `fstat`, `flock` and `errno` are not in scope.
  - **The headings read a bundle.** `HeadingsCatalog`, in `CVRendering`, reads its tables through `Bundle.module`. An Android app ships no SwiftPM resource bundle. The accessor SwiftPM generates for Android looks for the bundle next to the main bundle and the executable, and stops the process with `fatalError` when it is not there.
  - **Every other target builds.**
- **Only the import allow-lists keep an Apple-only framework out of a pure target**, and a pull request can widen one. Nothing refuses `Bundle.module` there: R2 allows it.
- **About thirty calls in the core need the full Foundation**, the one with ICU, which weighs tens of megabytes for each ABI of an app: regular expressions, `trimmingCharacters`, `folding`, `replacingOccurrences`, `JSONSerialization`. They build for Android with the full Foundation, not with `FoundationEssentials` alone. Whether the app should drop ICU is an open question for the owner, which the spike of #267 answers with measurements.
- **The SDK for Android must match the host toolchain exactly.** Xcode 27, which Xcode Cloud builds with, ships Swift 6.4.0. The Linux job ran Swift 6.3.

## Decision

**The owner decided on 2026-10-20** to adopt the cheap guardrails now ("Sì, adesso": yes, now). The bigger ones the analysis lists are follow-ups (below).

1. **CI builds the portable targets for Android.** A job on GitHub Actions, next to the Linux job, cross-compiles for `aarch64-unknown-linux-android28` every target that builds on Linux: the packages `PrestoCVCore`, `CVPDFExporter`, `CVGeneratorAI` and `PrestoCVApp`, whose manifests leave out the Apple-only and legacy targets on a Linux host ([ADR 0012](0012-legacy-targets-during-migration.md)). It builds, without the tests; the tests do not run on an emulator yet.
   - **Every version is pinned:** Swift 6.4.0, the toolchain of Xcode 27.0; its SDK for Android; the NDK r30 (30.0.16248370) of the runner image; and the action that installs them, `skiptools/swift-android-action` 2.9.5, by commit.
   - **The Linux job runs the same Swift 6.4.0.** Linux, Android and Xcode Cloud build with one compiler, and a toolchain update changes all three in one pull request.
2. **R18: pure targets stay portable to Android.** It applies to the targets that R2 calls pure: domain, application, published language, integration, presentation and workflow ports. The checker:
   - **refuses** an import of a module that only Apple platforms have (SwiftUI, UIKit, AppKit, Combine, CryptoKit, `os`, NaturalLanguage, FoundationModels, PDFKit, WebKit, Vision and others), in any form;
   - **refuses** `Bundle` in any form, `Bundle.module` and `#bundle` included;
   - **warns** on the APIs that need the full Foundation: `NSRegularExpression`, `NSRange`, `.regularExpression`, `folding`, `replacingOccurrences`, `trimmingCharacters`, `JSONSerialization`, `NSString`, `String(format:)`, Foundation's formatters and the localised comparisons. A warning does not fail the check and never enters the baseline: the warnings are the list of what `FoundationEssentials` alone would need, until the owner decides.
3. **Resources reach the core through a port.** `HeadingsCatalog` reads its tables through `HeadingTableSource`, as raw bytes, and decodes them itself, as the catalog does with `BundledDesignSource`. The tables move into a new adapter target, `CVBundledHeadings`, which reads them from its own bundle on Apple platforms and Linux. On Android the app's edge reads the same files from its assets and passes them through the same port. The package still owns its translations (R13).
4. **The file stores lock on Android too.** They import `Android` in a `canImport(Android)` branch, next to `Glibc` and `Darwin`. Their allow-lists and [modules.md](../modules.md) name it.

## Consequences

- **An Apple-only import or a bundle in a pure target fails the checker**, on GitHub Actions and on Xcode Cloud. A target that stops building for Android fails the Android job, on every pull request.
- **The Android job costs a few minutes** on a public repository's free runners. The action caches the host toolchain; the SDK and the build are not cached, because a build restored on fresh sources is rebuilt anyway.
- **The warnings stay visible** in every run of the checker, until the owner decides whether the core keeps the full Foundation.
- **`Bundle.module` stays allowed in adapters**, such as `CVBundledDesigns` and `CVBundledHeadings`: they are the edges that read the platform's resources. R2 keeps its rule for the other ambient state.
- **A new platform condition is allowed only in an adapter** (R11). The `canImport(Android)` branches are in the file stores, which are adapters.
- **Not decided here, and listed for later:**
  - a portable grounding: the draft's grounding moves into `CVDrafting` as plain structs, the description's language becomes an input, and English and German verbs come from closed lists instead of NaturalLanguage, which amends [ADR 0023](0023-ground-the-ai-draft-in-the-description.md);
  - more of the app's rules moved into the core, so that Kotlin does not rewrite them;
  - a rule for an API that Kotlin calls easily, for the facade that swift-java bridges;
  - the fonts bundled with the app, the same on iOS and Android, which R8 says needs its own ADR;
  - a committed JSON Schema, with a corpus of valid and invalid files, for `CVFileV1`, `CVDocument` and the exchange format of #266;
  - a check that the string catalog converts to Android's `strings.xml` mechanically;
  - the tests on an Android emulator, nightly;
  - whether the core drops the full Foundation, decided after the spike's measurements.

## Alternatives considered

- **Wait for the spike.** The guardrails cost little, and without them the core drifts from Android while the migration fills it: one more Apple-only import or one more `Bundle.module` is enough.
- **Rewrite the calls that need the full Foundation now.** About thirty replacements, but whether ICU's weight matters is what the spike measures, and the owner has not decided. A warning keeps the list visible without deciding.
- **Refuse those calls, with a baseline.** The baseline may only shrink, so a new regular expression would need an exception or a rewrite, for a call that is not a defect while the core keeps the full Foundation.
- **A `portable` flag per target in `rules.json`**, as the analysis proposed. A rule mapped to targets is the mechanism the checker already has, with the same effect.
- **Build only `PrestoCVDomain` and `PrestoCVApplication` for Android.** It saves seconds, but the targets that failed were the file stores, and the targets that build on Linux are the ones the Android app reuses.
- **Run the tests on an emulator now.** Booting an emulator adds minutes to every pull request. It comes later, as a nightly job.
- **Pass the heading tables to the catalog as a value.** It works too, but a port is how the catalog already receives its bundled designs, and it lets each platform's edge read the files when they are needed.
- **Pin the Android job to Swift 6.3, as the Linux job was.** The SDK must match the toolchain exactly, and the iOS app builds with 6.4.0 on Xcode Cloud; one version for all three removes a difference instead of choosing which one to keep.
