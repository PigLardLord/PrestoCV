# Packages and targets

This is the authoritative list of production modules and of what each may import. The checker's `rules.json` must agree with it in both directions ([ADR 0006](adr/0006-enforce-architecture-mechanically.md)):

- every target listed here has a rule, or is declared `notYetImplemented`;
- no rule allows an import this file does not allow. Rules may be stricter, never looser;
- every dependency declared in a `Package.swift` must be an allowed import.

A new target, or a new edge between targets, changes this file in the same pull request.

Notation:
- **May import** lists every module the target may `import`. Swift and Foundation are always allowed; in domain targets only as value types (R2).
- The platform column reads iOS / macOS / Linux. **Linux ✓** means the target must build and pass its tests on Linux in CI.

Test targets and test-support targets are described below each package. The checker applies only its import allow-lists to them.

---

## Package `PrestoCVCore` — CV Authoring

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `PrestoCVDomain` | domain | iOS, macOS, Linux ✓ | Foundation |
| `PrestoCVApplication` | application | iOS, macOS, Linux ✓ | `PrestoCVDomain`, Foundation |
| `PrestoCVPersistence` | outbound adapter | iOS, macOS, Linux ✓ | `PrestoCVApplication`, `PrestoCVDomain`, Foundation, Glibc, Darwin |

**`PrestoCVDomain`**
- **`CV`**, the aggregate:
  - a typed identity (`CVID`);
  - `revision`, `createdAt` and `updatedAt`, settable only inside the package;
  - a private title, `PersonalDetails`, and ordered sections of entries;
  - the "has enough content to be saved" rule, which is about the name only;
  - the size bounds: `limitViolation` reports the first bound the CV is over, or nil;
  - duplication with a title composed by the caller.
- **The text rule** is internal to the domain, in one file. `CV` applies it wherever text enters: both initialisers, so a stored file too, and `rename`, `setPersonalDetails` and `setSections`. Value objects are validated when they are made, and the rule does not touch them. It has two kinds:
  - **single line**: the title, the name, the professional title, the location, an entry's role, company, location, degree and school, a skill, a language, a certification's name and issuer, a profile's platform, and each interest. A line break (`\r\n`, `\r`, `\n`, NEL, U+2028, U+2029) or a tab becomes one space.
  - **multi line**: the summary and the descriptions of an experience, an education entry and a certification. A line break becomes `\n`, and a tab becomes one space.
  - **Both kinds** remove, without an error, the C0 controls, DEL, the C1 controls other than NEL, bidirectional embeddings, overrides and isolates (U+202A–U+202E, U+2066–U+2069), and tag characters (U+E0000–U+E007F). They keep ZWJ and ZWNJ, and they neither trim nor collapse spaces. Applying the rule twice gives the same text.
  - Interests are normalised before they are trimmed and de-duplicated, so `a<tab>b` and `a b` are one interest.
- **Size limits**, `CVLimits`, counted in UTF-8 bytes: 10,000 bytes in a text, 250,000 in all the text of a CV, and 200 entries in a section.
  - They are at or below the bounds of both places a CV goes, so a CV that can be saved can be rendered and can be stored (R6, R12):
    - the document validator in `CVPDFExporter` (16,384 bytes in a text, 262,144 in all, 200 entries). They sit below it because the document adds its language tag, and because the domain counts every text a CV holds, the title, the contact details and the links included, so it is never looser;
    - the stored file ([ADR 0009](adr/0009-persisted-schema-v1.md)): a text of at most 10,000 characters, a list of at most 500 items and a file of at most 5 MiB. A text of 10,000 bytes is never more than 10,000 characters, 200 entries are under 500, and 250,000 bytes of text are far under the file cap.
  - `limitViolation` reports the first bound in a fixed order: a text that is too long (`textTooLong`, which names the field and, for an entry, its index in the section), then a section with too many entries (`tooManyEntries`), then the total (`tooMuchText`). The values name fields and sections; presentation writes the words (R13).
  - A text is never cut. A CV over a bound is refused at save.
