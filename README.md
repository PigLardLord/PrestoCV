# PrestoCV - Professional CV Creation App

A modern iOS application for creating, editing, and exporting professional CVs with beautiful templates and AI-powered generation.

## Table of Contents
- [Features](#features)
- [Architecture Overview](#architecture-overview)
- [Module Descriptions](#module-descriptions)
- [Template System Architecture](#template-system-architecture)
- [Design Principles](#design-principles)
- [Data Flow Examples](#data-flow-examples)
- [Development Workflow](#development-workflow)
- [Testing Strategy](#testing-strategy)

---

## Features

- **Template Selection**: Choose from professional, modern, and minimal CV templates
- **CV Editing**: Comprehensive editor for personal info, experience, education, skills, and more
- **AI Generation**: Generate CV content from natural language using Apple's FoundationModels
- **PDF Export**: Export CVs to PDF with customizable templates
- **Template Sharing**: Import/export custom templates via AirDrop or Files app (.mcvt format)
- **Sample CVs**: Quick start with pre-configured sample CVs
- **Dark Mode**: Full dark mode support throughout the app

---

## Architecture Overview

PrestoCV follows a **multi-module Clean Architecture** pattern with clear separation of concerns and dependency inversion.

### Module Dependency Diagram

```
┌─────────────────────────────────────────────────────┐
│              PrestoCV (Main App)                        │
│         iOS SwiftUI Application                     │
│  - Features (CVList, Editor, Export, etc.)         │
│  - ViewModels (MVVM Pattern)                        │
│  - AppRouter (Navigation)                           │
│  - ViewModelFactory (DI)                           │
└──────────────┬──────────────────────────────────────┘
               │ depends on ↓
┌──────────────▼──────────────────────────────────────┐
│              PrestoCVCore                               │
│         Application & Domain Layer                  │
│  - Use Cases (CVManagement, Onboarding)            │
│  - Domain Models (CVModel, PersonalInfo)           │
│  - Repositories (CVRepository, Sample)             │
│  - Services (Storage, Search, Category)            │
│  - DependencyContainer                             │
└──────┬───────────────────────────────┬─────────────┘
       │ depends on ↓                  │ depends on ↓
┌──────▼─────────────────┐   ┌─────────▼──────────────┐
│   CVPDFExporter        │   │   CVGeneratorAI        │
│  Template & PDF Layer  │   │  AI Generation Layer   │
│  - Template System     │   │  - FoundationModels    │
│  - .mcvt Packages      │   │  - CV Generation       │
│  - PDF Rendering       │   │  - Validation          │
│  - Bootstrap Service   │   │  - Type-Safe Models    │
└────────────────────────┘   └────────────────────────┘
```

### Dependency Flow

The dependency flow follows the **Dependency Inversion Principle**:

1. **PrestoCV** (Presentation) → **PrestoCVCore** (Application/Domain)
2. **PrestoCVCore** → **CVPDFExporter** + **CVGeneratorAI** (Infrastructure)

**Key Principle**: Higher-level modules depend on abstractions (protocols), not concrete implementations.

---

## Module Descriptions

### 1. PrestoCV (Main App)

**Purpose**: iOS SwiftUI application providing the user interface and navigation.

**Architecture**: MVVM (Model-View-ViewModel) pattern

**Structure**:
```
PrestoCV/
├── App/
│   ├── PrestoCVApp.swift           # App entry point
│   ├── AppRootView.swift       # Root view with navigation
│   └── AppRouter.swift         # Centralized navigation
├── Features/
│   ├── Onboarding/             # First-time user experience
│   ├── CVList/                 # CV list and management
│   ├── CVEditor/               # CV editing interface
│   ├── TemplateSelection/      # Template browsing and selection
│   ├── AIGeneration/           # AI-powered CV generation
│   └── Export/                 # PDF export functionality
└── Common/
    ├── ViewModelFactory.swift  # Dependency injection
    ├── LoadingView.swift       # Reusable UI components
    └── ErrorView.swift
```

**Key Components**:
- **ViewModels**: `@StateObject` classes managing feature state
- **AppRouter**: Navigation state machine with type-safe routing
- **ViewModelFactory**: Creates ViewModels with proper dependency injection
- **DependencyContainer**: Injected at app launch, provides all services

**Navigation Flow**:
```
Onboarding → CVList → [Template Selection | AI Generation] → CV Editor → PDF Export
```

### 2. PrestoCVCore

**Purpose**: Platform-independent domain logic and business rules.

**Architecture**: Clean Architecture (Use Cases + Domain Models + Repositories)

**Structure**:
```
PrestoCVCore/
├── Models/
│   ├── CVModel.swift           # Core CV data structure
│   ├── PersonalInfo.swift
│   ├── Experience.swift
│   ├── Education.swift
│   ├── Skill.swift
│   └── ...
├── UseCases/
│   ├── CVManagementUseCase.swift
│   ├── OnboardingUseCase.swift
│   └── ...
├── Protocols/
│   ├── CVRepositoryProtocol.swift
│   ├── StorageServiceProtocol.swift
│   └── ...
├── Services/
│   ├── Repositories/
│   │   ├── CVRepository.swift
│   │   ├── SampleCVRepository.swift
│   │   └── OnboardingRepository.swift
│   ├── Storage/
│   │   └── FileStorageService.swift
│   └── Utilities/
│       ├── ParallelSearchService.swift
│       └── TemplateCategoryService.swift
└── DependencyContainer.swift   # Service composition
```

**Key Responsibilities**:
- **Domain Models**: Codable, Equatable, Sendable value types
- **Use Cases**: Orchestrate business logic (create CV, save CV, check onboarding)
- **Repositories**: Data access abstractions (CV storage, samples)
- **Services**: Utility services (file I/O, search, categorization)

**Design Patterns**:
- **Repository Pattern**: Abstracts data storage
- **Use Case Pattern**: One use case per business operation
- **Dependency Injection**: All dependencies injected via constructors

### 3. CVPDFExporter

**Purpose**: Platform-agnostic template system and PDF export library (distributable via SPM).

**Architecture**: Clean Architecture + Dependency Inversion

**Structure**:
```
CVPDFExporter/
├── Templates/
│   ├── Domain/
│   │   ├── Template.swift          # Template model
│   │   ├── TemplateManifest.swift  # Metadata
│   │   └── TemplatePackage.swift   # .mcvt format
│   ├── Repository/
│   │   ├── FileTemplateRepository.swift  # File system templates
│   │   ├── TemplateRegistryManager.swift # Template registry
│   │   └── BundledTemplateRepository.swift
│   ├── Services/
│   │   ├── TemplateBootstrapService.swift # Sync bundled templates
│   │   ├── TemplateEngine.swift          # Mustache rendering
│   │   └── TemplateValidator.swift
│   └── UseCases/
│       ├── GetAvailableTemplatesUseCase.swift
│       └── InstallTemplateUseCase.swift
├── PDF/
│   ├── PDFExportEngine.swift      # Main export coordinator
│   ├── HTMLToPDFRenderer.swift    # Protocol for platform rendering
│   └── ExportOptions.swift
└── Resources/
    └── Templates/
        └── Bundled/                # Bundled .mcvt files
            ├── professional.mcvt
            ├── modern.mcvt
            └── minimal.mcvt
```

**Key Features**:
- **Platform Independence**: No UIKit/AppKit dependencies (uses dependency injection)
- **Template System**: .mcvt packages with manifest, CSS, HTML, and preview images
- **Multiple Sources**: Bundled templates, file system templates, remote (future)
- **SPM Distributable**: Can be used as a standalone Swift Package
- **Template Bootstrap**: Syncs bundled templates to Application Support on app launch

**Template Responsibilities**:
- Templates are **rendering artifacts** (HTML/CSS defining how CVs are displayed)
- Templates define the **visual presentation** of CV data
- Templates are **tightly coupled to PDF rendering** logic
- Therefore, templates **belong in the rendering module** (CVPDFExporter)

### 4. CVGeneratorAI

**Purpose**: AI-powered CV generation using Apple's FoundationModels.

**Architecture**: Protocol-based abstraction for AI backends

**Structure**:
```
CVGeneratorAI/
├── Models/
│   ├── CVData.swift               # AI-generated CV structure
│   ├── PersonalInfo.swift
│   ├── Experience.swift
│   └── ...
├── Protocols/
│   └── CVGenerationServiceProtocol.swift
├── Services/
│   ├── FoundationModelsService.swift
│   └── MockCVGenerationService.swift
├── UseCases/
│   └── CVGeneratorUseCase.swift
└── Validation/
    ├── CVGenerationRequestValidator.swift
    └── CVDataValidator.swift
```

**Key Features**:
- **Protocol-Based**: Abstract AI backend (can swap FoundationModels for other services)
- **Type-Safe**: All models are Codable, Equatable, Sendable
- **Validation**: Comprehensive input/output validation
- **Test Coverage**: 28 tests covering models, services, and use cases
- **Isolated**: No dependencies on main app models (uses adapters for conversion)

---

## Template System Architecture

### Why Templates Live in CVPDFExporter

**Question**: "*Is it correct that templates are bundled in the rendering package AND also shared in the main app?*"

**Answer**: **Yes, this is the correct architectural decision.** Here's why:

#### 1. Templates Are Rendering Artifacts

Templates define **HOW** CVs are rendered to PDF:
- HTML structure
- CSS styling
- Page breaks and print media queries
- Visual layout and typography

This makes them **intrinsically tied to the rendering layer**, not the domain layer.

#### 2. Separation of Concerns

```
┌────────────────────────────────────────────────┐
│ PrestoCVCore                                       │
│ "WHAT data to show" (CVModel, PersonalInfo)  │
│ Domain models represent CV content            │
└────────────────────────────────────────────────┘
                     │
                     │ data flows to ↓
                     ▼
┌────────────────────────────────────────────────┐
│ CVPDFExporter                                  │
│ "HOW to render the data" (Templates)         │
│ Templates define visual presentation          │
└────────────────────────────────────────────────┘
```

#### 3. Main App Accesses Templates Cleanly

The main app does NOT directly access template files. Instead:

```swift
// Main app uses clean use case interface
let getTemplatesUseCase = GetAvailableTemplatesUseCase(repositories: [bundledRepo, fileRepo])
let templates = try await getTemplatesUseCase.execute()

// No direct file I/O, no coupling to template storage
```

This follows the **Dependency Inversion Principle**:
- Main app depends on `GetAvailableTemplatesUseCase` (abstraction)
- NOT on `FileTemplateRepository` (concrete implementation)

#### 4. SPM Distribution

CVPDFExporter is a **distributable Swift Package**. Bundling templates with the package means:
- Other apps can use CVPDFExporter standalone
- Bundled templates come "for free" when adding the package
- No manual resource copying required
- Templates are versioned with the package

#### 5. Template Sharing Works Through Clean Interfaces

**Bundled Templates**:
- Stored in `CVPDFExporter/Resources/Templates/Bundled/`
- Loaded via `Bundle.module` (SPM resource access)
- Synced to Application Support on app launch via `TemplateBootstrapService`

**Custom Templates**:
- Users import .mcvt files via AirDrop/Files app
- Installed to `~/Library/Application Support/PrestoCV/Templates/`
- Loaded via `FileTemplateRepository`
- Combined with bundled templates by `GetAvailableTemplatesUseCase`

### Template Data Flow

```
1. App Launch
   ↓
2. TemplateBootstrapService.syncBundledTemplates()
   ↓ loads from Bundle.module
3. Bundled .mcvt files → Application Support directory
   ↓ registered in
4. TemplateRegistryManager (persistent registry)
   ↓ accessed via
5. GetAvailableTemplatesUseCase
   ↓ combines
6. [Bundled Templates] + [User Templates] + [Remote Templates (future)]
   ↓ returned to
7. TemplateSelectionViewModel
   ↓ displayed in
8. TemplateSelectionView (SwiftUI)
```

### .mcvt Package Format

Templates are distributed as **JSON-encoded .mcvt files**:

```json
{
  "manifest": {
    "id": "professional",
    "name": "Professional",
    "version": "1.0.0",
    "description": "Clean professional template",
    "author": "PrestoCV",
    "price": 0.0,
    "isFree": true
  },
  "cssContent": "/* CSS styles for template */",
  "htmlContent": null,
  "previewImageData": "base64-encoded-png-image"
}
```

**Sharing Methods**:
- AirDrop
- Files app
- Email/Messages
- Remote download (future: template marketplace)

---

## Design Principles

### 1. Clean Architecture

**Layers**:
1. **Presentation** (PrestoCV): SwiftUI Views, ViewModels
2. **Application** (PrestoCVCore): Use Cases, Domain Models
3. **Domain** (PrestoCVCore): Business Rules, Protocols
4. **Infrastructure** (CVPDFExporter, CVGeneratorAI): External services

**Dependency Rule**: Outer layers depend on inner layers, never the reverse.

### 2. SOLID Principles

#### Single Responsibility Principle
- Each module has one reason to change
- `CVManagementUseCase`: Only CV CRUD operations
- `TemplateBootstrapService`: Only bundled template synchronization

#### Open/Closed Principle
- Open for extension: Add new template repositories without modifying existing code
- Closed for modification: `TemplateRepositoryProtocol` interface is stable

#### Liskov Substitution Principle
- All repositories conform to `TemplateRepositoryProtocol`
- Can be swapped without breaking use cases

#### Interface Segregation Principle
- Focused protocols (`TemplateRepositoryProtocol`, `StorageServiceProtocol`)
- No "god interfaces" with unused methods

#### Dependency Inversion Principle
- High-level modules (use cases) depend on abstractions (protocols)
- Low-level modules (repositories) implement abstractions
- Example: `GetAvailableTemplatesUseCase` depends on `TemplateRepositoryProtocol`, not concrete implementations

### 3. Platform Independence

**CVPDFExporter** and **CVGeneratorAI** are platform-agnostic:
- No `import UIKit` or `import AppKit`
- PDF rendering injected via `HTMLToPDFRenderer` protocol
- Can run on iOS, macOS, Linux, or any Swift platform

### 4. Test-First Development (TDD)

All modules follow Red-Green-Refactor:
1. **RED**: Write failing test
2. **GREEN**: Implement minimal code to pass
3. **REFACTOR**: Clean up code
4. **COMMIT**: Only when all tests pass

---

## Data Flow Examples

### 1. Template Selection → CV Creation → PDF Export

```
User Action: Select Template
  ↓
TemplateSelectionViewModel.loadTemplates()
  ↓ calls
GetAvailableTemplatesUseCase.execute()
  ↓ queries
[BundledTemplateRepository, FileTemplateRepository]
  ↓ returns
[Template] (Professional, Modern, Minimal, + User Templates)
  ↓ displayed in
TemplateSelectionView
  ↓ user selects template
TemplateSelectionViewModel.createCVFromTemplate()
  ↓ navigates to
CVEditorView (with new CVModel based on template)
  ↓ user edits CV
CVEditorViewModel.saveCV()
  ↓ saves via
CVManagementUseCase.createCV()
  ↓ persists to
CVRepository (FileStorage)
  ↓ navigates to
ExportView
  ↓ user taps Export
CVExportSheetViewModel.exportToPDF()
  ↓ calls
PDFExportEngine.exportToPDF(template: selectedTemplate, cv: cvModel)
  ↓ renders with
HTMLToPDFRenderer (platform-specific implementation)
  ↓ returns
PDF Data → Shared via iOS Share Sheet
```

### 2. AI Generation → CV Creation

```
User Action: "Generate CV from AI"
  ↓
AIGenerationViewModel.generateCV(prompt: userPrompt)
  ↓ calls
CVGeneratorUseCase.generateCV(request: CVGenerationRequest)
  ↓ calls
FoundationModelsService.generateCV()
  ↓ uses Apple FoundationModels
AI Processing (natural language → structured CV data)
  ↓ returns
CVData (AI-generated structure)
  ↓ validates
CVDataValidator.validate()
  ↓ converts
AIToCoreModelAdapter.convert(CVData) → CVModel
  ↓ navigates to
CVEditorView (with AI-generated content)
```

### 3. Custom Template Import

```
User Action: Import .mcvt file via AirDrop
  ↓ iOS document picker
File URL received
  ↓
TemplateImportHandler.importTemplate(url: fileURL)
  ↓ reads
TemplatePackage (from JSON file)
  ↓ validates
TemplateValidator.validate(package)
  ↓ installs via
InstallTemplateUseCase.execute(package: templatePackage)
  ↓ saves to
FileTemplateRepository → Application Support directory
  ↓ registers in
TemplateRegistryManager (persistent registry)
  ↓ available in
GetAvailableTemplatesUseCase.execute()
  ↓
Template appears in TemplateSelectionView
```

---

## Development Workflow

### Feature Development Process

1. **Plan Feature**:
   - Identify which module(s) are affected
   - Define use cases and domain models
   - Consider existing abstractions

2. **Write Tests First (TDD)**:
   ```bash
   # 1. Create test file
   touch Tests/NewFeatureTests.swift

   # 2. Write failing tests
   # 3. Run tests - see RED
   xcodebuild test -scheme PrestoCV
   ```

3. **Implement Feature**:
   - Start with domain models (PrestoCVCore)
   - Add use cases (PrestoCVCore)
   - Implement repositories/services if needed
   - Add presentation layer (PrestoCV)
   - Run tests after each step - see GREEN

4. **Refactor**:
   - Extract common patterns
   - Improve naming
   - Ensure SOLID principles
   - Tests must stay GREEN

5. **Commit**:
   ```bash
   # Only commit when all tests pass
   git add .
   git commit -m "Add feature X with tests"
   ```

### Module-Specific Guidelines

#### When to Add to PrestoCVCore
- Domain models (represent CV data concepts)
- Business logic (CV validation, duplicate detection)
- Use cases (coordinate domain operations)
- Repository protocols (data access abstractions)

#### When to Add to CVPDFExporter
- Template-related features (new template types, rendering logic)
- PDF export enhancements
- Template validation/installation logic

#### When to Add to CVGeneratorAI
- AI generation improvements
- New AI backend integrations
- Validation rules for AI-generated content

#### When to Add to Main App
- UI components (SwiftUI Views)
- ViewModels (presentation logic)
- Navigation (routing, deep linking)
- Platform-specific features (iOS Share Sheet, etc.)

### Testing Requirements

- **Minimum Coverage**: 70% overall
- **Core Logic**: 90% coverage
- **New Features**: 100% coverage for public API
- **No Commits**: Without passing tests

---

## Testing Strategy

### Unit Tests Per Module

#### PrestoCV Tests
- ViewModel state transitions
- Navigation logic
- Dependency injection
- UI component behavior

#### PrestoCVCore Tests
- Domain model validation
- Use case orchestration
- Repository implementations
- Service behavior

#### CVPDFExporter Tests
- Template loading and validation
- Repository operations
- Use case coordination
- Bootstrap service
- **62 tests passing**

#### CVGeneratorAI Tests
- Model initialization
- Service behavior
- Request/response validation
- Use case orchestration
- **28 tests passing**

### Integration Tests

Test cross-module interactions:
- App → Core: ViewModel uses use cases
- Core → PDFExporter: Use case queries templates
- Core → AI: Use case generates CV

### UI Tests (Planned)

Critical user flows:
- Onboarding → CVList
- Template Selection → CV Editor
- CV Editor → PDF Export
- AI Generation → CV Editor

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme PrestoCV -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run specific module tests
swift test --package-path CVPDFExporter
swift test --package-path CVGeneratorAI

# Run with coverage
xcodebuild test -scheme PrestoCV -enableCodeCoverage YES
```

---

## Project Structure

```
PrestoCV/
├── PrestoCV/                       # Main iOS app
│   ├── App/                    # App lifecycle and root
│   ├── Features/               # Feature modules (MVVM)
│   └── Common/                 # Shared UI components
├── PrestoCVCore/                   # Domain and application layer
│   └── Sources/PrestoCVCore/
│       ├── Models/             # Domain models
│       ├── UseCases/           # Business logic
│       ├── Protocols/          # Repository abstractions
│       └── Services/           # Infrastructure services
├── CVPDFExporter/              # Template and PDF export (SPM)
│   ├── Sources/CVPDFExporter/
│   │   ├── Templates/          # Template system
│   │   ├── PDF/                # PDF export engine
│   │   └── Resources/          # Bundled templates (.mcvt)
│   └── Tests/
├── CVGeneratorAI/              # AI generation (SPM)
│   ├── Sources/CVGeneratorAI/
│   │   ├── Models/             # AI data structures
│   │   ├── Services/           # AI backends
│   │   └── UseCases/           # Generation logic
│   └── Tests/
├── PrestoCVTests/                  # Main app tests
├── PrestoCVUITests/                # UI automation tests
└── README.md                   # This file
```

---

## Key Architectural Decisions

### ✅ Templates in CVPDFExporter
**Decision**: Bundle templates with the rendering module, not the domain module.

**Rationale**:
- Templates are rendering artifacts (HTML/CSS)
- Tightly coupled to PDF export logic
- Enables SPM distribution with bundled templates
- Main app accesses via clean use case interfaces (no coupling)

### ✅ Multi-Module Architecture
**Decision**: Separate domain (PrestoCVCore), infrastructure (CVPDFExporter, CVGeneratorAI), and presentation (PrestoCV).

**Rationale**:
- Clear separation of concerns
- Independent testing per module
- Reusable packages (CVPDFExporter can be used in other apps)
- Easier to reason about dependencies

### ✅ Protocol-Based Abstractions
**Decision**: Use protocols for all cross-module dependencies.

**Rationale**:
- Dependency inversion (depend on abstractions)
- Testability (easy to mock/stub)
- Flexibility (swap implementations)

### ✅ Template Bootstrap Service
**Decision**: Sync bundled templates to Application Support on app launch.

**Rationale**:
- Central template registry (FileTemplateRepository + TemplateRegistryManager)
- Unified access to bundled and user templates
- Enables version management and updates
- Users can override bundled templates with custom versions

---

## References

- **CVPDFExporter README**: Detailed architecture of template and PDF export system
- **CVGeneratorAI README**: AI generation implementation details
- **TEMPLATE_SYSTEM_ARCHITECTURE.md**: Complete template system documentation

---

## License

Copyright © 2024 PrestoCV. All rights reserved.

---

**Last Updated**: 2025-01-27
**Version**: 1.0.0
**Architecture**: Multi-Module Clean Architecture
