# Template Delivery Uniformization - Implementation Plan

**Status**: 🔴 NOT STARTED
**Last Updated**: 2025-01-25
**Estimated Completion**: 0% (0/16 steps)

---

## 🎯 Objective

Refactor template delivery system from hardcoded HTML strings to a uniform .mcvt package format with:
- Standard shared HTML template (CSS-only customization)
- Embedded base64 preview images in .mcvt packages
- Template registry/cache (templates.json) for fast lookups
- Async repository pattern for future remote/local implementations
- Two-tier storage: bundled (app) + user (Application Support)

---

## 📋 Architecture Principles (MUST FOLLOW)

### 1. **TDD Approach** ✅
- Write tests FIRST before implementation
- Run tests after EVERY change
- Commit ONLY when ALL tests are GREEN (62+ tests passing)
- Never skip test coverage

### 2. **SOLID Principles** 🏗️
- **S**ingle Responsibility: Each class has one clear purpose
- **O**pen/Closed: Extend via protocols, don't modify existing
- **L**iskov Substitution: Implementations interchangeable via protocols
- **I**nterface Segregation: Small, focused protocols
- **D**ependency Inversion: Depend on protocols, not concrete classes

### 3. **Clean Architecture** 🧹
- **Domain**: Models, protocols (no dependencies)
- **Use Cases**: Business logic (depends on domain only)
- **Infrastructure**: Repositories, managers (implements domain protocols)
- **Presentation**: ViewModels, Views (depends on use cases)

### 4. **Dependency Injection** 💉
- Constructor injection for all dependencies
- Use DependencyContainer pattern
- No singletons or static dependencies
- Testable via protocol mocking

### 5. **Async/Await** ⏳
- ALL repository methods must be `async`
- Use structured concurrency (Task, TaskGroup)
- Proper error handling with typed errors

---

## 📦 .mcvt Package Format (Final Specification)

```json
{
  "manifest": {
    "id": "modern",
    "name": "Modern",
    "description": "Contemporary design with clean lines and modern typography",
    "author": "PrestoCV Team",
    "version": "1.0.0",
    "previewImageBase64": "iVBORw0KGgoAAAANSUhEUgAA..."
  },
  "cssContent": "/* All CSS styling here */\n:root { ... }",
  "htmlContent": null
}
```

**Key Points**:
- `previewImageBase64`: PNG encoded as base64 string (embedded in package)
- `cssContent`: Required, contains all styling
- `htmlContent`: Optional, null = use StandardTemplate.html

---

## 🗂️ Directory Structure

```
CVPDFExporter/
├── Resources/
│   ├── StandardTemplate.html          # NEW: Shared HTML template
│   └── BundledTemplates/              # NEW: Bundled .mcvt packages
│       ├── modern.mcvt
│       ├── professional.mcvt
│       └── minimal.mcvt
├── Sources/CVPDFExporter/Templates/
│   ├── Domain/
│   │   ├── TemplatePackage.swift      # MODIFY: Add previewImageBase64
│   │   ├── TemplateRegistry.swift     # NEW: Registry models
│   │   └── TemplateRepositoryProtocol.swift  # MODIFY: Add async
│   ├── Infrastructure/
│   │   └── TemplateRegistryManager.swift  # NEW: Registry management
│   └── Repository/
│       ├── BundledTemplateRepository.swift  # MODIFY: Load from .mcvt
│       └── FileTemplateRepository.swift     # MODIFY: Use registry
└── Tests/
    └── CVPDFExporterTests/
        ├── TemplateRegistryTests.swift    # NEW
        └── [Update all existing tests]     # MODIFY: async/await

~/Library/Application Support/PrestoCV/
├── Templates/              # User-installed .mcvt files
├── TemplateCache/          # Extracted preview PNGs
└── templates.json          # Registry cache
```

---

## 🗄️ Template Registry Format (templates.json)

