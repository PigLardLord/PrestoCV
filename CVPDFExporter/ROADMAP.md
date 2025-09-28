# CVPDFExporter - Complete Implementation Roadmap & Recovery Plan

## Core Principles
1. **Apple-First**: Use Foundation Models framework, PDFKit, WebKit, and native Apple technologies
2. **TDD**: Write tests first, then implementation (Red-Green-Refactor)
3. **Small Commits**: Each commit represents one atomic change
4. **SOLID Principles**: Single responsibility, Open/closed, Liskov substitution, Interface segregation, Dependency inversion
5. **DRY**: Check for existing implementations, make components generic and reusable
6. **Clean Code**: Meaningful names, small functions, no comments (code should be self-documenting)
7. **Easy Recovery**: Each sprint has clear checkpoints and recovery instructions

## Project Structure (Clean Architecture)

```
CVPDFExporter/
├── Domain/                    # Business logic (no external dependencies)
│   ├── UseCases/
│   │   ├── PDFExportUseCase
│   │   ├── TemplateSelectionUseCase
│   │   ├── CVTailoringUseCase (using Foundation Models)
│   │   └── PreviewGenerationUseCase
│   ├── Entities/
│   │   ├── CVDocument (already exists)
│   │   ├── Template (already exists)
│   │   └── ExportConfiguration
│   └── Protocols/
│       ├── PDFRendererProtocol
│       └── CVTailoringServiceProtocol
├── Application/               # Orchestration layer
│   ├── Services/
│   │   └── PDFExportService
│   └── Adapters/
│       └── PrestoCVCoreToCVDocumentAdapter
├── Infrastructure/           # External dependencies
│   ├── Renderers/
│   │   ├── WKWebViewPDFRenderer (exists, needs completion)
│   │   └── PDFKitRenderer (for macOS)
│   ├── AI/
│   │   └── FoundationModelsService (Apple's new framework)
│   └── Storage/
│       └── ExportHistoryRepository
└── Presentation/            # UI layer
    ├── CompositionRoot/
    │   └── PDFExportDependencyContainer
    └── ViewModels/
        └── ExportViewModel
```

## Implementation Sprints

### Sprint 0: Foundation & Recovery Setup (2 days)
**Goal**: Set up project structure and recovery mechanisms

#### Day 1 - Project Setup
```
Commit 1: "Create new ROADMAP with recovery checkpoints"
- Replace old ROADMAP.md with this comprehensive version
- Add RECOVERY_LOG.md for tracking progress

Commit 2: "Add domain layer protocols"
- PDFRendererProtocol
- CVTailoringServiceProtocol
- ExportRepositoryProtocol

Commit 3: "Add PDFExportUseCase with tests"
- Test: Should export CV to PDF
- Test: Should handle invalid document
- Test: Should respect page limits
```

#### Day 2 - Core Infrastructure
```
Commit 4: "Complete PrestoCVCoreToCVDocumentAdapter"
- Map CVModel to CVDocument
- Map PersonalInfo correctly
- Map all sections (experience, education, skills)

Commit 5: "Add adapter tests"
- Test: Maps personal info correctly
- Test: Maps experience section
- Test: Maps education section
- Test: Handles empty sections
```

**Recovery Checkpoint 0**:
- Run: `swift test --filter CVPDFExporterTests`
- All domain tests should pass
- Adapter should map real PrestoCVCore data

---

### Sprint 1: iOS PDF Rendering (3 days)
**Goal**: Complete iOS PDF generation using native components

#### Day 1 - WKWebView Renderer Enhancement
```
Commit 1: "Enhance WKWebViewPDFRenderer with progress tracking"
- Add progress delegate
- Add cancellation support
- Test: Generates valid PDF data

Commit 2: "Add page break handling to WKWebViewPDFRenderer"
- Implement smart page breaks
- Test: Respects page boundaries
- Test: Doesn't split items across pages
```