- **Value objects:**
  - `PartialDate` (year or month precision, partial order);
  - `Period`, whose end is a date, "current" or "ended, date unknown" (`PeriodEnd.unknown`);
  - `SkillLevel` (1–5);
  - `LanguageProficiency` (CEFR + native);
  - `EmailAddress`, `PhoneNumber`, `WebLink`, `DocumentLanguage`, `DesignChoice`.
- **`Period.make(start:end:current:)`** is the single rule that turns loose data into a period, or into a typed `PeriodError`.
- Planned: projects (#54), photo (#53).

**`PrestoCVApplication`**
- **Ports:**
  - `CVRepository`: create, conditional update, load, list, conditional delete. Typed `RepositoryError`, not cancellable.
  - `CVStoreMaintenance`: restore from quarantine, erase every copy, purge quarantine.
  - `SampleCVSource`, `IDGenerator`, `TimeSource`. `TimeSource` is so named to avoid shadowing `Swift.Clock`.
- **Use cases:**
  - `NewCV`, `SaveCV` (create or conditional update, errors translated to `AuthoringError`, including `tooLarge`), `LoadCV`;
  - `SaveCV` refuses a CV without a name (`notEnoughContent`) first, then a CV over a size limit (`exceedsLimits`, which carries the CV's `limitViolation`), before it touches the store; rename and duplicate save through it and refuse the same way;
  - list (by last change), rename, duplicate, delete, start from a sample, determine onboarding.
- **Listing** returns the healthy CVs plus `StoreIssue`s: `corrupt`, `upgradeRequired`, `unreadable`, `tooLarge`, `quarantineFailed`.

**`PrestoCVPersistence`**
- `FileCVRepository`:
  - one `CVFileV1` file per CV, named from its id;
  - atomic writes with `complete` protection, and a read-back check before every write;
  - every mutation under an exclusive `flock` on the store;
  - reads classified as described in R12, and text normalised by the domain when the CV is built, so a stored file cannot bring back what the text rule removes;
  - `Quarantine/` with validated restore, erase and purge.
- `DirectorySampleCVSource`: sample CVs from an injected directory, in the same v1 format and through the store's own reader. The app ships them in `PrestoCV/Resources/Samples/`.

**Test support and tests.**
- `PrestoCVCoreTestSupport` may import `PrestoCVApplication`, `PrestoCVDomain`, Foundation, Synchronization. It holds:
  - `InMemoryCVRepository`, `SteppingClock`, `SequentialIDGenerator`;
  - the **`CVRepository` contract suite**: round trip with timestamps, create twice, update bumps the revision, stale update and stale delete, 50 concurrent updates from one revision leave exactly one success, update after delete, listing order.
- File-store behaviour that an in-memory store cannot have is tested in the Core tests, not in the contract: mixed directory, unreadable, oversized and hostile files, restore, erase, purge, and two instances racing.

---

## Package `CVPDFExporter` — Design Catalog and Document Rendering

Standalone and portable. It has no dependency on any PrestoCV package ([ADR 0002](adr/0002-cvpdfexporter-standalone-and-portable.md)). Legacy targets are declared only on Apple hosts during the migration ([ADR 0012](adr/0012-legacy-targets-during-migration.md)).

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `CVDocumentModel` | published language | iOS, macOS, Linux ✓ | Foundation |
| `CVDesignCatalog` | domain + application | iOS, macOS, Linux ✓ | Foundation |
| `CVDesignCatalogFileStore` | outbound adapter | iOS, macOS, Linux ✓ | `CVDesignCatalog`, Foundation, Glibc, Darwin |
| `CVBundledDesigns` | outbound adapter + resources | iOS, macOS, Linux ✓ | `CVDesignCatalog`, Foundation |
| `CVRendering` | application | iOS, macOS, Linux ✓ | `CVDocumentModel`, `CVDesignCatalog`, Foundation |
| `CVRenderingWebKitSupport` | adapter support | iOS, macOS | `CVRendering`, WebKit, Foundation |
| `CVRenderingIOS` | outbound adapter | iOS | `CVRenderingWebKitSupport`, `CVRendering`, WebKit, UIKit, Foundation |
| `CVRenderingMacOS` | outbound adapter | macOS | `CVRenderingWebKitSupport`, `CVRendering`, WebKit, AppKit, Foundation |
| `CVRenderingPDFKitInspector` | outbound adapter | iOS, macOS | `CVRendering`, PDFKit, Foundation |
| *(future)* `CVRenderingServer` | outbound adapter | Linux | `CVRendering`, Foundation |

**`CVDocumentModel`**
- **`CVDocument`**, the package's public contract, also the JSON a backend accepts:
  - `schemaVersion` (other versions are rejected) and `language`;
  - the person: name, professional title, email, phone, location, website;
  - typed sections: summary, experience, education, skills, languages, certifications (name, issuer, year, URL, description), profiles, interests;
  - dates as `DocumentDate` and `DocumentPeriod` with `PeriodEnd` `present`, `date` or `unspecified`, never display strings.
- **Explicit JSON.** Sections are `{"kind": …}` objects and periods carry an `end` discriminator.
- **`CVDocumentValidator`** is the anti-corruption layer for documents from outside:
  - it checks the name, counts, dates and ratings;
  - it bounds text in UTF-8 bytes, per field and for the whole document, and refuses control characters and bidirectional overrides;
  - JSON arrives through `decode(json:)`, which checks the size before decoding.
- Pending: a committed JSON Schema.

**`CVDesignCatalog`**
- **`MarkupContract`**, version 1: elements, classes, section kinds, ratings, pseudo-classes. See [markup-contract.md](markup-contract.md).
- **The CSS policy:** a tokenizer, an allow-list of properties and values, and canonical re-serialisation into `ValidatedStylesheet`, whose initialiser is internal.
- **`DesignPackageValidator`** takes raw bytes and returns a `ValidatedDesign`: manifest, stylesheet and PNG preview.
- **Customisation values:** `HexColor`, `Palette` (exists only with readable contrast) and `FontScheme` (a closed set).
- **Use cases:**
  - list, get, sync bundled designs (upgrade when newer);
  - **`InstallDesign`**: validate the raw bytes, then `DesignRenderingGate.verify`, then `DesignStore.save`. Nothing is stored unless both checks pass.
- **Ports:** `DesignStore`, `BundledDesignSource` (raw bytes), and **`DesignRenderingGate`**. The catalog owns the gate; `CVRendering` implements it, along the allowed Rendering → Catalog edge.

**`CVDesignCatalogFileStore`** holds `FileDesignStore`: the directory is injected, the index is written atomically under a lock (`flock`), and one instance serves the process. Every read validates the file again, so only validated designs leave the store.

**`CVBundledDesigns`** holds the bundled `.mcvt` files as resources, served as raw bytes through `Bundle.module`.

**`CVRendering`**
- **`DocumentHTMLBuilder`:**
  - produces the markup contract, with closed `Tag` and `Attr` enums and per-scalar escaping;
  - validates the language tag;
  - keeps only `WebLink`s, and prints each link's destination as its text;
  - formats dates in the document language.
- **`HeadingsCatalog`:** JSON heading tables per language plus an index, matched by BCP 47. An unsupported language is a typed error.
- **`PDFRendering`**, the outbound port: `render(html:page:) async throws -> RenderedPDF`, with `data`, `pageCount` and `requiredPages`. `truncated` is derived from those.
- **`PDFInspecting`**, the outbound port that reads the page count and text of a PDF.
- **`RenderedDocument`:** the builder's output, meaning the HTML plus the exact text nodes it contains.
- **`DocumentCompleteness`:** every text node needs its own span of the PDF text, which no other node uses, ignoring case and spacing.
- **`FixtureRenderingGate`:** implements the catalog's `DesignRenderingGate`. It renders a fixture that uses every section with the candidate design, and requires a complete, untruncated PDF.
- **Policy:** the required fields and page limit, shared by preview and export.

**`CVRenderingWebKitSupport`**
- `SecureWebViewConfiguration.compileRules()` is called once by the composition root: a block rule per network scheme, plus a block on every subresource type. `make(rules:)` then builds each configuration: JavaScript off for content, non-persistent store, media only on user action.
- `SingleLoadNavigationDelegate` loads the HTML string with no base URL, reports when that load has finished, and cancels every later navigation.
- `DocumentReadiness` waits until the document is complete and its fonts are ready. Its script runs in a content world of its own, with a timeout.
- Content blockers do not see `data:` URLs on Apple platforms: a test records this. None can enter the document, because the builder emits only http(s) links and the CSS policy has no `url()` (R8).
- A clicked link, which only happens in the preview, may open a connection to its host before the navigation is cancelled (a WebKit preconnect). Nothing is sent over it. A document's links and a refresh make no connection at all; tests record both.
- Every file is wrapped in `#if canImport(WebKit)`.
- **`CVRenderingWebKitSupportTests`** check each of these on iOS and macOS. Each network test has a control without the rules, which shows that the test can see a request.
- On iOS the exporter's tests run through the shared `ExporterTests` scheme, which holds the new test targets only: the package scheme also builds the legacy targets, which do not build for iOS.

**`CVRenderingIOS`, `CVRenderingMacOS`**
- One `PDFRendering` implementation per platform ([ADR 0003](adr/0003-one-pdf-renderer-per-platform.md)). Every file is wrapped in its platform condition.

**`CVRenderingPDFKitInspector`**
- `PDFInspecting` on PDFKit, used by the export workflow and by the native contract tests. Every file is wrapped in `#if canImport(PDFKit)`.

**Test support and tests.**
- **`CVRenderingTestSupport`** may import `CVRendering`, `CVDocumentModel`, `CVDesignCatalog`, Foundation. It holds `InMemoryDesignStore`, the **`DesignStore` contract suite** that it and `FileDesignStore` pass, and:
  - the **`PDFRendering` contract suite**:
    - the fixture must fit and contain every field;
    - page count per the inspector;
    - truncation reported;
    - `requiredPages` checked against an unlimited render;
    - deterministic pre-start cancellation;
  - `FakePDFRenderer`, which writes real uncompressed PDFs;
  - `MinimalPDFInspector`.
- **`CVRenderingIOSTests` and `CVRenderingMacOSTests`** run the contract suite against the real renderers with the PDFKit inspector: `xcodebuild test` on the iOS simulator, `swift test` on macOS. They also run the long-document pagination test, in-flight cancellation and the content-completeness test for every bundled design.

**Separate package `CVPDFExporterExamples`** holds the demos and the template viewer. The library package contains no executables (R14).

---

## Package `CVGeneratorAI` — AI Drafting

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `CVDrafting` | domain + application | iOS, macOS, Linux ✓ | Foundation |
| `CVDraftingFoundationModels` | outbound adapter | iOS 26, macOS 26 | `CVDrafting`, FoundationModels, Foundation |

**`CVDrafting`**
- **`CVDraft`:** plain `Sendable` structs; optional wherever the user may not have said it. A job has an optional start year, an optional end year and whether it is current.
- **Use case:** `DraftCV` validates the input, generates, then validates the output. Streaming follows the same path.
- **Ports:** `DraftGenerating` (untyped `throws`, cancellable) and `DraftAvailability`.
- **`DraftingError`:** one case per model failure.

**`CVDraftingFoundationModels`**
- Internal `@Generable` schema, a session with instructions, availability from `SystemLanguageModel`.
- Until it is implemented it throws a typed "unavailable" error; it never returns an empty draft.

**Test support.** `CVDraftingTestSupport` holds a fake generator and fixtures.

---

## Package `PrestoCVApp` — App integration and presentation

A local package next to the Xcode project. The compiler holds the app's layers too, and everything except the composition builds and tests on Linux.

| Target | Layer | Platforms | May import |
|---|---|---|---|
| `PrestoCVWorkflowPorts` | app ports | iOS, macOS, Linux ✓ | `PrestoCVApplication`, `PrestoCVDomain`, Foundation |
| `PrestoCVIntegration` | app application layer | iOS, macOS, Linux ✓ | `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain`, `CVDocumentModel`, `CVDesignCatalog`, `CVRendering`, `CVDrafting`, Foundation |
| `PrestoCVPresentation` | inbound adapter | iOS, macOS, Linux ✓ | `PrestoCVWorkflowPorts`, `PrestoCVApplication`, `PrestoCVDomain` (both `internal import`), Observation, Foundation |
| `PrestoCVComposition` | composition root | iOS, macOS | everything above, plus `PrestoCVPersistence`, `CVDesignCatalogFileStore`, `CVBundledDesigns`, `CVRenderingIOS` (iOS only), `CVRenderingMacOS` (macOS only), `CVRenderingWebKitSupport`, `CVRenderingPDFKitInspector`, `CVDraftingFoundationModels` |

**`PrestoCVWorkflowPorts`**
- The ports that view models consume: `CVEditing` (new, save, load) and `CVExporting` (untyped `throws`, so cancellation passes through).
- App value types: `ExportOutcome`, `ExportFailure`.

**`PrestoCVIntegration`**
- **Workflows**, implementing the ports:
  - `EditCVWorkflow`;
  - `ExportCVWorkflow`: from the editor snapshot, with the document language, through the renderer, then the completeness check on the actual PDF;
  - `BrowseDesigns`;
  - `DraftCVWithAI`: availability, then draft, then an unsaved CV plus its gaps.
- **Mappers:** `CV → CVDocument` and `CVDraft → CV`. They are exhaustive and deterministic, with typed dates. The draft mapper uses `Period.make` and reports every gap.

**`PrestoCVPresentation`**
- `@Observable @MainActor` view models whose public API holds presentation types only: status enums, and no domain types.
- **Saves** are serialised and coalesced, and every caller waits for its own edits to land.
- **Save and export** each have their own status, reset when a new intent starts.
- **Conflict** offers reload or save as a copy; **deleted elsewhere** offers save as a copy.
- **View-model initialisers do no I/O.** Loading happens in the view's `.task`, so the factory can be called on every view init.

**`PrestoCVComposition`**
- The only place that creates infrastructure (R4). The `@main` App type holds it in a `static let`. It owns:
  - file locations under Application Support;
  - one `FileCVRepository` and one `FileDesignStore`;
  - the web-view rule list, compiled once;
  - the platform renderer and the PDFKit inspector;
  - the AI adapter, `TimeSource`, `IDGenerator` and logger;
  - the `ScreenFactory`.
- **UI tests and previews** use the production `FileCVRepository` on a temporary directory seeded from fixture JSON. A launch argument selects it. No production target depends on a test-support target.

**Test support.** `PrestoCVAppTestSupport` holds fakes for the workflow ports.

---

## Xcode app target `PrestoCV` (iOS 26, macOS 26)

A native SwiftUI multiplatform target ([ADR 0004](adr/0004-native-multiplatform-app.md)). The checker maps each folder as its own target.

| Folder | Contents | May import |
|---|---|---|
| `App/` | `@main` (holds the composition), scenes and macOS commands; `#if os` allowed here | SwiftUI, `PrestoCVComposition`, `PrestoCVPresentation` |
| `Features/` | SwiftUI views per screen; `NavigationSplitView` navigation; no `#if` | SwiftUI, `PrestoCVPresentation` |
| `DesignSystem/` | tokens and reusable components | SwiftUI |
| `Platform/` | the platform shims: iOS-only modifiers wrapped for `Features/`, HTML and PDF previews, sharing, pasteboard, file import and export | SwiftUI, UIKit, AppKit, WebKit, PDFKit, QuickLook, UniformTypeIdentifiers, `CVRenderingWebKitSupport`, `PrestoCVPresentation` |
| `Resources/` | `Localizable.xcstrings`, sample CV JSON, assets | — |

---

## Dependency graph (summary)

```
PrestoCV (app) ─▶ PrestoCVPresentation ─▶ PrestoCVWorkflowPorts ─▶ PrestoCVApplication ─▶ PrestoCVDomain
     │                                     ▲
     │                     PrestoCVIntegration ┴─▶ CVRendering ─┬─▶ CVDocumentModel
     │                                    │                └─▶ CVDesignCatalog
     │                                    └─▶ CVDrafting
     └────▶ PrestoCVComposition ─▶ (all of the above) + PrestoCVPersistence, CVDesignCatalogFileStore, CVBundledDesigns,
                                CVRenderingWebKitSupport, CVRenderingIOS | CVRenderingMacOS,
                                CVRenderingPDFKitInspector, CVDraftingFoundationModels

Forbidden: any edge between PrestoCVCore, CVPDFExporter and CVGeneratorAI.
Forbidden: any edge from a domain, application or port target to an adapter target.
Forbidden: PrestoCVPresentation → PrestoCVIntegration.
```