```json
{
  "templates": [
    {
      "id": "modern",
      "name": "Modern",
      "description": "Contemporary design with clean lines",
      "version": "1.0.0",
      "source": "bundled",
      "packagePath": "/path/to/modern.mcvt",
      "previewPath": "/path/to/cache/modern_preview.png",
      "lastModified": "2025-01-25T10:30:00Z"
    },
    {
      "id": "user-custom",
      "name": "My Custom Template",
      "description": "Imported via AirDrop",
      "version": "1.0.0",
      "source": "user",
      "packagePath": "/path/to/user-custom.mcvt",
      "previewPath": "/path/to/cache/user-custom_preview.png",
      "lastModified": "2025-01-25T14:20:00Z"
    }
  ],
  "lastUpdate": "2025-01-25T14:20:00Z"
}
```

**Purpose**: Fast template lookups without directory scanning

---

## 📝 Implementation Steps (Sequential - Update Progress)

### ✅ Step 1: Create StandardTemplate.html [✅ COMPLETE]

**File**: `CVPDFExporter/Sources/CVPDFExporter/Templates/BaseHTMLTemplate.swift`

**Description**: Create shared HTML template used by all templates (unless overridden)

**Requirements**:
- Complete HTML structure with `<!DOCTYPE html>` ✅
- All Mustache variables: `{{name}}`, `{{email}}`, `{{phone}}`, `{{location}}`, etc. ✅
- All sections: work experience, education, skills, certifications, languages, social links, interests ✅
- Conditional rendering: `{{#hasPhone}}`, `{{#hasWorkExperience}}`, etc. ✅
- CSS variables injection: `{{colorPrimary}}`, `{{fontHeading}}`, `{{fontSize}}`, etc. ✅
- Support for `{{i18n_*}}` localization placeholders ✅
- Clean, semantic HTML5 structure ✅
- `{{customCSS}}` injection point for template customization ✅

**Tests**: Not applicable (resource file)

**Commit Message**: N/A (already exists)

**Status**: ✅ COMPLETE (BaseHTMLTemplate already implemented)

**Notes**: The `BaseHTMLTemplate.swift` file already exists and provides exactly what we need. Modern, Professional, and Minimal templates already use it with CSS injection.

---

### ✅ Step 2: Update TemplatePackage Domain Model [✅ COMPLETE]

**File**: `CVPDFExporter/Sources/CVPDFExporter/Templates/Domain/TemplateManifest.swift`

**Description**: Add support for embedded preview images

**Changes**:
```swift
public struct TemplateManifest: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let author: String
    public let version: String
    public let previewImage: String
    public let previewImageBase64: String?  // ✅ ADDED
    public let price: Double
    // ... existing fields
}
```

**Tests**:
1. Test decoding manifest with `previewImageBase64` ✅
2. Test decoding manifest without `previewImageBase64` (backward compatibility) ✅
3. Test encoding/decoding round-trip with base64 preview ✅
4. Test TemplatePackage with base64 preview ✅
5. Test nil base64 preview (backward compatibility) ✅

**Test File**: `CVPDFExporterTests/TemplatePackageTests.swift` (5 new tests added)

**Test Results**: ✅ ALL 263 tests passing

**Commit Message**: "feat: Add previewImageBase64 to TemplateManifest for embedded previews

Add optional base64-encoded preview image field to TemplateManifest.
This allows templates to be self-contained with embedded preview images.
Maintains backward compatibility with existing templates.

Implementation Plan: Step 2 - Update TemplatePackage Domain Model
Status: 2/16 steps completed
Tests: All passing (263 tests)"

**Status**: ✅ COMPLETE

---

### ✅ Step 3: Create TemplateRegistry Domain Models [NOT STARTED]

**File**: `CVPDFExporter/Sources/CVPDFExporter/Templates/Domain/TemplateRegistry.swift`

**Description**: Create domain models for template registry/cache system

**Models to Create**:
```swift
public struct TemplateRegistry: Codable, Equatable, Sendable {
    public var templates: [TemplateEntry]
    public var lastUpdate: Date

    public init(templates: [TemplateEntry] = [], lastUpdate: Date = Date())
}

public struct TemplateEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let version: String
    public let source: TemplateSource
    public let packagePath: String
    public let previewPath: String?
    public let lastModified: Date

    public init(...)  // Full initializer
}

public enum TemplateSource: String, Codable, Sendable {
    case bundled
    case user
}
```

