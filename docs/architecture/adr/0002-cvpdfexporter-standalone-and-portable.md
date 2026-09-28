# 0002. CVPDFExporter is a standalone package, portable to a Linux backend

- **Status:** Accepted
- **Date:** 2026-09-27
- **Related:** [ADR 0003](0003-one-pdf-renderer-per-platform.md), [ADR 0007](0007-each-package-owns-its-model.md), [modules](../modules.md#package-cvpdfexporter--design-catalog-and-document-rendering), R1, R2, R8, R11

## Context

The exporter is meant to be reused outside the iOS app, including server-side PDF generation. Today it cannot be:
- It depends on `PrestoCVCore` for a single adapter (`PrestoCVCoreAdapter`, `convertToCV(from: Any?)`).
- It mixes platform-neutral logic with WebKit, UIKit, AppKit, SwiftUI, QuickLook, Combine and CryptoKit.
- It hard-codes app paths (`Application Support/PrestoCV/Templates`, `TemplateCache`) and reads the host's `Bundle.main`.
- It ships demos, a template viewer, UI components and test doubles inside the library.
- It trusts design packages, even though on a server every input is untrusted.

## Decision

`CVPDFExporter` stays a separate package with no dependency on any PrestoCV package. Its public contract is its own `CVDocument`: `Codable`, versioned, with typed sections.

Its core targets build and test on Linux: `CVDocumentModel`, `CVDesignCatalog`, `CVDesignCatalogFileStore`, `CVBundledDesigns` and `CVRendering`. They use no WebKit, UIKit, AppKit, SwiftUI, Combine, CryptoKit, `os.log`, `Bundle.main` or hard-coded paths.

The pipeline has two stages:
1. **Document + design → HTML** is pure Swift and identical everywhere.
2. **HTML → PDF** is a port with one adapter per platform ([ADR 0003](0003-one-pdf-renderer-per-platform.md)).

The published contract is explicit JSON: sections carry a `kind`, periods an `end` discriminator. Other schema versions are rejected, and `CVDocumentValidator` validates every document that arrives from outside. A committed JSON Schema is pending.

On a backend, rendering runs in a sandboxed process with no network egress, and with time, page and memory limits. A design that escapes the rules must not be able to reach internal services.

Security is part of the package rather than left to its callers:
- design packages are validated and sanitised on install;
- rendering has no JavaScript and no network;
- user values are escaped and never re-parsed.

Headings are translated through package resources, in the document's language.

## Consequences

- The app maps its `CV` to `CVDocument` in its integration layer. The exporter never sees app types.
- A Linux CI job builds and tests the core targets. It is what guarantees portability.
- Hashing, if needed, uses `swift-crypto`, or a non-cryptographic hash for cache keys. Logging goes through an injected logger.
- Demos move to a separate `CVPDFExporterExamples` package.
- A backend adapter (`CVRenderingServer`, for example driving headless Chromium) can be added later without touching the core.

## Validation

The validation prototype in `Prototypes/ADRValidation/` (Swift 6.3.3, Linux).

**Scope.** Linux only. This validates the package's core; nothing here validates a PDF produced by WebKit.

**Passed**
- `CVDocumentModel`, `CVDesignCatalog`, `CVBundledDesigns` and `CVRendering` build and pass their tests on Linux, with no dependency on any PrestoCV module. The checker confirms it: no import outside the allow-lists, and none declared in `Package.swift`.
- `CVDocument` carries today's CV content: the person's contact fields and every section, certifications included. It round-trips through explicit JSON. A document with `schemaVersion: 99` is rejected. The validator rejects an empty name, a rating of 9, oversized text or lists, control characters and an end before the start.
- The bundled `.mcvt` files load from `Bundle.module` on Linux.
- Headings load from package resources through BCP 47 matching. `de`, `fil` and `fi` are errors, not English.
- Every design-package attack in #9, in the adversarial reviews and in the security review is rejected. See [ADR 0011](0011-typed-html-builder.md#validation).

**Found**
- All three bundled designs are rejected as they stand, and must be rewritten against [contract 1](../markup-contract.md).
- A server renderer matches the Apple output only if the fonts match. Designs use a closed set of system font families, and embedding fonts needs its own ADR.

## Alternatives considered

- **Keep the exporter app-specific.** Rejected: it conflicts with the goal of reusing it.
- **Share the app's CV model with the exporter.** Rejected: a backend would then have to depend on the app's authoring domain. See [ADR 0007](0007-each-package-owns-its-model.md).
