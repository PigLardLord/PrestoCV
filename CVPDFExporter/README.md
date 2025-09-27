# CVPDFExporter

A native iOS/macOS PDF export system for CVs with beautiful, customizable templates.

## 📋 Project Purpose

CVPDFExporter is a Swift package that provides:
- **Fast PDF generation** from CV data using native iOS/macOS APIs
- **Professional templates** with HTML/CSS for easy customization
- **Offline-first operation** with no external dependencies
- **Commercial-friendly licensing** for App Store distribution
- **Minimal user customization** to ensure professional output

This package is designed to integrate with the PrestoCV app, providing users the ability to export their CVs as beautifully formatted PDFs ready for job applications.

---

## 🚀 Quick Start

```swift
import CVPDFExporter

// Initialize the exporter
let exporter = CVPDFExporterFactory.create()

// Export to PDF
let pdfData = try await exporter.exportToPDF(
    profile: myProfile,
    template: "professional",
    customization: ExportCustomization(
        colorPalette: .modern,
        fontScheme: .classic
    )
)
```

---

## 📖 Development Workflow

### Step 1: Read the Roadmap
Always start by reading `ROADMAP.md`:
```bash
cat ROADMAP.md | grep "Current Status" -A 10
```

The roadmap tells you:
- Current sprint and progress percentage
- Next immediate task to implement
- Complete implementation details
- Architecture decisions and rationale

### Step 2: Implement the Next Task
1. Find the next unchecked task in the current sprint
2. Implementation code is provided in the roadmap
3. Follow the exact structure and naming conventions
4. Make atomic changes (one feature per commit)

### Step 3: Test Your Changes
```bash
# Run tests before EVERY commit
swift test

# Build to ensure no compilation errors
swift build

# Run the demo app for manual testing
swift run CVPDFExporterDemo

# For iOS specific features
xcodebuild -scheme CVPDFExporter -sdk iphonesimulator test
```

### Step 4: Update the Roadmap
Mark your completed task:
```markdown
- [x] Implement WKWebViewPDFRenderer  # Changed from [ ] to [x]
```

Update the progress percentage:
```markdown
**Progress**: 45% - Core structure complete  # Update percentage
```

### Step 5: Commit Your Changes
```bash
# Stage your changes
git add .

# Commit with proper format
git commit -m "[Sprint 0] CVPDF-001: Add WKWebViewPDFRenderer

- Implement HTML to PDF conversion using WKWebView
- Add page size and margin configuration
- Include async/await support"
```

### Step 6: Repeat
Go back to Step 1 and continue with the next task.

---

## 📝 Development Rules

### 1. Clean Code Principles
- **Single Responsibility**: Each class/function does ONE thing
- **DRY**: Don't Repeat Yourself - extract common code
- **KISS**: Keep It Simple, Stupid - avoid over-engineering
- **YAGNI**: You Aren't Gonna Need It - don't add unused features

### 2. Atomic Commits
- **One feature per commit** - never mix different changes
- **Complete functionality** - each commit should build and pass tests
- **Clear commit messages** - follow the format below

### 3. Commit Message Format
```
[Sprint X] TaskID: Brief description

- Detailed point about what changed
- Another detail if needed
- Maximum 3 bullet points
```

**Examples**:
```
[Sprint 0] CVPDF-001: Add WKWebViewPDFRenderer

- Implement HTML to PDF conversion using WKWebView
- Add async/await support for iOS 16+

[Sprint 1] CVPDF-005: Convert static template to Mustache

- Add variable placeholders for CV data
- Include CSS variables for customization
```

### 4. Testing Requirements
**MANDATORY**: Before EVERY commit:
```bash
# 1. Run all tests
swift test

# 2. Verify no build warnings
swift build -Xswiftc -warnings-as-errors

# 3. Run demo app to verify functionality
swift run CVPDFExporterDemo

# 4. Check test coverage (aim for >70%)
swift test --enable-code-coverage

# 5. Check formatting (if swift-format is installed)
swift-format lint -r Sources/
```