**Tests**:
1. Test TemplateRegistry encoding/decoding
2. Test TemplateEntry encoding/decoding
3. Test TemplateSource cases
4. Test Equatable conformance
5. Test empty registry initialization

**Test File**: `CVPDFExporterTests/TemplateRegistryTests.swift` (NEW)

**Commit Message**: "Add TemplateRegistry domain models"

**Status**: ❌ NOT STARTED

---

### ✅ Step 4: Create TemplateRegistryManager Protocol [NOT STARTED]

**File**: `CVPDFExporter/Sources/CVPDFExporter/Templates/Domain/TemplateRegistryProtocol.swift`

**Description**: Define protocol for registry management (domain layer)

**Protocol**:
```swift
public protocol TemplateRegistryProtocol: Sendable {
    func loadRegistry() async throws -> TemplateRegistry
    func saveRegistry(_ registry: TemplateRegistry) async throws
    func addTemplate(_ entry: TemplateEntry) async throws
    func removeTemplate(id: String) async throws
    func getTemplate(id: String) async throws -> TemplateEntry?
    func getAllTemplates() async throws -> [TemplateEntry]
    func refreshRegistry() async throws -> TemplateRegistry
    func extractPreview(from base64: String, templateId: String) async throws -> URL
}
```

**Tests**: Mock implementation tests

**Commit Message**: "Add TemplateRegistryProtocol"

**Status**: ❌ NOT STARTED

---

### ✅ Step 5: Implement TemplateRegistryManager [NOT STARTED]

**File**: `CVPDFExporter/Sources/CVPDFExporter/Templates/Infrastructure/TemplateRegistryManager.swift`

**Description**: Implement registry management (infrastructure layer)

**Requirements**:
- Read/write `templates.json` from Application Support
- Extract base64 preview → save PNG to TemplateCache/
- Add/remove template entries
- Refresh registry by scanning directories
- Thread-safe operations (actor pattern)
- Dependency injection (FileManager protocol)

**Implementation**:
```swift
public actor TemplateRegistryManager: TemplateRegistryProtocol {
    private let fileManager: FileManagerProtocol
    private let registryURL: URL
    private let cacheDirectoryURL: URL

    public init(fileManager: FileManagerProtocol = FileManager.default) async throws {
        // Initialize directories
        // Create Application Support/PrestoCV/ structure
    }

    // Implement all protocol methods
}
```

**Tests**:
1. Test registry creation on first launch
2. Test loading existing registry
3. Test saving registry
4. Test adding template entry
5. Test removing template entry
6. Test base64 preview extraction
7. Test cache directory creation
8. Test refresh registry (scan directories)

**Test File**: `CVPDFExporterTests/TemplateRegistryManagerTests.swift` (NEW)

**Commit Message**: "Implement TemplateRegistryManager with preview extraction"

**Status**: ❌ NOT STARTED

---

### ✅ Step 6: Update TemplateRepositoryProtocol to Async [NOT STARTED]

**File**: `CVPDFExporter/Sources/CVPDFExporter/Templates/Repository/TemplateRepositoryProtocol.swift`

**Description**: Make all repository methods async

**Changes**:
```swift
public protocol TemplateRepositoryProtocol: Sendable {
    func getTemplates() async throws -> [Template]
    func getTemplate(id: String) async throws -> Template?
    func installTemplate(_ package: TemplatePackage) async throws
    func refreshRegistry() async throws  // ✅ ADD THIS
}
```

**Tests**: Update all repository tests to use async/await

**Test Files**: All repository test files

**Commit Message**: "Update TemplateRepositoryProtocol to async/await"

**Status**: ❌ NOT STARTED

---

### ✅ Step 7: Extract CSS from Existing Templates [NOT STARTED]

