# 0005. Remove AI tailoring and JSON Resume; optimisation will come from external APIs

- **Status:** Accepted
- **Date:** 2026-09-27
- **Related:** R1, R14, [ADR 0002](0002-cvpdfexporter-standalone-and-portable.md), issue #47

## Context

`CVPDFExporter` contains two features the app never uses:
- **AI tailoring:** `CVTailoringUseCase`, `LocalAIService`, `CVTailoringServiceProtocol`, `JobRequirements`, `CVImprovement`, `TailoredCVResult`. It overlaps `CVGeneratorAI` and sits in the wrong context. `CVTailoringUseCase` ignores its injected service, and `applyTailoring` drops the professional title.
- **JSON Resume:** `JSONResume` with 9 nested types, `JSONResumeAdapter` and `ExportManager`. They are used only by tests.

CV optimisation for a job offer is wanted in the future, but through external APIs.

## Decision

- Delete AI tailoring and JSON Resume, with their tests.
- Do not create ports or placeholders for optimisation now. When it is built, it becomes its own context. Its adapter calls the external API, behind a port owned by the app's integration layer, and it maps to and from its own model like every other context ([ADR 0007](0007-each-package-owns-its-model.md)).

## Consequences

- `CVPDFExporter` shrinks and stays focused on design catalog and rendering.
- A future backend that needs a standard input format can accept `CVDocument` JSON. JSON Resume can come back later as an input adapter, if there is demand.

## Validation

Checked on 2026-09-27 by searching the repository:
- The app target, `PrestoCVCore` and `CVGeneratorAI` never reference tailoring (`CVTailoring*`, `LocalAIService`, `JobRequirements`, `CVImprovement`) or JSON Resume (`JSONResume`, `JSONResumeAdapter`, `ExportManager`).
- Inside `CVPDFExporter`, the only users are `PDFExportDependencyContainer` and `ExportViewModel`, which are removed anyway ([ADR 0008](0008-single-composition-root.md), R14), and their own tests.

Removal is therefore safe, provided it happens together with, or after, the removal of those two types.

## Alternatives considered

- **Keep them for later.** Rejected: unused code decays, is already buggy, and contradicts R14.
