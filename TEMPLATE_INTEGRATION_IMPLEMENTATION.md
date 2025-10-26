# Template Integration Implementation Plan

**Date**: 2025-10-25
**Status**: NOT STARTED
**Goal**: Replace Sample CV Templates with PDF Template System

---

## 📋 Architecture Principles (MUST FOLLOW)

### 1. **TDD Approach** ✅
- Write tests FIRST before implementation
- Run tests after EVERY change
- Commit ONLY when ALL tests are GREEN

### 2. **SOLID Principles** ✅
- **S**ingle Responsibility: Each class has ONE reason to change
- **O**pen/Closed: Open for extension, closed for modification
- **L**iskov Substitution: Subtypes must be substitutable
- **I**nterface Segregation: Many specific interfaces > one general
- **D**ependency Inversion: Depend on abstractions, not concretions

### 3. **Clean Code** ✅
- Meaningful names (no abbreviations)
- Functions do ONE thing
- Comments explain WHY, not WHAT
- No magic numbers/strings
- DRY (Don't Repeat Yourself)

### 4. **Dependency Injection** ✅
- Constructor injection (prefer over property/method injection)
- Protocol-based dependencies
- NO singletons (except DI container)
- Testable architecture

### 5. **Commit Strategy** ✅
- Commit EVERY step individually
- NEVER bulk commits
- Each commit = one logical unit of work
- Run ALL tests before EVERY commit

---

## 🎯 Current State Analysis

### What We Have
- **TemplateSelectionViewModel**: Loads sample CVs (`CVModel`) from `SampleCVRepositoryProtocol`
- **TemplateSelectionView**: Displays templates with placeholder SF Symbol icons (`doc.text`)
- **CVModel**: Used for both templates and actual CVs (conflated concerns)
- **Template System** in CVPDFExporter:
  - `Template` model with `thumbnailURL` support
  - `TemplateRepositoryProtocol` with async methods
  - `GetAvailableTemplatesUseCase` for fetching templates
  - `BundledTemplateRepository` with 3 hardcoded templates (professional, modern, minimal)
  - **New**: Registry system (Steps 1-6) for template caching with PNG previews

### What Needs to Change
1. **TemplateSelectionViewModel** should use `GetAvailableTemplatesUseCase` instead of `SampleCVRepositoryProtocol`
2. **TemplateSelectionView** should display actual template preview PNGs instead of SF Symbol icons
3. **Separation of Concerns**: `Template` for templates, `CVModel` for CVs
4. **Preview Images**: Load from `template.thumbnailURL` with fallback to default image

---

## 📝 Implementation Steps

### **Step 1**: Add Preview Image Assets to Bundle ✅ FIRST
**Why First**: Need assets in place before updating repository to reference them

**Files to Create**:
- `CVPDFExporter/Resources/Templates/professional_preview.png`
- `CVPDFExporter/Resources/Templates/modern_preview.png`
- `CVPDFExporter/Resources/Templates/minimal_preview.png`
- `CVPDFExporter/Resources/Templates/default_template_preview.png` (fallback)

**Tasks**:
1. Create `Resources/Templates/` directory in CVPDFExporter
2. Add placeholder preview PNGs (can be simple colored rectangles for now)
3. Update Xcode project to include resources in bundle
4. Verify resources are accessible via `Bundle.module` or `Bundle.main`

**No Tests**: This is asset setup

**Commit**: "Add template preview image assets to bundle"

---

### **Step 2**: Update BundledTemplateRepository with Thumbnail URLs
**Why**: Templates need to know where their preview images are located

**File**: `CVPDFExporter/Sources/CVPDFExporter/Templates/TemplateRepository.swift`

**TDD Steps**:
1. **Write Tests FIRST** in `BundledTemplateRepositoryTests.swift`:
   - Test that all templates have non-nil `thumbnailURL`
   - Test that thumbnailURL points to valid bundle resource
   - Test that professional template has professional_preview.png
   - Test that modern template has modern_preview.png
   - Test that minimal template has minimal_preview.png

2. **Implement**:
   - Update `loadBundledTemplates()` to set `thumbnailURL` for each template
   - Use `Bundle.module.url(forResource:withExtension:)` to get URLs
   - Handle missing resources gracefully (log warning, set to nil)

3. **Run Tests**: Verify all tests pass

**Commit**: "Add thumbnailURL support to BundledTemplateRepository with tests"

---

### **Step 3**: Create TemplateDisplayModel
**Why**: Separate display concerns from domain model, easier to test UI logic

**File**: `PrestoCV/Features/TemplateSelection/Models/TemplateDisplayModel.swift` (NEW)

**TDD Steps**:
1. **Write Tests FIRST** in `TemplateDisplayModelTests.swift`:
   - Test initialization from Template
   - Test computed properties (has valid preview, display name, display description)
   - Test Identifiable conformance
   - Test mapping collection of Templates to TemplateDisplayModels

2. **Implement**:
```swift
struct TemplateDisplayModel: Identifiable {
    let id: String
    let name: String
    let description: String
    let previewURL: URL?
    let isPremium: Bool

    init(from template: Template) {
        self.id = template.id
        self.name = template.name
        self.description = template.description
        self.previewURL = template.thumbnailURL
        self.isPremium = template.isPremium
    }

    var hasValidPreview: Bool {
        previewURL != nil
    }
}
```

3. **Run Tests**: Verify all tests pass

**Commit**: "Add TemplateDisplayModel with mapping from Template"

---

### **Step 4**: Create GetAvailableTemplatesUseCase Factory in DI Container
**Why**: Need to wire up use case with repository before using in ViewModel

**File**: `PrestoCV/App/ViewModelFactory.swift` (or wherever DI is configured)

**TDD Steps**:
1. **Write Tests FIRST** in `ViewModelFactoryTests.swift` or integration tests:
   - Test that `makeGetAvailableTemplatesUseCase()` returns use case
   - Test that use case is initialized with BundledTemplateRepository
   - Test that calling execute() returns templates

2. **Implement**:
```swift
func makeGetAvailableTemplatesUseCase() -> GetAvailableTemplatesUseCase {
    let repository = makeBundledTemplateRepository()
    return GetAvailableTemplatesUseCase(repositories: [repository])
}

private func makeBundledTemplateRepository() -> BundledTemplateRepository {
    return BundledTemplateRepository()
}
```

3. **Run Tests**: Verify all tests pass

**Commit**: "Add GetAvailableTemplatesUseCase factory to DI container"

---

### **Step 5**: Create New TemplateSelectionViewModel with Tests
**Why**: Core business logic change - MUST follow TDD strictly

**File**: `PrestoCV/Features/TemplateSelection/ViewModels/TemplateSelectionViewModel.swift` (REPLACE)

**TDD Steps**:
1. **Write Tests FIRST** in `TemplateSelectionViewModelTests.swift`:
   - Test initialization with GetAvailableTemplatesUseCase
   - Test `loadTemplates()` success: populates templates array
   - Test `loadTemplates()` failure: sets error state
   - Test `loadTemplates()` empty: handles empty array
   - Test state transitions: idle → loading → loaded
   - Test clearError() clears error state
   - Test computed properties (templates, isLoading, errorMessage)
   - Mock GetAvailableTemplatesUseCase for testing

2. **Implement**:
```swift
final class TemplateSelectionViewModel: ObservableObject {
    @Published var viewState: ViewState<[TemplateDisplayModel]> = .idle

    private let getTemplatesUseCase: GetAvailableTemplatesUseCase

    init(getTemplatesUseCase: GetAvailableTemplatesUseCase) {
        self.getTemplatesUseCase = getTemplatesUseCase
    }

    @MainActor
    func loadTemplates() async {
        viewState = .loading

        do {
            let templates = try await getTemplatesUseCase.execute()
            let displayModels = templates.map { TemplateDisplayModel(from: $0) }
            viewState = .loaded(displayModels)
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }

    // ... other methods
}
```

3. **Run Tests**: Verify all NEW tests pass
4. **Run ALL Tests**: Ensure no regressions

**Commit**: "Replace TemplateSelectionViewModel with Template-based implementation"

---

### **Step 6**: Update TemplateCardView to Display Preview Images
**Why**: UI needs to show actual preview images instead of SF Symbol icons

**File**: `PrestoCV/Features/TemplateSelection/Views/TemplateSelectionView.swift`

**TDD Steps**:
1. **Write SwiftUI Preview Tests** (manual verification):
   - Preview with valid preview URLs
   - Preview with nil preview URLs (fallback to default)
   - Preview with different template data

2. **Implement**:
```swift
private struct TemplateCardView: View {
    let template: TemplateDisplayModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            CardView(padding: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    // Template preview image
                    if let previewURL = template.previewURL {
                        AsyncImage(url: previewURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            defaultPreviewPlaceholder
                        }
                        .aspectRatio(1.0, contentMode: .fit)
                        .cornerRadius(DesignTokens.CornerRadius.md)
                    } else {
                        defaultPreviewPlaceholder
                    }

                    // Template info
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        Text(template.name)
                            .typography(.headline)
                        Text(template.description)
                            .typography(.caption1)
                    }
                }
            }
        }
    }

    private var defaultPreviewPlaceholder: some View {
        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
            .fill(DesignTokens.Colors.backgroundSecondary)
            .aspectRatio(1.0, contentMode: .fit)
            .overlay(
                Image(systemName: "doc.text")
                    .font(DesignTokens.IconSize.hero.font)
            )
    }
}
```

3. **Manual Test**: Run app, verify preview images load correctly

**Commit**: "Update TemplateCardView to display preview images with AsyncImage"

---

### **Step 7**: Update TemplateSelectionView to Use New ViewModel
**Why**: Wire up the new ViewModel with the View

**File**: `PrestoCV/Features/TemplateSelection/Views/TemplateSelectionView.swift`

**Tasks**:
1. Update view to accept new `TemplateSelectionViewModel`
2. Change `ForEach(viewModel.templates)` to iterate over `TemplateDisplayModel`
3. Update `onTap` closure to handle `TemplateDisplayModel` instead of `CVModel`
4. Keep `createNewCard` and `aiGenerationCard` unchanged (they don't use templates)

**No New Tests**: View layer integration

**Commit**: "Wire TemplateSelectionView with new ViewModel"

---

### **Step 8**: Handle Template → CVModel Conversion for Navigation
**Why**: AppRouter expects CVModel, but we now have Template

**Approach**: Create converter utility

**File**: `PrestoCV/Features/TemplateSelection/Utils/TemplateToCVModelConverter.swift` (NEW)

**TDD Steps**:
1. **Write Tests FIRST** in `TemplateToCVModelConverterTests.swift`:
   - Test converting professional Template to CVModel
   - Test converting modern Template to CVModel
   - Test converting minimal Template to CVModel
   - Test that converted CVModel has template metadata
   - Test that converted CVModel is empty (no personal data)

2. **Implement**:
```swift
struct TemplateToCVModelConverter {
    static func convert(_ template: Template) -> CVModel {
        var cv = CVModel()
        // Store template ID in CVModel for later PDF export
        // Option 1: Add templateId property to CVModel
        // Option 2: Store in metadata/custom field
        return cv
    }
}
```

3. **Run Tests**: Verify all tests pass

**Commit**: "Add TemplateToCVModelConverter with tests"

---

### **Step 9**: Update Template Selection onTap Navigation
**Why**: Convert TemplateDisplayModel → CVModel before navigation

**File**: `PrestoCV/Features/TemplateSelection/Views/TemplateSelectionView.swift`

**Tasks**:
1. Update `onTap` closure in TemplateCardView:
```swift
onTap: {
    // Need to get full Template from TemplateDisplayModel
    // Option 1: Store Template in TemplateDisplayModel
    // Option 2: Fetch Template by ID from ViewModel
    let cv = TemplateToCVModelConverter.convert(template)
    router.navigateToEditorWithTemplate(cv)
}
```

**Decision Needed**: How to get full `Template` from `TemplateDisplayModel` for conversion?
- **Option A**: Store `Template` reference in `TemplateDisplayModel`
- **Option B**: Add method to ViewModel: `getTemplate(id: String) -> Template?`

**Commit**: "Update template selection navigation with Template→CVModel conversion"

---

### **Step 10**: Update ViewModelFactory to Create New TemplateSelectionViewModel
**Why**: DI container needs to create ViewModel with new dependencies

**File**: `PrestoCV/App/ViewModelFactory.swift`

**TDD Steps**:
1. **Write Tests FIRST**:
   - Test that factory creates TemplateSelectionViewModel with correct dependencies
   - Test that ViewModel is functional after creation

2. **Implement**:
```swift
func makeTemplateSelectionViewModel() -> TemplateSelectionViewModel {
    let getTemplatesUseCase = makeGetAvailableTemplatesUseCase()
    return TemplateSelectionViewModel(getTemplatesUseCase: getTemplatesUseCase)
}
```

3. **Run Tests**: Verify all tests pass

**Commit**: "Update ViewModelFactory to create TemplateSelectionViewModel with GetAvailableTemplatesUseCase"

---

### **Step 11**: Update All Call Sites Creating TemplateSelectionViewModel
**Why**: Ensure all places creating the ViewModel use the factory

**Files**:
- `PrestoCV/Features/TemplateSelection/Views/TemplateSelectionView_Previews.swift`
- Any other places instantiating TemplateSelectionViewModel

**Tasks**:
1. Search for all `TemplateSelectionViewModel(` instantiations
2. Replace with factory method call
3. Update previews to use mock factory or test doubles

**Run Tests**: Full test suite to catch any missed call sites

**Commit**: "Update all TemplateSelectionViewModel instantiation sites to use factory"

---

### **Step 12**: Integration Testing
**Why**: Verify end-to-end flow works correctly

**File**: `PrestoCVTests/Integration/TemplateSelectionIntegrationTests.swift` (NEW)

**TDD Steps**:
1. **Write Tests**:
   - Test full flow: Load templates → Display in view → Tap template → Navigate to editor
   - Test with different template types (professional, modern, minimal)
   - Test error handling: Use case fails → Error displayed in view
   - Test empty state: No templates → Show appropriate message

2. **Run Tests**: Verify all integration tests pass

**Commit**: "Add integration tests for template selection flow"

---

### **Step 13**: Clean Up Old Sample CV Code (Optional - Separate Decision)
**Why**: Remove dead code if Sample CVs are no longer needed

**Analysis Needed**:
- Are "sample CVs" used anywhere else? (Onboarding?)
- Are they different from "templates"?

**If removing**:
1. Delete `SampleCVRepository` and related files
2. Remove from DependencyContainer
3. Update any other code using sample CVs

**If keeping**:
- Document why both concepts exist
- Clarify difference between "sample CV" and "template"

**Commit** (if removing): "Remove deprecated SampleCVRepository (replaced by Template system)"

---

### **Step 14**: Update Documentation
**Why**: Future developers need to understand the new system

**Files**:
- Update README or architecture docs
- Add inline documentation to new classes

**Tasks**:
1. Document Template vs CVModel distinction
2. Document template loading flow
3. Update architecture diagrams if needed

**Commit**: "Update documentation for template system integration"

---

## 🧪 Testing Checklist

### Unit Tests ✅
- [ ] TemplateDisplayModel tests
- [ ] TemplateSelectionViewModel tests (all state transitions)
- [ ] TemplateToCVModelConverter tests
- [ ] BundledTemplateRepository thumbnailURL tests
- [ ] ViewModelFactory tests

### Integration Tests ✅
- [ ] Full template selection flow
- [ ] Error handling paths
- [ ] Empty state handling

### Manual Tests 📱
- [ ] Run app, verify templates load
- [ ] Verify preview images display correctly
- [ ] Tap template, verify navigation to editor
- [ ] Verify fallback image shows when preview missing
- [ ] Verify "Create New" still works
- [ ] Verify AI Generation card still works (if enabled)

---

## 📊 Progress Tracking

| Step | Status | Tests Pass | Committed | Notes |
|------|--------|-----------|-----------|-------|
| 1. Add Preview Assets | ❌ NOT STARTED | N/A | ❌ | Asset setup |
| 2. Update BundledTemplateRepository | ❌ NOT STARTED | ❌ | ❌ | TDD |
| 3. Create TemplateDisplayModel | ❌ NOT STARTED | ❌ | ❌ | TDD |
| 4. DI Container Factory | ❌ NOT STARTED | ❌ | ❌ | TDD |
| 5. New TemplateSelectionViewModel | ❌ NOT STARTED | ❌ | ❌ | TDD - CRITICAL |
| 6. Update TemplateCardView | ❌ NOT STARTED | N/A | ❌ | UI Update |
| 7. Wire View with ViewModel | ❌ NOT STARTED | N/A | ❌ | Integration |
| 8. Template→CVModel Converter | ❌ NOT STARTED | ❌ | ❌ | TDD |
| 9. Update Navigation | ❌ NOT STARTED | N/A | ❌ | Integration |
| 10. Update ViewModelFactory | ❌ NOT STARTED | ❌ | ❌ | TDD |
| 11. Update Call Sites | ❌ NOT STARTED | ✅ | ❌ | Refactor |
| 12. Integration Tests | ❌ NOT STARTED | ❌ | ❌ | TDD |
| 13. Clean Up (Optional) | ❌ NOT STARTED | ✅ | ❌ | Cleanup |
| 14. Documentation | ❌ NOT STARTED | N/A | ❌ | Docs |

---

## 🚨 Open Questions / Decisions

1. **Sample CVs vs Templates**: Are they the same concept or different?
   - If same: Remove SampleCVRepository entirely
   - If different: Keep both, document distinction

2. **Preview Image Creation**: Who creates the actual preview PNGs?
   - For now: Simple colored placeholders
   - Future: Real template previews

3. **Template → CVModel Conversion**: How to store template ID in CVModel?
   - Option A: Add `templateId: String?` property to CVModel
   - Option B: Store in metadata/tags
   - Option C: Don't store, derive from template usage

4. **TemplateDisplayModel vs Template**: Store full Template or just display data?
   - Affects how we convert back to Template for navigation

---

## 📝 Notes

- **DO NOT** skip TDD for any step marked with TDD
- **DO NOT** bulk commit - each step is ONE commit
- **ALWAYS** run full test suite before committing
- **FOLLOW** SOLID principles strictly
- **USE** dependency injection everywhere
- **KEEP** clean code standards (naming, single responsibility, etc.)

---

## ✅ Definition of Done

- [ ] All tests GREEN (unit + integration)
- [ ] All steps committed individually
- [ ] Manual testing completed successfully
- [ ] No regressions in existing functionality
- [ ] Code review checklist passed (SOLID, Clean Code, DI)
- [ ] Documentation updated
- [ ] This plan document updated with final status
