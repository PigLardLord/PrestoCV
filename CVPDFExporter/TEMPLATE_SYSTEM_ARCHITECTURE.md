# .mcvt Template Delivery System Architecture

## Overview

The .mcvt (CV Template) system provides a flexible, extensible architecture for CV template distribution and management. It follows Clean Architecture principles with clear separation between domain logic, use cases, and infrastructure.

## Architecture Layers

### 1. Domain Layer

#### TemplateManifest
**Location**: `Sources/CVPDFExporter/Templates/Domain/TemplateManifest.swift`

Template metadata stored in `manifest.json` within .mcvt packages.

**Properties**:
- `id`: Unique template identifier
- `name`: Display name
- `description`: Template description
- `author`: Creator name
- `version`: Semantic version (e.g., "1.0.0")
- `previewImage`: Preview image filename
- `price`: Cost (0.0 for free templates)

**Validation**:
- ID, name, version cannot be empty/whitespace
- Price must be non-negative

#### TemplatePackage
**Location**: `Sources/CVPDFExporter/Templates/Domain/TemplatePackage.swift`

Container for .mcvt package contents.

**Properties**:
- `manifest`: TemplateManifest
- `cssContent`: Required CSS styles
- `htmlContent`: Optional custom HTML (uses base template if nil)
- `previewImageBase64`: Optional base64 PNG preview, at the top level of the file. Older packages keep it in the
  manifest; `embeddedPreviewBase64` returns whichever the package has

**Validation**:
- Manifest must be valid
- CSS content cannot be empty

### 2. Repository Layer

#### TemplateRepositoryProtocol
**Location**: `Sources/CVPDFExporter/Domain/Protocols/TemplateRepositoryProtocol.swift`

**Interface**:
```swift
func getTemplates() async throws -> [Template]
func getTemplate(id: String) async throws -> Template?
func installTemplate(_ package: TemplatePackage) async throws
```

#### BundledTemplateRepository
**Location**: `Sources/CVPDFExporter/Templates/TemplateRepository.swift`

Provides built-in templates (Professional, Modern, Minimal).
- Read-only (installation throws error)
- Delegates to a `FileTemplateRepository` in Application Support (`PrestoCV/Templates`), whose registry
  `TemplateBootstrapService` fills at launch; a template is listed only once it is registered
- If that storage cannot be opened, the error is thrown when templates are requested, not when the repository is created
- `loadTemplate(id:)` (async, from `TemplateRepositoryProtocol`) throws `TemplateError.templateNotFound` for an unknown id

#### FileTemplateRepository
**Location**: `Sources/CVPDFExporter/Templates/Repository/FileTemplateRepository.swift`

Manages .mcvt packages from file system.

**Features**:
- Loads packages from designated directory
- Auto-creates directory if missing
- Decodes JSON-encoded packages
- Gracefully skips corrupted files
- Composes the page of each package (`TemplatePackage.composedHTML`)
- Thread-safe operations
- `installTemplate` writes the package, caches its preview image as `<id>_preview.png` in the registry's directory
  and upserts the registry entry, replacing an installed version; the entry is written last. The entry's
  `previewPath` is relative to that directory and `TemplateRegistryManager.previewURL(for:)` resolves it

**Directory Structure**:
```
~/Documents/PrestoCV/Templates/
  ├── modern-gradient.mcvt
  ├── creative-bold.mcvt
  └── minimal-clean.mcvt
```

#### TemplateBootstrapService
**Location**: `Sources/CVPDFExporter/Templates/Services/TemplateBootstrapService.swift`

Installs the packages in the module's `Resources/Templates/Bundled` at app launch (`syncBundledTemplates()`).
- Installs a package that is not registered, and replaces an installed one only when its version is higher
- Processes professional, modern and minimal in that order, then any other package by file name, so the template the
  export sheet preselects does not depend on the file system
- A package that cannot be installed is logged and skipped; the others are still installed

### 3. Use Case Layer

#### GetAvailableTemplatesUseCase
**Location**: `Sources/CVPDFExporter/Domain/UseCases/GetAvailableTemplatesUseCase.swift`

