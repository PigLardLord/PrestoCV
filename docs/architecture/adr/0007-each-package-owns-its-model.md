# 0007. Each package owns its model; translation happens only in the app's integration layer

- **Status:** Accepted
- **Date:** 2026-09-28
- **Related:** [ADR 0002](0002-cvpdfexporter-standalone-and-portable.md), R1, R6, issues #2, #21, #35

## Context

A CV exists today in four production shapes: `CVModel` (Core), `CVDocument` (exporter), the template context `[String: Any]`, and `CVData` (AI). Five hand-written mappers join them, and each loses or renames data:
- The CV-to-document mapper lives in the exporter and takes `Any?`. The reverse mapper lives in the app and is not its inverse.
- Skill levels use three scales, language levels have three parsers, and periods have four formats.
- Social links are recognised by the English section title `"Online Profiles"`.

An earlier proposal introduced a shared-kernel package (`CVKernel`) with common value objects. It does not survive the constraints:
- The AI schema types must be `@Generable`, which ties them to FoundationModels.
- The exporter must not depend on app concepts ([ADR 0002](0002-cvpdfexporter-standalone-and-portable.md)).

A kernel would end up shared by one package only.

## Decision

- **Each package owns its model.**
  - Authoring owns `CV` and its value objects.
  - Rendering owns `CVDocument`, the published language of `CVPDFExporter`.
  - Drafting owns `CVDraft`, and its `@Generable` schema never leaves the adapter.
- **The three packages never import each other.** There is no shared kernel package.
- **Every translation between contexts lives in `PrestoCVIntegration`**, one mapper per direction that exists: `CV → CVDocument` and `CVDraft → CV`. Nothing maps back from `CVDocument`.
- **Mappers are**:
  - **exhaustive:** `switch` over every enum case, with no `default`, so a new case fails to compile until it is mapped;
  - **deterministic:** identifiers derived from the source, never `UUID()` or `Date()`;
  - **tested:** every field has a test, and the fixture CV exercises every section.
- **Typed contracts only.** No stringly-typed contracts between contexts. Sections are identified by type, never by title, and every field has one meaning.

## Consequences

- A few small value types exist in two or three packages: period, skill rating, language level, link. This is deliberate. Each package can evolve and ship on its own, and the mappers are where the differences are reconciled, in one place, under test.
- `PrestoCVCoreAdapter` and `CVDocumentAdapter` are deleted.
- The app's integration layer becomes the single place to look when data "disappears" between editor, AI and PDF.

## Validation

The validation prototype, commit `90533fb` of its own repository (`PigLardLord/PrestoCV-adr-prototype`, #65) (Swift 6.3.3, Linux), not yet in this repository; it is committed under `Prototypes/ADRValidation/` once it passes review.

**Passed**
- **`CV → CVDocument` keeps every field**, with typed dates. An unknown end becomes `unspecified`, never "present" (review finding H1).
- **A Mirror-based test** walks every populated field of a fully filled CV and requires each value in the mapped document. The test caught its own fixture's unpopulated month on the first run. A new field added to `CV` fails this test until it is mapped.
- **Adding a section kind without rendering it fails the build.**
- **`CVDraft → CV` goes through the domain's single period rule** (`Period.make`). Every shape is either kept or reported as a gap: current, completed, ended with an unknown end, no dates, end without start, end before start, current without start, current with an end. An invalid email is a gap, not a silent drop.
- **An AI draft keeps its identity** through save and load (#5).

**Scope.** The prototype's domain `CV` holds a subset of the target's fields: name, email, experiences and skills. `CVDocument` and the builder cover the full published contract, including contact fields and certifications, which review round 2 found missing. The Mirror test extends to every field as the domain grows.

**Found**
- The first mapper wrote display strings ("Present") into the document, which contradicted R13, and lost the "ended, unknown" state.
- The draft mapper silently dropped three shapes, and had its own copy of the period rule.

## Alternatives considered

- **Shared kernel package.** Rejected for the reasons above.
- **Share `CV` with the exporter.** Rejected: it would couple a reusable, backend-capable package to the app's authoring model.
- **Keep the mapper inside the exporter.** Rejected: it forces the exporter to depend on the app.
