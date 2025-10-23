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
- Templates loaded at initialization
- No file I/O during operation

#### FileTemplateRepository
**Location**: `Sources/CVPDFExporter/Templates/Repository/FileTemplateRepository.swift`

Manages .mcvt packages from file system.

**Features**:
- Loads packages from designated directory
- Auto-creates directory if missing
- Decodes JSON-encoded packages
- Gracefully skips corrupted files
- Generates base HTML for CSS-only packages
- Thread-safe operations

**Directory Structure**:
```
~/Documents/PrestoCV/Templates/
  ├── modern-gradient.mcvt
  ├── creative-bold.mcvt
  └── minimal-clean.mcvt
```

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
  "htmlContent": null  // Optional, uses base template if null
}
```

### Distribution Methods
1. **AirDrop**: Share .mcvt files between devices
2. **File Import**: Import from Files app
3. **Remote Download**: Future implementation via RemoteTemplateRepository
4. **Email/Messages**: Attach .mcvt files

## Template Rendering Flow

1. **Template Selection**: User chooses template via GetAvailableTemplatesUseCase
2. **Data Binding**: TemplateEngine injects CV data into template
3. **Localization**: TemplateLocalizer replaces i18n placeholders (future)
4. **PDF Generation**: HTMLToPDFRenderer converts to PDF

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

### Phase 5: Localization (Pending)
- [ ] TemplateLocalizer service
- [ ] i18n placeholder replacement ({{i18n_work_experience}})
- [ ] Multi-language support

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
