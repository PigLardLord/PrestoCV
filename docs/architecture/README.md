# PrestoCV target architecture

This directory defines the architecture PrestoCV must converge to before its first release, and the rules that keep it there. It describes the **target**. The code does not match it yet; the migration plan at the end says how it gets there.

Every rule here is meant to be checked by a machine: by the compiler through module boundaries, by the architecture checker in CI, or by a test. A rule without a check is a wish. See [ADR 0006](adr/0006-enforce-architecture-mechanically.md).

| Document | Contents |
|---|---|
| [rules.md](rules.md) | The rules (R1–R18), why each exists, and how each is enforced |
| [modules.md](modules.md) | Every package and target: responsibility, allowed dependencies, platforms |
| [glossary.md](glossary.md) | The vocabulary used in code, UI copy and tickets |
| [markup-contract.md](../../CVPDFExporter/Docs/markup-contract.md) | The HTML structure designs may style, versioned |
| [adr/](adr/) | Architecture decision records |

## Bounded contexts

| Context | Kind | Owns | Package |
|---|---|---|---|
| **CV Authoring** | core domain | The CV aggregate and its entries, their invariants and lifecycle; sample CVs; the reference to the chosen design | `PrestoCVCore` |
| **Design Catalog** | supporting | Design packages (`.mcvt`), their validation, installation, versions and listing | `CVPDFExporter` |
| **Document Rendering** | generic | Turning a document plus a design into HTML, and HTML into PDF, per platform | `CVPDFExporter` |
| **AI Drafting** | supporting | Producing a CV draft from a free-text description with the on-device model | `CVGeneratorAI` |
| **App** | integration and presentation | Cross-context workflows, the mappers between contexts, view models, views, the composition root | `PrestoCVApp` package + Xcode app target |

CV optimisation will come later from external APIs, as a separate context. AI tailoring and JSON Resume are removed ([ADR 0005](adr/0005-remove-ai-tailoring-and-json-resume.md)).

## Context map

```
                          ┌──────────────────────────── App ────────────────────────────┐
                          │ Views ──▶ ViewModels ──▶ Workflows + Mappers ◀── Composition │
                          └───────┬───────────────────┬──────────────────────┬──────────┘
            conformist to its     │                   │                      │
            published language    ▼                   ▼                      ▼
                          ┌───────────────┐  ┌──────────────────────────┐  ┌──────────────┐
                          │ CV Authoring  │  │ Design Catalog           │  │ AI Drafting  │
                          │ (PrestoCVCore)    │  │ Document Rendering       │  │ (CVGenerator │
                          │               │  │ (CVPDFExporter)          │  │  AI)         │
                          └───────────────┘  └──────────────────────────┘  └──────────────┘
                              no arrows between the three packages
```