**Never commit if**:
- Tests are failing
- Build has errors or warnings
- Demo app crashes or shows errors
- Code coverage drops below 70%
- Code doesn't match the style guide

### 5. Git Commit Rules
**NEVER mention in commits**:
- ❌ Any AI tool or coding assistant
- ❌ "Generated", "AI-assisted", or similar terms
- ❌ Co-authored-by AI references
- ❌ Emoji in commit messages

**ALWAYS include**:
- ✅ Sprint number and task ID
- ✅ Clear, professional description
- ✅ Specific technical details

### 6. Code Style Guidelines
```swift
// CORRECT: Clear, documented, testable
public struct PDFRenderer {
    private let configuration: RenderConfiguration

    public init(configuration: RenderConfiguration) {
        self.configuration = configuration
    }

    public func render(html: String) async throws -> Data {
        // Implementation
    }
}

// WRONG: Mixed responsibilities, no structure
func makePDF(html: String, options: Dictionary<String, Any>) -> Data? {
    // Doing everything in one function
}
```

---

## 🔄 Sprint Development Process

### Current Sprint Status
Check the roadmap for current sprint:
```bash
grep "Sprint.*:" ROADMAP.md | grep -v "##"
```

### Sprint Workflow
1. **Start Sprint** - Review all tasks in the sprint section
2. **Daily Work** - Complete 1-2 tasks per day
3. **Sprint Review** - Ensure all tasks are checked
4. **Sprint Close** - Update roadmap status to next sprint

### Task Completion Checklist
- [ ] Implementation complete
- [ ] Tests written and passing
- [ ] Documentation updated
- [ ] Roadmap task checked off
- [ ] Commit with proper format
- [ ] Build successful

---

## 🏗️ Architecture Overview

The package follows **Clean Architecture**:

```
Presentation → Application → Domain → Infrastructure
     ↓             ↓            ↓            ↓
  SwiftUI      Use Cases     Models    WKWebView
```

**Key Principles**:
- Domain models are independent of frameworks
- Business logic is separated from UI
- Testable components with clear interfaces
- Dependency injection for flexibility

---

## 📊 Progress Tracking

### How to Read Progress
In `ROADMAP.md`, find:
```markdown
## Current Status

**Sprint**: 0 (MVP)
**Progress**: 40% - Core structure complete
**Next Task**: Implement WKWebViewPDFRenderer
```

### How to Update Progress
After completing a task:
1. Check off the task: `[x]`
2. Calculate new percentage: `completed_tasks / total_tasks * 100`
3. Update the progress line
4. Update "Next Task" to the following unchecked item

### Sprint Transitions
When all tasks in a sprint are complete:
1. Update Sprint number
2. Reset progress to 0%
3. Set first task of new sprint as "Next Task"
4. Commit: `[Sprint X] Complete sprint X, begin sprint X+1`

---

## 🧪 Testing

### Testing Strategy
CVPDFExporter uses a comprehensive testing approach:
1. **Unit Tests** - Test individual components in isolation
2. **Integration Tests** - Test component interactions
3. **Demo App** - Manual testing and visual verification

### Running Tests
```bash
# All tests
swift test

# Specific test file
swift test --filter PDFExportTests

# With coverage
swift test --enable-code-coverage

# View coverage report
swift test --show-code-coverage

# Demo app for manual testing
swift run CVPDFExporterDemo

# iOS-specific tests
xcodebuild test -scheme CVPDFExporter -sdk iphonesimulator -enableCodeCoverage YES
```

### Test Coverage Areas
- **CVDocument Models** - Data structure validation
- **ExportOptions** - Configuration testing
- **PDFExportEngine** - Core export functionality
- **WKWebViewPDFRenderer** - HTML to PDF conversion
- **PrestoCVCoreAdapter** - Data transformation

### Test Requirements
- Each new feature needs a test
- Maintain > 70% code coverage
- Tests must be deterministic (no random failures)
- Use mock data, not real network calls
- Test both success and failure paths
- Include performance tests for critical paths

