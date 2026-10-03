# PrestoCV target architecture

This directory defines the architecture PrestoCV must converge to before its first release, and the rules that keep it there. It describes the **target**. The code does not match it yet; the migration plan at the end says how it gets there.

Every rule here is meant to be checked by a machine: by the compiler through module boundaries, by the architecture checker in CI, or by a test. A rule without a check is a wish. See [ADR 0006](adr/0006-enforce-architecture-mechanically.md).

| Document | Contents |
|---|---|
| [rules.md](rules.md) | The rules (R1–R14), why each exists, and how each is enforced |
| [modules.md](modules.md) | Every package and target: responsibility, allowed dependencies, platforms |
| [glossary.md](glossary.md) | The vocabulary used in code, UI copy and tickets |
| [markup-contract.md](markup-contract.md) | The HTML structure designs may style, versioned |
| [adr/](adr/) | Architecture decision records |

## Bounded contexts

| Context | Kind | Owns | Package |
|---|---|---|---|
| **CV Authoring** | core domain | The CV aggregate and its entries, their invariants and lifecycle; sample CVs; the reference to the chosen design | `PrestoCVCore` |
| **Design Catalog** | supporting | Design packages (`.mcvt`), their validation, installation, versions and listing | `CVPDFExporter` |
| **Document Rendering** | generic | Turning a document plus a design into HTML, and HTML into PDF, per platform | `CVPDFExporter` |
| **AI Drafting** | supporting | Producing a CV draft from a free-text description with the on-device model | `CVGeneratorAI` |
| **CV Tailoring** | core domain | Tailoring one CV to a job advert and writing its cover letter, and holding both to their sources: advert analysis, content checks, the provenance gate, the tailoring loop | `CVTailoring` |
| **App** | integration and presentation | Cross-context workflows, the mappers between contexts, view models, views, the composition root | `PrestoCVApp` package + Xcode app target |
| **Server** | integration and composition | The HTTP API, the jobs, the authentication of installations, and the adapters that run tailorings with a model | `PrestoCVServer` package |

CV Tailoring is the context [ADR 0005](adr/0005-remove-ai-tailoring-and-json-resume.md) reserved ([ADR 0013](adr/0013-cv-tailoring-context.md)). It runs in the app and on the server; the tailoring loop runs only on the server. JSON Resume is not supported (ADR 0005).

