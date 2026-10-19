# Architecture decision records

An ADR records one decision: the context that forced it, what was decided, and what it costs.

- **While their branch is open, ADRs are drafts.** They are corrected as reviews find problems, including the ones already marked Accepted. "Accepted" there means the owner has taken the decision; the text can still be refined.
- **Once the branch is merged, an ADR is immutable.** A changed decision gets a new ADR that supersedes the old one, and the old one's status says so.
- **An ADR is binding only once it is Accepted and merged.** Proposed ADRs describe the intended target and guide the prototype, but they are not rules yet.

Status is one of **Proposed**, **Accepted**, **Superseded by NNNN**, **Rejected**.

| # | Decision | Status |
|---|---|---|
| [0001](0001-architecture-before-bug-fixing.md) | Define and enforce the target architecture before fixing bugs | Accepted |
| [0002](0002-cvpdfexporter-standalone-and-portable.md) | CVPDFExporter is a standalone package, portable to a Linux backend | Accepted |
| [0003](0003-one-pdf-renderer-per-platform.md) | One PDF renderer per platform behind a shared port | Accepted |
| [0004](0004-native-multiplatform-app.md) | The app is native SwiftUI on iOS and macOS | Accepted |
| [0005](0005-remove-ai-tailoring-and-json-resume.md) | Remove AI tailoring and JSON Resume; optimisation will come from external APIs | Accepted |
| [0006](0006-enforce-architecture-mechanically.md) | Enforce the architecture with target boundaries, a syntax-based checker and a shrinking baseline | Accepted |
| [0007](0007-each-package-owns-its-model.md) | Each package owns its model; translation happens only in the app's integration layer | Accepted |
| [0008](0008-single-composition-root.md) | A single composition root in the app | Accepted |
| [0009](0009-persisted-schema-v1.md) | Persisted CVs use a versioned DTO, schema v1, strict decoding, revisions and a store lock | Accepted |
| [0010](0010-ui-free-presentation-package.md) | View models live in a UI-framework-free package target | Accepted |
| [0011](0011-typed-html-builder.md) | Generate document HTML with a typed builder; designs are allow-listed CSS only | Accepted |
| [0012](0012-legacy-targets-during-migration.md) | Keep legacy targets out of Linux builds and out of the rules until deleted | Accepted |
| [0022](0022-ship-legacy-app-as-v1.md) | Ship the legacy app, fixed, as version 1 | Accepted |
| [0023](0023-ground-the-ai-draft-in-the-description.md) | Ground the AI draft by quoting the description and explaining every word | Accepted |
| [0024](0024-run-apple-ci-and-releases-on-xcode-cloud.md) | Run the Apple CI and the releases on Xcode Cloud | Accepted |
| [0025](0025-hold-the-legacy-app-to-the-separation-rules.md) | Hold the legacy app to the separation of views, view models and rules | Accepted |

New ADRs copy [template.md](template.md).