#### Day 2 - PDFKit Integration
```
Commit 3: "Add PDFKit post-processor"
- Use PDFDocument for metadata
- Add document properties
- Test: PDF has correct metadata

Commit 4: "Add PDF compression"
- Optimize file size
- Test: Compressed PDF is smaller
- Test: Quality is maintained
```

#### Day 3 - Integration Testing
```
Commit 5: "Add end-to-end PDF export tests"
- Test: Export complete CV to PDF
- Test: Multiple templates work
- Test: Customization applied correctly
```

**Recovery Checkpoint 1**:
- Run: `swift test --filter PDFExport`
- Check: PDFs generate correctly on iOS
- Verify: Files in test output directory

---

### Sprint 2: Template System Integration (2 days)
**Goal**: Connect existing templates with PDF export

#### Day 1 - Template Selection
```
Commit 1: "Add TemplateSelectionUseCase"
- Get available templates
- Recommend based on CV type
- Test: Returns correct templates

Commit 2: "Add template preview generation"
- Generate preview HTML
- Test: Preview matches template
```

#### Day 2 - Customization
```
Commit 3: "Apply customization to templates"
- Use existing CustomizationOptions
- Test: Colors applied correctly
- Test: Fonts applied correctly
```

**Recovery Checkpoint 2**:
- Templates selectable
- Previews generate
- Customization works

---

### Sprint 3: Apple Intelligence Integration (3 days)
**Goal**: Add CV tailoring using Foundation Models framework

#### Day 1 - Foundation Models Setup
```
Commit 1: "Add FoundationModelsService"
- Import FoundationModels framework
- Setup @Generable structs
- Test: Service initializes

Commit 2: "Add CVTailoringPrompt struct"
@Generable
struct CVTailoringPrompt {
    let jobDescription: String
    let currentCV: CVDocument
    let targetRole: String
}
```

#### Day 2 - Tailoring Implementation
```
Commit 3: "Implement CVTailoringUseCase"
- Extract key requirements from job description
- Suggest relevant experience order
- Test: Extracts requirements correctly

Commit 4: "Add skill matching"
- Match CV skills to job requirements
- Suggest missing skills
- Test: Identifies skill gaps
```

#### Day 3 - Content Generation
```
Commit 5: "Add summary generation"
- Generate tailored summary
- Keep under 4096 tokens (model limit)
- Test: Summary is relevant

Commit 6: "Add highlight suggestions"
- Suggest which achievements to highlight
- Test: Suggestions are relevant
```

**Recovery Checkpoint 3**:
- Foundation Models integrated
- CV tailoring works offline
- All on-device, no API keys needed

---

### Sprint 4: UI Integration (3 days)
**Goal**: Add export UI to main app

#### Day 1 - Dependency Container
```
Commit 1: "Create PDFExportDependencyContainer"
- Wire all dependencies
- Integrate with PrestoCVCore container
- Test: Container builds correctly

Commit 2: "Add to ViewModelFactory"
- Create ExportViewModel
- Test: ViewModel initializes
```

#### Day 2 - Export View
```
Commit 3: "Add ExportView with template selection"
- Use existing design system components
- Show template grid
- Test: View renders

Commit 4: "Add customization controls"
- Color palette selector
- Font scheme selector
- Test: Options update preview
```

#### Day 3 - Share Sheet
```
Commit 5: "Add iOS share sheet integration"
- Use UIActivityViewController
- Support save to Files
- Test: Share sheet appears

Commit 6: "Add export history"
- Track recent exports
- Show in list
- Test: History persists
```

**Recovery Checkpoint 4**:
- Export button in CV editor
- Templates selectable
- PDF exports and shares

---

### Sprint 5: macOS Support (2 days)
**Goal**: Add macOS-specific implementations