The server is an integration and composition package beside the app, in two roles, `serve` and `work` ([ADR 0014](adr/0014-server-modular-monolith.md)). Like the app, it has a composition root of its own ([R4](rules.md#r4-one-composition-root-per-executable)). It reaches models through the providers its deployment configures, each held to the deployment's data policy ([ADR 0015](adr/0015-inference-providers-and-data-policy.md)). Hosted, it runs on Cloud Run in the EU, erases a job once the app has its result (24 hours after it ends at the latest), and limits what it spends ([ADR 0017](adr/0017-hosting-storage-and-cost.md)). Installations, not users, authenticate: the app proves with Apple's App Attest that it is a genuine copy, and the server keeps no account ([ADR 0018](adr/0018-app-attest.md)).

## Context map

```
                          ┌───────────────────────────────────── App ──────────────────────────────────────┐   ┌─────────────── Server ───────────────┐
                          │          Views ──▶ ViewModels ──▶ Workflows + Mappers ◀── Composition          │   │  HTTP ──▶ Use cases ◀── Composition  │
                          └───────┬───────────────────┬──────────────────────┬───────────────────────┬─────┘   └───────────────────┬──────────────────┘
            conformist to its     │                   │                      │                       │                             │
            published language    ▼                   ▼                      ▼                       ▼                             │
                          ┌───────────────┐  ┌──────────────────────────┐  ┌──────────────┐  ┌───────────────┐                     │
                          │ CV Authoring  │  │ Design Catalog           │  │ AI Drafting  │  │ CV Tailoring  │                     │
                          │ (PrestoCVCore)    │  │ Document Rendering       │  │ (CVGenerator │  │ (CVTailoring) │                     │
                          │               │  │ (CVPDFExporter)          │  │  AI)         │  │               │◀────────────────────┘
                          └───────────────┘  └──────────────────────────┘  └──────────────┘  └───────────────┘
                              no arrows between the four packages
```

- The four domain packages **never import each other**. Each publishes its own model: `CV` in Authoring, `CVDocument` in Rendering, `CVDraft` in Drafting, `SourceCV` and `TailoredCV` in Tailoring.
- Inside `CVPDFExporter`, Document Rendering is downstream of Design Catalog: it consumes validated stylesheets and palettes. That is the only edge between contexts inside a package, and it goes one way ([R1](rules.md#r1-packages-are-isolated-contexts-depend-only-along-documented-edges)).
- All translation between contexts happens today in one place: the app's integration layer (`PrestoCVIntegration`). Each mapper is exhaustive and tested ([ADR 0007](adr/0007-each-package-owns-its-model.md)).
- On the server, `ServerHTTP` maps the API's generated types to the tailoring model and back. That is not a translation between contexts, and the generated types never leave it ([ADR 0014](adr/0014-server-modular-monolith.md)).
- The API between the app and the server is one spec, `openapi.yaml`, in the `PrestoCVAPI` package. The types, the server's protocol and the app's client are generated from it and committed, and CI keeps them current and compatible. The package is not a context. Its generated types are imported only by `ServerHTTP` and, in the app, by the outbound adapter `PrestoCVAPIAdapter`, which is the app's only client of the API, and never leave them ([ADR 0016](adr/0016-api-contract.md)).
- The server sits beside the app. Today it conforms only to CV Tailoring's published model.
- `CVPDFExporter` is reusable outside the app, including on a Linux backend ([ADR 0002](adr/0002-cvpdfexporter-standalone-and-portable.md)).

## Target graph

```
Xcode app target "PrestoCV" (iOS 26, macOS 26) — SwiftUI views, design system, platform views, @main
   │
   ├──▶ PrestoCVPresentation ──▶ PrestoCVWorkflowPorts ──▶ PrestoCVApplication ──▶ PrestoCVDomain   (domain via internal import)
   └──▶ PrestoCVComposition ──▶ everything below, renderer chosen per platform
                                   │
PrestoCVApp package                    │
  PrestoCVIntegration ─────────────────┼──▶ PrestoCVWorkflowPorts, PrestoCVApplication, PrestoCVDomain
                                   ├──▶ CVDocumentModel, CVDesignCatalog, CVRendering
                                   ├──▶ CVDrafting
                                   └──▶ TailoringModel, AdvertAnalysis, ContentChecks
  PrestoCVComposition ──▶ PrestoCVPersistence, CVDesignCatalogFileStore, CVBundledDesigns,
                      CVRenderingWebKitSupport, CVRenderingIOS (iOS) / CVRenderingMacOS (macOS),
                      CVRenderingPDFKitInspector, CVDraftingFoundationModels, PrestoCVAPIAdapter, PrestoCVAppAttest
  PrestoCVAPIAdapter ──▶ PrestoCVIntegration, TailoringModel, PrestoCVAPITypes, PrestoCVAPIClient
  PrestoCVAppAttest ──▶ PrestoCVIntegration    (iOS 26, macOS 27; DeviceCheck, CryptoKit, Security)

PrestoCVCore package        PrestoCVDomain ◀── PrestoCVApplication ◀── PrestoCVPersistence
CVPDFExporter package   CVDocumentModel ◀── CVRendering ──▶ CVDesignCatalog ◀── CVDesignCatalogFileStore, CVBundledDesigns
                        CVRendering ◀── CVRenderingWebKitSupport ◀── CVRenderingIOS / CVRenderingMacOS
                        CVRendering ◀── CVRenderingPDFKitInspector
CVGeneratorAI package   CVDrafting ◀── CVDraftingFoundationModels
CVTailoring package     TailoringModel ◀── AdvertAnalysis, ContentChecks ◀── Provenance ◀── Tailoring
PrestoCVAPI package         PrestoCVAPITypes ◀── PrestoCVAPIServer, PrestoCVAPIClient    (generated from openapi.yaml, imports no PrestoCV package)

PrestoCVServer package
  PrestoCVServer (executable, composition root) ──▶ every target below, Tailoring and JWTKit
  ServerHTTP ──▶ ServerApplication, ServerAuth, TailoringModel, PrestoCVAPITypes, PrestoCVAPIServer
  ServerApplication ──▶ TailoringModel, Tailoring
  ServerAuth ──▶ ServerApplication
  ServerInference ──▶ ServerApplication, Tailoring, TailoringModel
  ServerAttestApple, ServerSessionJWT ──▶ ServerAuth
  ServerStorePostgres ──▶ ServerApplication, ServerAuth, TailoringModel
  ServerLocalProfile ──▶ ServerApplication, ServerAuth
  ServerQueueCloudTasks ──▶ ServerApplication
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

| Module group | iOS | macOS | Linux |
|---|---|---|---|
| Domain, application, persistence, design catalog, rendering core, drafting core, tailoring, integration, presentation | ✓ | ✓ | ✓ must build and test |
| `CVRenderingWebKitSupport`, `CVRenderingPDFKitInspector` | ✓ | ✓ | |
| `CVRenderingIOS` | ✓ | | |
| `CVRenderingMacOS` | | ✓ | |
| Server targets: `ServerApplication`, `ServerAuth`, `ServerInference`, `ServerAttestApple`, `ServerSessionJWT`, `ServerStorePostgres`, `ServerQueueCloudTasks`, `ServerLocalProfile`, `ServerHTTP`, `PrestoCVServer` | | ✓ for development | ✓ must build and test |
| `PrestoCVAPITypes`, `PrestoCVAPIClient`, `PrestoCVAPIAdapter` | ✓ | ✓ | ✓ must build and test |
| `PrestoCVAPIServer` | | ✓ for development | ✓ must build and test |
| Test-support targets | ✓ | ✓ | ✓ |
| `CVDraftingFoundationModels` | ✓ 26 | ✓ 26 | |
| `PrestoCVAppAttest` | ✓ 26 | ✓ 27 | builds empty (R11) |
| Xcode app target | ✓ 26 | ✓ 26 | |

Linux support is not a nice-to-have. It is what proves that platform code stayed in the adapters ([R11](rules.md#r11-platform-code-lives-only-in-adapters)), and it is where the renderer for a backend will run.

## Migration strategy

The current code is not refactored in place. The new structure is built next to it, one context at a time, and the old code is deleted when its replacement is wired in.

1. **Rules and checks first.** Write this directory, commit the validation prototype (as `excluded`), then add `Tools/ArchitectureCheck` and the CI matrix ([ADR 0006](adr/0006-enforce-architecture-mechanically.md)).
   - The old targets are mapped as `legacy`, declared only on Apple hosts, and exempt until deleted ([ADR 0012](adr/0012-legacy-targets-during-migration.md)). The new targets start with an empty baseline.
2. **Empty targets.** Create every target in [modules.md](modules.md) with its dependency list, so the compiler holds the boundaries from day one.
3. **Rendering and Design Catalog.** They are the most broken part (GitHub issues #1, #2, #3, #8, #9, #21, #22) and the one meant for reuse. Build them in the new targets with contract tests, and rewrite the bundled designs against [markup contract 1](markup-contract.md).
   - The legacy exporter, with its `PrestoCVCoreAdapter`, keeps serving the old app until step 5.
4. **CV Authoring.** Rich aggregate, persistence DTOs with schema v1, use cases returning the persisted identity (#4, #5, #10, #11, #12, #13, #27, #45).
5. **App integration, presentation and composition.** One composition root, view models in `PrestoCVPresentation`, workflow ports in `PrestoCVWorkflowPorts`, mappers in `PrestoCVIntegration`, NavigationSplitView for iOS and macOS (#6, #7, #14, #49). The app switches to the new export and editing workflows here; the legacy exporter is deleted.
6. **AI Drafting.** Port with its own draft model, availability port, validation on every path (#16, #17, #18, #35).
7. **Delete the old code** and close the issues the refactor made obsolete.

Each step lands behind green CI on iOS, macOS and Linux. On Linux only the new targets exist ([ADR 0012](adr/0012-legacy-targets-during-migration.md)).

### Porting from the validation prototype

The validation prototype proved the ADRs; it is not production code. Its review ended with a fix-check round and no final gate (owner decision, 2026-09-28), because every part of it is reviewed again when it is ported. It lives in `Prototypes/ADRValidation/`, outside every build; the checker maps it as `excluded`.

Code ported from the prototype into the real targets, in step 1 (the checker) and in steps 3 to 6, is treated as new code:
- it is reviewed in full in the pull request that ports it, including the final adversarial review;
- its tests are read again, not trusted because they passed in the prototype.