**Files**:
- `CVPDFExporter/Sources/CVPDFExporter/Templates/ModernHTMLTemplate.swift`
- `CVPDFExporter/Sources/CVPDFExporter/Templates/ProfessionalHTMLTemplate.swift`
- `CVPDFExporter/Sources/CVPDFExporter/Templates/MinimalHTMLTemplate.swift`

**Description**: Extract CSS-only content from each template

**Process**:
1. Read current HTML from each template
2. Extract `<style>` block content
3. Save CSS to temporary files:
   - `modern_extracted.css`
   - `professional_extracted.css`
   - `minimal_extracted.css`

**Tests**: Not applicable (manual extraction)

**Commit Message**: "Extract CSS from templates for .mcvt conversion"

**Status**: ❌ NOT STARTED

---

### ✅ Step 8: Generate Preview Images [NOT STARTED]

**Tools**: Use PDF rendering or screenshot

**Description**: Create preview PNG for each template (800x1000px)

**Process**:
1. Render each template with sample data
2. Export as PNG (800x1000px)
3. Save as:
   - `modern_preview.png`
   - `professional_preview.png`
   - `minimal_preview.png`
4. Convert to base64 for embedding

**Tests**: Not applicable (manual generation)

**Commit Message**: "Generate preview images for bundled templates"

**Status**: ❌ NOT STARTED

---

### ✅ Step 9: Create .mcvt Package Files [NOT STARTED]

**Directory**: `CVPDFExporter/Resources/BundledTemplates/`

**Files to Create**:
- `modern.mcvt`
- `professional.mcvt`
- `minimal.mcvt`

**Content Format** (example for modern.mcvt):
```json
{
  "manifest": {
    "id": "modern",
    "name": "Modern",
    "description": "Contemporary design with clean lines and modern typography",
    "author": "PrestoCV Team",
    "version": "1.0.0",
    "previewImageBase64": "iVBORw0KGgo..."
  },
  "cssContent": "/* Extracted CSS from Step 7 */",
  "htmlContent": null
}
```

**Validation**:
- JSON is valid
- Base64 preview decodes to valid PNG
- CSS content is not empty
- Manifest fields are complete

**Tests**: TemplatePackage decoding tests

**Commit Message**: "Create bundled .mcvt template packages"

**Status**: ❌ NOT STARTED

---

### ✅ Step 10: Update BundledTemplateRepository [NOT STARTED]

**File**: `CVPDFExporter/Sources/CVPDFExporter/Templates/TemplateRepository.swift`

**Description**: Load templates from bundled .mcvt files instead of hardcoded HTML

**Changes**:
```swift
public final class BundledTemplateRepository: TemplateRepositoryProtocol, @unchecked Sendable {
    private let standardHTML: String
    private let registryManager: TemplateRegistryProtocol

    public init(registryManager: TemplateRegistryProtocol) async throws {
        self.registryManager = registryManager
        self.standardHTML = try Self.loadStandardHTML()

        // Load and register bundled templates on first launch
        try await self.registerBundledTemplates()
    }

    private static func loadStandardHTML() throws -> String {
        // Load from Bundle.module.url(forResource: "StandardTemplate", withExtension: "html")
    }

    private func registerBundledTemplates() async throws {
        // Load .mcvt files from BundledTemplates/
        // Register each in templates.json
        // Extract previews
    }

    public func getTemplates() async throws -> [Template] {
        let entries = try await registryManager.getAllTemplates()
        return try await entries
            .filter { $0.source == .bundled }
            .asyncMap { try await self.loadTemplate(from: $0) }
    }

    public func getTemplate(id: String) async throws -> Template? {
        guard let entry = try await registryManager.getTemplate(id: id),
              entry.source == .bundled else {
            return nil
        }
        return try await loadTemplate(from: entry)
    }

    private func loadTemplate(from entry: TemplateEntry) async throws -> Template {
        // Load .mcvt package
        // If htmlContent is nil, use standardHTML
        // Build Template object
    }

    public func installTemplate(_ package: TemplatePackage) async throws {
        throw TemplateRepositoryError.ioError("Cannot install into bundled repository")
    }

    public func refreshRegistry() async throws {
        try await registerBundledTemplates()
    }
}
```