### Test Structure
```swift
func testFeatureName() {
    // Given (Arrange)
    let sut = SystemUnderTest()
    let input = TestData()

    // When (Act)
    let result = sut.process(input)

    // Then (Assert)
    XCTAssertEqual(result, expectedOutput)
}
```

### Manual Testing with Demo App
The demo app (`swift run CVPDFExporterDemo`) provides:
- Export with different page sizes (A4, Letter)
- Various margin configurations
- Performance metrics
- Output file inspection
- Visual verification of PDF quality

---

## 📦 Build & Release

### Local Development
```bash
# Clean build
swift package clean && swift build

# Release build
swift build -c release

# Generate docs
swift package generate-documentation
```

### Integration with PrestoCV
1. Add to `Package.swift` dependencies:
```swift
.package(path: "../CVPDFExporter")
```

2. Import in your code:
```swift
import CVPDFExporter
```

---

## 🐛 Debugging

### Common Issues

**WKWebView not rendering**:
- Ensure running on main thread with `@MainActor`
- Check HTML is valid with no JavaScript errors

**PDF is blank**:
- Verify HTML loads completely before rendering
- Check page size and margins are correct

**Tests failing on CI**:
- Ensure no UI tests run in headless environment
- Mock WKWebView for unit tests

---

## 📚 Documentation

### Roadmap Structure
The `ROADMAP.md` contains:
1. **Project Vision** - Goals and principles
2. **Requirements** - Complete specifications
3. **Architecture** - Technical design
4. **Sprint Plan** - Development tasks
5. **Implementation Details** - Actual code
6. **Current Status** - Where we are now

### Updating Documentation
When adding new features:
1. Update ROADMAP.md with implementation details
2. Update README.md if workflow changes
3. Add inline documentation to code
4. Update sprint progress

---

## 🔑 Key Commands Reference

```bash
# Development
swift build                     # Build package
swift test                      # Run tests
swift package clean             # Clean build

# Git
git status                      # Check changes
git add .                       # Stage all changes
git commit -m "[Sprint X] ..."  # Commit with format
git log --oneline -10          # View recent commits

# Roadmap
grep "\[ \]" ROADMAP.md        # Find uncompleted tasks
grep "Sprint.*:" ROADMAP.md    # List all sprints
tail -50 ROADMAP.md            # View current status
```

---

## 📋 Pre-Commit Checklist

Before EVERY commit, ensure:

- [ ] Code builds without warnings
- [ ] All tests pass
- [ ] Roadmap is updated
- [ ] Commit message follows format
- [ ] No AI tool references
- [ ] Changes are atomic (one feature)
- [ ] Documentation is updated if needed

---

## 🚫 What NOT to Do

1. **Don't commit broken code** - always test first
2. **Don't mix features** - one commit = one feature
3. **Don't skip tests** - write tests for new code
4. **Don't ignore warnings** - fix them immediately
5. **Don't mention AI tools** - keep commits professional
6. **Don't over-engineer** - follow YAGNI principle
7. **Don't duplicate code** - extract common functionality

---

## ✅ Definition of Done

A task is complete when:
1. ✅ Code is implemented and working
2. ✅ Tests are written and passing
3. ✅ Documentation is updated
4. ✅ Code follows style guidelines
5. ✅ Commit is atomic with proper message
6. ✅ Roadmap task is checked off
7. ✅ No warnings or errors
8. ✅ Build succeeds on all platforms

---

## 📞 Support

For questions about:
- **Architecture**: Review ROADMAP.md Architecture section
- **Implementation**: Check ROADMAP.md Implementation Details
- **Workflow**: Re-read this README
- **Specific Task**: Find it in ROADMAP.md Sprint Plan

Remember: Everything you need is documented. Read first, implement second.

---

## License

Copyright © 2024 PrestoCV. All rights reserved.

---

**Last Updated**: 2024-11-27
**Version**: 1.0.0
**Status**: Active Development