Coordinates template retrieval from multiple repositories.

**Features**:
- Combines templates from bundled, file, and remote sources
- Removes duplicates by ID
- First repository wins for duplicates
- Gracefully handles repository failures
- Returns partial results on errors

**Usage**:
```swift
let useCase = GetAvailableTemplatesUseCase(repositories: [
    bundledRepo,
    fileRepo,
    remoteRepo
])
let templates = try await useCase.execute()
```

#### InstallTemplateUseCase
**Location**: `Sources/CVPDFExporter/Domain/UseCases/InstallTemplateUseCase.swift`

Validates and installs template packages.

**Validation Steps**:
1. Package validation (manifest + CSS)
2. Duplicate ID check
3. Repository installation

**Error Types**:
- `TemplateInstallationError.invalidPackage`: Validation failure
- `TemplateInstallationError.duplicateTemplateID`: ID conflict
- `TemplateInstallationError.repositoryError`: I/O or storage error

**Usage**:
```swift
let useCase = InstallTemplateUseCase(repository: fileRepo)
try await useCase.execute(package: templatePackage)
```

## .mcvt Package Format

### File Structure
```
template-name.mcvt (JSON file)
{
  "manifest": {
    "id": "modern-gradient",
    "name": "Modern Gradient",
    "description": "Contemporary design with gradient header",
    "author": "Designer Name",
    "version": "1.0.0",
    "previewImage": "preview.png",
    "price": 0.0
  },
  "cssContent": "/* CSS styles */",
  "htmlContent": null  // Optional; the page of the package. Uses the base template if null
}
```

### Distribution Methods
1. **AirDrop**: Share .mcvt files between devices
2. **File Import**: Import from Files app
3. **Remote Download**: Future implementation via RemoteTemplateRepository
4. **Email/Messages**: Attach .mcvt files

## Template Rendering Flow

1. **Template Selection**: User chooses template via GetAvailableTemplatesUseCase
2. **Page**: the package's `htmlContent`, or the base template when it has none, with the package's `cssContent` in the `{{customCSS}}` slot (`TemplatePackage.composedHTML`)
3. **Localization**: TemplateLocalizer replaces the `{{i18n_*}}` placeholders with the headings of the document's language (English, Italian, German, Spanish, French, Portuguese; any other language gets English)
4. **Data Binding**: TemplateEngine injects CV data into the template. Text from the CV is escaped, braces included, so it is never read as a template tag
5. **PDF Generation**: HTMLToPDFRenderer converts to PDF

### Page breaks

The iOS renderer paginates with `UIPrintPageRenderer`, which keeps a block whole for `break-inside: avoid` and keeps the first and the last lines of a block together for `orphans` and `widows`, but does not honour `break-after: avoid`: a title would stay alone at the foot of a page. The bundled designs therefore:

- print each entry of work experience, education and certifications as one block of inline content, whose first lines stay together (`orphans: 3`, `widows: 3`) and flow over the page break; a long entry is cut, a short one is not;
- print the title of such a section as the first line of its first entry. The engine flags that entry with `isFirst`: `{{#isFirst}}<span class="section-title">…</span>{{/isFirst}}`;
- keep a small section (skills, languages, interests, social links) whole with `break-inside: avoid`, and a certificate;
- space blocks with a margin above each block that follows another, never below, so that the end of the CV has no margin to push an empty page out;
- let a web address break after its slashes: the engine puts a `<wbr>` after each slash that follows a name, and the designs use `overflow-wrap: anywhere` for an address longer than its column.

`PageBreakManager` adds forced breaks (`.page-break`) and `.avoid-break`, and nothing that makes a section or an entry unbreakable.

### A short CV on one page

A short CV often runs over one page by a few lines, and its last sections, kept whole, would then be alone on a second page. `OnePageFit` says how the iOS renderer prints such a CV on one page instead. A CV is a candidate when it takes two pages with the design's own spacing; a CV of one page, or of three or more, is printed once, as its design lays it out.

The renderer tries two steps on a candidate, lightest first, and keeps the first print that takes one page:

1. **Tightening** (class `fit-one-page` on the root element): the space between blocks and between lines closes up a little. The foot margin of the page stays.
2. **Compact** (classes `fit-one-page` and `fit-one-page-compact`): the space closes up to the least that is still easy to read; the small lists (languages, profiles, certificates) of the designs that stack them run along a line instead of down a column; and the margin at the foot of the page shrinks from the page's margin to `OnePageFit.minimumBottomMargin`, which is 10 mm.

A CV that no step brings onto one page is printed as its design lays it out. That print is drawn before the page changes, so it is the same, page for page, as without `OnePageFit`: a long CV keeps its page breaks, and so does a CV of two pages that is too long to fit.

What a step never does:
- change the size of the text, narrow the page's side margins or the text column, or scale the page;
- set the lines closer than 1.2 times the size of the text;
- take the margin at the foot of the page below 10 mm.

The text of the compact print reads in the order of the design's own print: an item that a design stacks, such as a profile's platform over its address, is set on one line so that the platform comes before its address. WebKit prints Modern scaled to fit, and the scale follows the height of the printable area, so its text comes out a fraction of a percent smaller when the foot margin shrinks (the name is 28.9 pt instead of 29.0 pt), as it does for any change of the page's margin without a step; the CSS sets the same sizes.

Each bundled design says how it tightens, with rules under `html.fit-one-page` and `html.fit-one-page-compact`; a rule of a step starts at the root element, so it cannot reach a page that is not tightened. `OnePageFitTests` holds the designs to what they may set (spacing and the layout of lists, never a font size, a width or a transform), to the line height and to the least space they keep between sections and entries, and they read the cascade to hold Modern's first entry of a section flush under its heading in every step. A design without such rules is printed as it lays itself out. The version of a design goes up when its rules change, so that an installed copy is replaced.

### Regenerating the thumbnails

The template carousel of the export sheet shows the `previewImageBase64` of each bundled package. It is the first page of the PDF of the example CV (`SampleCVData.complete`) that the real renderer makes with the options of the export sheet, one pixel per point (595 × 842). Regenerate it whenever the look of a design changes:

```
xcodebuild test -project PrestoCV.xcodeproj -scheme PrestoCV -destination '<an iOS simulator>' \
  -only-testing:PrestoCVTests/BundledDesignThumbnails TEST_RUNNER_PRESTOCV_REGENERATE_THUMBNAILS=1
```

