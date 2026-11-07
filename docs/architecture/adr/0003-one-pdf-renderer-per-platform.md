# 0003. One PDF renderer per platform behind a shared port

- **Status:** Accepted
- **Date:** 2026-09-27
- **Related:** [ADR 0002](0002-cvpdfexporter-standalone-and-portable.md), [ADR 0004](0004-native-multiplatform-app.md), [ADR 0011](0011-typed-html-builder.md), R3, R8, R9, R10, R11, issues #8, #22, #44

## Context

HTML-to-PDF conversion is platform specific. On iOS, pagination comes from `UIPrintPageRenderer` with the web view's print formatter; on macOS, from `NSPrintOperation`; on Linux there is no WebKit at all.

Today:
- The iOS renderer drops every page after `maxPages` (default 4) without saying so.
- The page count is estimated from the byte size.
- The renderer is built through `MainActor.assumeIsolated` in a static factory.
- There are three macOS renderers, only one of them reachable. It produces a single tall, unpaginated page and can wait forever on a failed load.
- `TestPDFRenderer` is the production fallback on unsupported platforms.

## Decision

- **One port.** `CVRendering` declares `PDFRendering`. It is async, cancellable (untyped `throws`) and `Sendable`, and returns `RenderedPDF { data, pageCount, requiredPages }`. `truncated` is derived from `requiredPages > pageCount`; a renderer cannot declare it.
- **One adapter target per platform:** `CVRenderingIOS`, `CVRenderingMacOS`, and later `CVRenderingServer`. No renderer serves two platforms through `#if`. Every file of a platform target is wrapped entirely in its platform condition.
- **Web-view security lives once**, in `CVRenderingWebKitSupport`:
  - the rule list is compiled once by the composition root;
  - network is blocked per scheme and for every subresource type;
  - JavaScript is off for content;
  - the store is non-persistent;
  - media plays only on user action;
  - a navigation delegate accepts only the initial load.

  The readiness script runs in a dedicated `WKContentWorld` through `callAsyncJavaScript`, with a timeout and cancellation, and never trusts DOM state.
- **The PDF is read, not trusted.** `CVRendering` declares a second port, `PDFInspecting`. `CVRenderingPDFKitInspector` implements it on Apple platforms. The export workflow and the contract both use it.
- **Every adapter passes the contract suite** from `CVRenderingTestSupport`:
  - the fixture fits within the page limit (a truncated fixture is a failure) and every field appears in the extracted text;
  - the page count is the inspector's;
  - truncation is reported;
  - `requiredPages` equals the page count of an unlimited render;
  - pre-start cancellation is deterministic.

  Native-only tests are added by `CVRenderingIOSTests` and `CVRenderingMacOSTests`:
  - in-flight cancellation;
  - long-document pagination;
  - content completeness for every bundled design;
  - the security tests from R8.

  A **geometric completeness** check reads the real PDF with PDFKit (`PDFKitInspector`, `GeometricCompleteness`): each text line inside its page, and its glyph height at least 6 pt. The design install gate and the native renderer tests run it (#78, #80).
- **Selection by the app.** The app picks its renderer through platform-conditional target dependencies in `PrestoCVComposition`. The composition root creates it on the main actor and injects it.
- **No fallback renderer.** An unsupported platform fails at build time, not with a fake PDF.
- **Backend.** A server renderer runs in a sandboxed process with no network egress, and with time, page and memory limits.

## Consequences

- The iOS and macOS renderers are written against the contract, not ported from the current code.
- Output differences between platforms become visible in the contract tests, not in users' hands.
- A backend renderer is an addition, not a refactor.

## Validation

**Scope.** Linux only, with a fake renderer. Nothing here validates a real PDF. The native iOS and macOS runs of the contract suite are pending, and they are required before any PDF defect is declared fixed. `CVRenderingWebKitSupport` has not been compiled: there is no Apple toolchain on this machine. Its block rules were exercised on WebKitGTK 2.52.6 by the security review: rule compilation, a blocked image load, and the main document still loading. That engine shares WebKit's content-extension compiler, but its PDF path differs from Apple's.

Prototype: the validation prototype of the target structure (packages `Core`, `Exporter`, `Drafting`, `App`, plus the checker), in `Prototypes/ADRValidation/`, Swift 6.3.3 on Linux (x86_64), 2026-09-27, after an adversarial review and three internal reviews (Swift code, security, documentation). It is mapped as `excluded` in the checker's rules, and its README says how to reproduce these results.

**Passed**
- The contract reads the PDF through `PDFInspecting`. The fake renderer writes real, uncompressed PDFs and passes.
- These renderers fail it:
  - bytes that are not a PDF, with an invented page count;
  - a renderer that loses a field;
  - one that misreports its page count;
  - one that truncates without reporting it (#8);
  - one that declares truncation it did not do while dropping content (review H2);
  - one whose output pushes the fixture past the page limit.
- Pre-start cancellation is checked inside an already-cancelled task group. The previous version failed 3 of 40 runs under CPU load.
- `PrestoCVComposition` picks the renderer through `.when(platforms:)` dependencies, and the package still builds on Linux.

**Found, and now part of this decision**
- A platform-only target breaks `swift build` of the whole package on Linux unless every file in it is wrapped in `#if os(...)`.
- `requiredPages` and the truncation flag must be checked against the PDF, not taken from the renderer.

## Alternatives considered

- **One Apple renderer using `WKWebView.createPDF`.** Rejected: it does not paginate, and the decision is to keep one renderer per platform.
- **Mac Catalyst to reuse the iOS renderer.** Rejected together with Catalyst in [ADR 0004](0004-native-multiplatform-app.md).