**Requirements**:
- Dependency injection (registryManager)
- Load StandardTemplate.html from bundle
- Load .mcvt files from BundledTemplates/
- Use standardHTML when htmlContent is nil
- Register templates on first launch
- Extract and cache previews

**Tests**:
1. Test loading StandardTemplate.html
2. Test loading bundled .mcvt files
3. Test template registration
4. Test preview extraction
5. Test getTemplates() returns all bundled
6. Test getTemplate(id:) returns specific template
7. Test htmlContent=null uses standardHTML
8. Test installTemplate() throws error

**Test File**: `CVPDFExporterTests/BundledTemplateRepositoryTests.swift` (UPDATE)

**Commit Message**: "Refactor BundledTemplateRepository to load from .mcvt packages"

**Status**: ❌ NOT STARTED

---

### ✅ Step 11: Update FileTemplateRepository [NOT STARTED]

**File**: `CVPDFExporter/Sources/CVPDFExporter/Templates/Repository/FileTemplateRepository.swift`

**Description**: Use registry for fast lookups and support user templates directory

**Changes**:
```swift
public final class FileTemplateRepository: TemplateRepositoryProtocol {
    private let registryManager: TemplateRegistryProtocol
    private let userTemplatesDirectory: URL
    private let standardHTML: String

    public init(
        registryManager: TemplateRegistryProtocol,
        userTemplatesDirectory: URL
    ) async throws {
        self.registryManager = registryManager
        self.userTemplatesDirectory = userTemplatesDirectory
        self.standardHTML = try Self.loadStandardHTML()

        // Create user templates directory if needed
        try FileManager.default.createDirectory(
            at: userTemplatesDirectory,
            withIntermediateDirectories: true
        )
    }

    public func getTemplates() async throws -> [Template] {
        // Get all templates from registry (bundled + user)
        let entries = try await registryManager.getAllTemplates()
        return try await entries.asyncMap { try await loadTemplate(from: $0) }
    }

    public func getTemplate(id: String) async throws -> Template? {
        guard let entry = try await registryManager.getTemplate(id: id) else {
            return nil
        }
        return try await loadTemplate(from: entry)
    }

    public func installTemplate(_ package: TemplatePackage) async throws {
        // 1. Save .mcvt to userTemplatesDirectory
        // 2. Extract preview from base64
        // 3. Cache preview PNG
        // 4. Create TemplateEntry
        // 5. Add to registry
    }

    public func refreshRegistry() async throws {
        // Rescan userTemplatesDirectory
        // Update registry with new/removed templates
        try await registryManager.refreshRegistry()
    }

    private func loadTemplate(from entry: TemplateEntry) async throws -> Template {
        // Load .mcvt from entry.packagePath
        // If htmlContent is nil, use standardHTML
        // Build Template object
    }
}
```

**Requirements**:
- Use registry for all lookups (no directory scanning)
- Support both bundled and user templates
- installTemplate() saves to user directory
- Extract and cache preview during install
- Create user directory on init

**Tests**:
1. Test user directory creation
2. Test getTemplates() returns bundled + user
3. Test installTemplate() saves to user directory
4. Test preview extraction during install
5. Test registry update after install
6. Test refreshRegistry() scans user directory
7. Test loading template from registry entry

**Test File**: `CVPDFExporterTests/FileTemplateRepositoryTests.swift` (UPDATE)

**Commit Message**: "Update FileTemplateRepository with registry and user templates support"

**Status**: ❌ NOT STARTED

---

### ✅ Step 12: Update All Template Tests to Async [NOT STARTED]

**Files**: All test files in `CVPDFExporterTests/`

**Description**: Convert all repository tests to async/await syntax

**Changes**:
- Replace `XCTestExpectation` with `async/await`
- Update test methods: `func testName() async throws`
- Use `await` for all repository calls
- Update mock implementations