- The three domain packages **never import each other**. Each publishes its own model: `CV` in Authoring, `CVDocument` in Rendering, `CVDraft` in Drafting.
- Inside `CVPDFExporter`, Document Rendering is downstream of Design Catalog: it consumes validated stylesheets and palettes. That is the only edge between contexts inside a package, and it goes one way ([R1](rules.md#r1-packages-are-isolated-contexts-depend-only-along-documented-edges)).
- All translation between contexts happens in one place: the app's integration layer (`PrestoCVIntegration`). Each mapper is exhaustive and tested ([ADR 0007](adr/0007-each-package-owns-its-model.md)).
- `CVPDFExporter` is reusable outside the app, including on a Linux backend ([ADR 0002](adr/0002-cvpdfexporter-standalone-and-portable.md)).

## Target graph

```
Xcode app target "PrestoCV" (iOS 26.5, macOS 26) — SwiftUI views, design system, platform views, @main
   │
   ├──▶ PrestoCVPresentation ──▶ PrestoCVWorkflowPorts ──▶ PrestoCVApplication ──▶ PrestoCVDomain   (domain via internal import)
   └──▶ PrestoCVComposition ──▶ everything below, renderer chosen per platform
                                   │
PrestoCVApp package                    │
  PrestoCVIntegration ─────────────────┼──▶ PrestoCVWorkflowPorts, PrestoCVApplication, PrestoCVDomain
                                   ├──▶ CVDocumentModel, CVDesignCatalog, CVRendering
                                   └──▶ CVDrafting
  PrestoCVComposition ──▶ PrestoCVPersistence, CVDesignCatalogFileStore, CVBundledDesigns, CVBundledHeadings,
                      CVRenderingWebKitSupport, CVRenderingIOS (iOS) / CVRenderingMacOS (macOS),
                      CVRenderingPDFKitInspector, CVDraftingFoundationModels

PrestoCVCore package        PrestoCVDomain ◀── PrestoCVApplication ◀── PrestoCVPersistence
CVPDFExporter package   CVDocumentModel ◀── CVRendering ──▶ CVDesignCatalog ◀── CVDesignCatalogFileStore, CVBundledDesigns
                        CVRendering ◀── CVRenderingWebKitSupport ◀── CVRenderingIOS / CVRenderingMacOS
                        CVRendering ◀── CVRenderingPDFKitInspector, CVBundledHeadings
CVGeneratorAI package   CVDrafting ◀── CVDraftingFoundationModels
```

Arrows point from the importer to the imported module. The authoritative list is [modules.md](modules.md).

## Layers inside a context

```
          inbound adapters (view models, CLI, server handlers)
                         │ call
                         ▼
   ┌──────────── Application: use cases, inbound + outbound ports ────────────┐
   │                     ┌──────────── Domain ────────────┐                   │
   │                     │ entities, value objects, rules │                   │
   │                     └────────────────────────────────┘                   │
   └───────────────────────────────▲─────────────────────────────────────────┘
                                   │ implement outbound ports
          outbound adapters (file storage, WebKit, FoundationModels)
```

Dependencies point inwards only. The domain knows nothing about storage, UI, localisation, platforms or time sources.

## Platforms

| Module group | iOS | macOS | Linux | Android |
|---|---|---|---|---|
| Domain, application, persistence, design catalog, rendering core, drafting core, integration, presentation | ✓ | ✓ | ✓ must build and test | ✓ must build |
| `CVRenderingWebKitSupport`, `CVRenderingPDFKitInspector` | ✓ | ✓ | | |
| `CVRenderingIOS` | ✓ | | | |
| `CVRenderingMacOS` | | ✓ | | |
| Test-support targets | ✓ | ✓ | ✓ | ✓ must build |
| `CVDraftingFoundationModels` | ✓ 26 | ✓ 26 | | |
| Xcode app target | ✓ 26 | ✓ 26 | | |

Linux support is not a nice-to-have. It is what proves that platform code stayed in the adapters ([R11](rules.md#r11-platform-code-lives-only-in-adapters)), and it is where the renderer for a backend will run.

Android support keeps the core reusable under the Android app's Kotlin interface. CI builds every Linux target for Android too, and [R18](rules.md#r18-pure-targets-stay-portable-to-android) keeps Apple-only modules and bundles out of the pure targets ([ADR 0026](adr/0026-keep-the-core-portable-to-android.md)).

## Migration strategy

The current code is not refactored in place. The new structure is built next to it, one context at a time, and the old code is deleted when its replacement is wired in.

1. **Rules and checks first.** Write this directory, commit the validation prototype (as `excluded`), then add `Tools/ArchitectureCheck` and the CI matrix ([ADR 0006](adr/0006-enforce-architecture-mechanically.md)).
   - The old targets are mapped as `legacy`, declared only on Apple hosts, and exempt until deleted ([ADR 0012](adr/0012-legacy-targets-during-migration.md)). The new targets start with an empty baseline.
2. **Empty targets.** Create every target in [modules.md](modules.md) with its dependency list, so the compiler holds the boundaries from day one.
3. **Rendering and Design Catalog.** They are the most broken part (GitHub issues #1, #2, #3, #8, #9, #21, #22) and the one meant for reuse. Build them in the new targets with contract tests, and rewrite the bundled designs against [markup contract 1](../../CVPDFExporter/Docs/markup-contract.md).
   - The legacy exporter, with its `PrestoCVCoreAdapter`, keeps serving the old app until step 5.
4. **CV Authoring.** Rich aggregate, persistence DTOs with schema v1, use cases returning the persisted identity (#4, #5, #10, #11, #12, #13, #27, #45).
5. **App integration, presentation and composition.** One composition root, view models in `PrestoCVPresentation`, workflow ports in `PrestoCVWorkflowPorts`, mappers in `PrestoCVIntegration`, NavigationSplitView for iOS and macOS (#6, #7, #14, #49). The app switches to the new export and editing workflows here; the legacy exporter is deleted.
6. **AI Drafting.** Port with its own draft model, availability port, validation on every path (#16, #17, #18, #35).
7. **Delete the old code** and close the issues the refactor made obsolete.

Each step lands behind green CI on iOS, macOS and Linux. On Linux only the new targets exist ([ADR 0012](adr/0012-legacy-targets-during-migration.md)). The Linux checks and the Android build run on GitHub Actions and the Apple checks on Xcode Cloud ([ADR 0024](adr/0024-run-apple-ci-and-releases-on-xcode-cloud.md)).

### Porting from the validation prototype

The validation prototype proved the ADRs; it is not production code. Its review ended with a fix-check round and no final gate (owner decision, 2026-09-28), because every part of it is reviewed again when it is ported. It lives in `Prototypes/ADRValidation/`, outside every build; the checker maps it as `excluded`.

Code ported from the prototype into the real targets, in step 1 (the checker) and in steps 3 to 6, is treated as new code:
- it is reviewed in full in the pull request that ports it, including the final adversarial review;
- its tests are read again, not trusted because they passed in the prototype.