Without the variable the test is skipped. With it, each design is rendered and its `previewImageBase64` is rewritten in `CVPDFExporter/Resources/Templates/Bundled/<design>.mcvt`, the rest of the file untouched (the path comes from the test's own location, so the checkout that was built is the one that changes). Then raise the `version` of the designs whose thumbnail changed: an installed copy is only replaced by a newer version. `BundledThumbnailTests` checks that every thumbnail is a PNG of 595 × 842 pixels.

## Testing Strategy

### Test Coverage
- **Domain Models**: 15 tests (TemplateManifest, TemplatePackage)
- **Repository Protocol**: 7 tests (protocol conformance, error handling)
- **FileTemplateRepository**: 9 tests (loading, installation, error handling)
- **GetAvailableTemplatesUseCase**: 8 tests (multi-repo, duplicates, failures)
- **InstallTemplateUseCase**: 8 tests (validation, duplicates, errors)
- **Template Validator**: 15 tests (field validation, template verification)

**Total: 62 tests passing**

### TDD Approach
All components developed using Red-Green-Refactor:
1. RED: Write failing test
2. GREEN: Implement minimal code to pass
3. REFACTOR: Clean up and optimize
4. COMMIT: Only when tests pass

## Error Handling

### TemplateRepositoryError
```swift
enum TemplateRepositoryError: Error {
    case templateNotFound(String)
    case invalidPackage(String)
    case ioError(String)
}
```

### TemplateInstallationError
```swift
enum TemplateInstallationError: Error {
    case invalidPackage(String)
    case duplicateTemplateID(String)
    case repositoryError(String)
}
```

### Error Recovery Strategy
- Repository failures: Continue with working repositories
- Validation failures: Fail fast with clear messages
- I/O errors: Wrap with context for debugging

## Future Enhancements

### Phase 4: iOS Integration (Pending)
- [ ] Register .mcvt UTType in Info.plist
- [ ] Document type handler for AirDrop/Files integration
- [ ] Share sheet support

### Phase 5: Localization (Done)
- [x] TemplateLocalizer service
- [x] i18n placeholder replacement ({{i18n_work_experience}})
- [x] Multi-language support

### Phase 6: Template Refactoring (Pending)
- [ ] Extract BaseHTMLTemplate with placeholders
- [ ] Refactor existing templates to CSS-only
- [ ] Update TemplateValidator for package validation

### Phase 7: Remote Repository (Future)
- [ ] RemoteTemplateRepository implementation
- [ ] Template marketplace backend
- [ ] Authentication and payment integration

## SOLID Principles Applied

### Single Responsibility
- `TemplateManifest`: Only metadata representation
- `FileTemplateRepository`: Only file-based template management
- `InstallTemplateUseCase`: Only installation coordination

### Open/Closed
- TemplateRepositoryProtocol: Open for extension (new repository types)
- Closed for modification (interface stable)

### Liskov Substitution
- All repositories interchangeable via protocol
- Use cases work with any conforming repository

### Interface Segregation
- Focused protocols (no god interfaces)
- Clients depend only on methods they use

### Dependency Inversion
- Use cases depend on TemplateRepositoryProtocol (abstraction)
- Not on concrete FileTemplateRepository (implementation)

## Performance Considerations

### File I/O
- Lazy loading: Templates loaded on-demand
- Caching: Future enhancement for frequently accessed templates
- Batch operations: getTemplates() loads all at once

### Concurrency
- Thread-safe: All repositories use @unchecked Sendable
- Async/await: Non-blocking I/O operations
- Graceful failures: Partial results on repository errors

### Memory Management
- Lightweight models: Codable structs
- No retain cycles: Value types throughout
- Efficient JSON decoding: Streaming when available

## Security Considerations

### Package Validation
- Strict manifest validation before installation
- CSS sanitization: Future enhancement
- No arbitrary code execution (CSS-only)

### File System
- Sandboxed directory access
- User-writable templates directory only
- No system file modifications

### Future Security Features
- Package signing for verified authors
- Checksum validation for integrity
- Malicious CSS pattern detection

## Documentation for Template Creators

### Creating a .mcvt Template

#### Step 1: Design the CSS
Create your template styles focusing on print media:
```css
@media print {
  body { font-size: 11pt; }
  .cv-header { page-break-after: avoid; }
}
```

#### Step 2: Test with Base HTML
Templates use the base HTML structure with your CSS injected.

#### Step 3: Create manifest.json
```json
{
  "id": "unique-template-id",
  "name": "Display Name",
  "description": "Brief description",
  "author": "Your Name",
  "version": "1.0.0",
  "previewImage": "preview.png",
  "price": 0.0
}
```

#### Step 4: Package as .mcvt
Create JSON file containing manifest and CSS:
```json
{
  "manifest": { ... },
  "cssContent": "/* your CSS */",
  "htmlContent": null
}
```

#### Step 5: Distribute
Share via AirDrop, email, or upload to template marketplace.

## Troubleshooting

### Template Not Loading
- Check file extension is .mcvt
- Verify JSON is valid
- Ensure manifest ID is unique
- Check CSS is not empty

### Installation Fails
- Check for duplicate template ID
- Verify manifest fields not empty
- Ensure price is non-negative
- Check file permissions

### Template Rendering Issues
- Validate Mustache placeholders
- Check CSS print media queries
- Verify page break settings

## Version History

### v1.0.0 (Current)
- Initial .mcvt system implementation
- Domain models (Manifest, Package)
- Repository layer (Bundled, File)
- Use cases (GetAvailable, Install)
- Comprehensive test coverage (62 tests)
- TDD methodology throughout

### Future Versions
- v1.1.0: iOS integration + UTType registration
- v1.2.0: Localization system
- v1.3.0: Template marketplace
- v2.0.0: Remote repository + authentication