**Test Files**:
- `ModernTemplateTests.swift`
- `ProfessionalTemplateTests.swift`
- `MinimalTemplateTests.swift`
- `BundledTemplateRepositoryTests.swift`
- `FileTemplateRepositoryTests.swift`
- `TemplateEngineTests.swift`
- All other affected tests

**Verification**: Run `swift test` → all 62+ tests must pass

**Commit Message**: "Update all template tests to async/await syntax"

**Status**: ❌ NOT STARTED

---

### ✅ Step 13: Update Dependency Container [NOT STARTED]

**File**: `CVPDFExporter/Sources/CVPDFExporter/Presentation/CompositionRoot/PDFExportDependencyContainer.swift`

**Description**: Add factory methods for new dependencies

**Changes**:
```swift
public final class PDFExportDependencyContainer {

    public func makeTemplateRegistryManager() async throws -> TemplateRegistryProtocol {
        return try await TemplateRegistryManager()
    }

    public func makeBundledTemplateRepository() async throws -> TemplateRepositoryProtocol {
        let registryManager = try await makeTemplateRegistryManager()
        return try await BundledTemplateRepository(registryManager: registryManager)
    }

    public func makeFileTemplateRepository() async throws -> TemplateRepositoryProtocol {
        let registryManager = try await makeTemplateRegistryManager()
        let userDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrestoCV")
            .appendingPathComponent("Templates")
        return try await FileTemplateRepository(
            registryManager: registryManager,
            userTemplatesDirectory: userDir
        )
    }

    // Update existing factory methods to use async repositories
}
```

**Tests**: Update dependency container tests

**Commit Message**: "Update dependency container for async template repositories"

**Status**: ❌ NOT STARTED

---

### ✅ Step 14: Update Use Cases and ViewModels [NOT STARTED]

**Files**:
- Template-related use cases
- Template selection ViewModels

**Description**: Update to use async repository methods

**Changes**:
- Update all `repository.getTemplates()` calls to `await`
- Update all `repository.getTemplate(id:)` calls to `await`
- Wrap async calls in `Task { }`
- Handle errors appropriately

**Tests**: Update use case and ViewModel tests

**Commit Message**: "Update use cases and ViewModels for async template repositories"

**Status**: ❌ NOT STARTED

---

### ✅ Step 15: Update Documentation [NOT STARTED]

**Files**:
- `CVPDFExporter/TEMPLATE_SYSTEM_ARCHITECTURE.md`
- `CVPDFExporter/README.md`

**Description**: Comprehensive documentation of new template delivery system

**Content for TEMPLATE_SYSTEM_ARCHITECTURE.md**:
1. **Standard HTML Template**
   - Purpose and location
   - When it's used vs custom HTML
   - Mustache variables reference

2. **.mcvt Package Format**
   - JSON structure
   - manifest fields
   - Embedded base64 preview
   - cssContent requirements
   - htmlContent override

3. **Template Registry System**
   - templates.json format
   - Cache directory structure
   - Preview extraction workflow
   - Fast lookup benefits

4. **Two-Tier Template Storage**
   - Bundled templates (app bundle)
   - User templates (Application Support)
   - Template installation workflow
   - AirDrop/cloud sharing preparation

5. **Repository Architecture**
   - Async protocol design
   - BundledTemplateRepository
   - FileTemplateRepository
   - Future: RemoteTemplateRepository

6. **Directory Structure Diagram**

**Content for README.md**:
1. Template delivery overview
2. How to create custom templates
3. .mcvt package creation guide
4. Template sharing workflow

**Commit Message**: "Update documentation for template delivery system"

**Status**: ❌ NOT STARTED

---

### ✅ Step 16: Integration Testing and Cleanup [NOT STARTED]

**Description**: End-to-end testing and final cleanup

**Tasks**:
1. Run full test suite: `swift test` (all tests must pass)
2. Test template loading in actual app
3. Test template selection UI
4. Test PDF export with new templates
5. Verify preview images display correctly
6. Test template installation workflow
7. Remove deprecated template files (optional: keep for backward compatibility)
8. Clean up any temporary files from extraction
9. Verify all commits follow conventions
10. Final code review