#### Day 1 - macOS Renderer
```
Commit 1: "Add NSPrintOperationPDFRenderer"
- Use NSPrintOperation for macOS
- Test: Generates PDF on macOS

Commit 2: "Add macOS-specific UI"
- Use AppKit where needed
- Test: UI works on macOS
```

**Recovery Checkpoint 5**:
- Works on both iOS and macOS
- Platform-specific optimizations

---

### Sprint 6: Performance & Polish (2 days)
**Goal**: Optimize and finalize

#### Day 1 - Performance
```
Commit 1: "Add caching to PDF export"
- Cache generated PDFs
- Test: Cache hit improves speed

Commit 2: "Optimize HTML generation"
- Use existing ParallelProcessor
- Test: Multiple exports faster
```

#### Day 2 - Error Handling
```
Commit 3: "Add comprehensive error handling"
- User-friendly error messages
- Recovery suggestions
- Test: All errors handled

Commit 4: "Add analytics"
- Track export success/failure
- Track template usage
- Test: Events logged
```

**Final Recovery Checkpoint**:
- All tests pass
- Performance targets met
- Ready for production

---

## Recovery Instructions

### To Resume Work:
1. Check RECOVERY_LOG.md for last completed checkpoint
2. Run tests for that checkpoint: `swift test --filter [CheckpointName]`
3. Read the last 5 commits: `git log --oneline -5`
4. Continue from next uncommitted task in roadmap

### Recovery Log Format (RECOVERY_LOG.md):
```markdown
## Current Status
Sprint: 2
Checkpoint: 2
Last Commit: "Add template preview generation"
Date: 2024-01-15

## Completed:
- [x] Sprint 0: Foundation
- [x] Sprint 1: iOS Rendering
- [x] Sprint 2, Day 1: Template Selection
- [ ] Sprint 2, Day 2: Customization

## Next Task:
Commit 3: "Apply customization to templates"

## Test Status:
- All tests passing: YES
- Coverage: 87%
```

---

## Testing Strategy

### Unit Tests (TDD):
- Write test first (Red)
- Implement minimal code (Green)
- Refactor if needed (Refactor)
- One test per commit

### Integration Tests:
- Test adapter mappings
- Test use case orchestration
- Test dependency wiring

### UI Tests:
- Test export flow
- Test template selection
- Test share functionality

### Test Naming Convention:
```swift
func test_methodName_condition_expectedResult() {
    // Given
    // When
    // Then
}
```

---

## Commit Message Format:
```
[Sprint N] ComponentName: Brief description

- Specific change 1
- Specific change 2
Tests: Added/Updated/Passed
```

Example:
```
[Sprint 1] WKWebViewPDFRenderer: Add progress tracking

- Add PDFRenderingDelegate protocol
- Implement progress callbacks
- Add cancellation support
Tests: Added 3 new tests, all passing
```

---

## Definition of Done:
- [ ] Tests written and passing
- [ ] Code follows SOLID principles
- [ ] No code duplication (DRY)
- [ ] Uses Apple native components
- [ ] Documentation in code (self-documenting)
- [ ] Commit follows format
- [ ] Recovery log updated

---

## Key Apple Technologies to Use:
1. **Foundation Models** - For AI features (on-device, no cloud)
2. **PDFKit** - For PDF manipulation
3. **WebKit** - For HTML rendering (WKWebView)
4. **Combine** - For reactive programming
5. **SwiftUI** - For UI (already used)
6. **async/await** - For concurrency (already used)
7. **UIActivityViewController** - For sharing
8. **FileManager** - For storage

---

## Success Metrics:
- PDF generation < 1 second
- Memory usage < 50MB
- Test coverage > 85%
- Zero external API dependencies
- Works offline
- Supports iOS 17+ and macOS 14+

This roadmap ensures the project is:
1. **Recoverable**: Clear checkpoints and logs
2. **Testable**: TDD approach throughout
3. **Scalable**: Clean architecture
4. **Apple-native**: Uses latest Apple technologies
5. **Maintainable**: SOLID principles and clean code