**Verification Checklist**:
- [ ] All 62+ tests passing
- [ ] No compiler warnings
- [ ] Preview images render correctly
- [ ] Templates export to PDF successfully
- [ ] Registry cache works correctly
- [ ] User templates directory created
- [ ] Standard HTML fallback works
- [ ] CSS-only templates render correctly
- [ ] Documentation is complete
- [ ] Code follows SOLID principles

**Commit Message**: "Complete template delivery uniformization"

**Status**: ❌ NOT STARTED

---

## 🧪 Testing Strategy

### Unit Tests
- Test each component in isolation
- Mock dependencies via protocols
- Cover all edge cases
- Aim for 80%+ code coverage

### Integration Tests
- Test repository + registry interaction
- Test template loading flow
- Test preview extraction
- Test registry updates

### End-to-End Tests
- Test complete template loading workflow
- Test template installation workflow
- Test PDF export with new templates

---

## 🔄 Commit Strategy

### Rules:
1. Commit ONLY when tests are GREEN ✅
2. One logical change per commit
3. Follow conventional commit format
4. Reference this plan document in commit descriptions

### Commit Message Format:
```
<type>: <short description>

<detailed description>

Implementation Plan: Step X - <step name>
Status: X/16 steps completed
Tests: All passing (X tests)
```

---

## 📊 Progress Tracking

Update this section after each step completion:

| Step | Description | Status | Tests | Commit |
|------|-------------|--------|-------|--------|
| 1 | StandardTemplate.html | ✅ | N/A | N/A (already exists) |
| 2 | TemplatePackage updates | ✅ | ✅ (263 tests) | Pending |
| 3 | TemplateRegistry models | ❌ | ⬜ | - |
| 4 | Registry protocol | ❌ | ⬜ | - |
| 5 | RegistryManager impl | ❌ | ⬜ | - |
| 6 | Async protocol | ❌ | ⬜ | - |
| 7 | Extract CSS | ❌ | N/A | - |
| 8 | Generate previews | ❌ | N/A | - |
| 9 | Create .mcvt files | ❌ | N/A | - |
| 10 | BundledRepository | ❌ | ⬜ | - |
| 11 | FileRepository | ❌ | ⬜ | - |
| 12 | Async tests | ❌ | ⬜ | - |
| 13 | DI Container | ❌ | ⬜ | - |
| 14 | Use cases/VMs | ❌ | ⬜ | - |
| 15 | Documentation | ❌ | N/A | - |
| 16 | Integration test | ❌ | ⬜ | - |

**Legend**: ❌ Not Started | 🔄 In Progress | ✅ Complete | ⬜ Tests Pending | ✅ Tests Pass

---

## 🚨 Important Reminders

### For ALL Future Sessions:
1. **READ THIS DOCUMENT FIRST** before starting work
2. **Follow the steps SEQUENTIALLY** - don't skip ahead
3. **Write tests BEFORE implementation** (TDD)
4. **Run tests after EVERY change**
5. **Commit ONLY when tests are GREEN**
6. **Update progress table after each step**
7. **Follow SOLID and Clean Architecture principles**
8. **Use dependency injection for all dependencies**
9. **All repository methods must be async**
10. **Document code with clear comments**

### Red Flags to Avoid:
- ❌ Skipping tests
- ❌ Committing with failing tests
- ❌ Hardcoded dependencies
- ❌ Singletons or static state
- ❌ Mixing concerns (view logic in repositories, etc.)
- ❌ Synchronous file I/O
- ❌ Missing error handling
- ❌ Incomplete documentation

---

## 🎓 Learning Resources

- Swift Async/Await: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
- SOLID Principles: https://en.wikipedia.org/wiki/SOLID
- Clean Architecture: https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html
- TDD: https://en.wikipedia.org/wiki/Test-driven_development

---

**Next Step**: Begin with Step 1 - Create StandardTemplate.html

**Current Blocker**: None

**Questions/Issues**: Document any questions or blockers here for team discussion

---

_This document is the single source of truth for the template delivery implementation. Keep it updated!_
