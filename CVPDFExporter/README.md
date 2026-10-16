# CVPDFExporter

A platform-agnostic PDF export library for CVs with beautiful, customizable templates.

## 📋 Project Purpose

CVPDFExporter is a **platform-agnostic** Swift package that provides:
- **Platform-independent PDF generation** through dependency injection
- **Professional templates** with HTML/CSS for easy customization
- **Test-first development** with comprehensive unit testing
- **Clean architecture** with dependency inversion principle
- **Zero platform dependencies** - works on iOS, macOS, Linux, or any Swift platform
- **Minimal user customization** to ensure professional output

This package uses **dependency injection** for PDF rendering, allowing consuming apps to provide their own platform-specific implementations while keeping the library completely platform-agnostic.

---

## 🏗️ Architecture Principles

### 1. Platform Independence Through Dependency Inversion
```swift
// ❌ WRONG - Library depends on platform
class PDFEngine {
    #if canImport(UIKit)
    let renderer = WKWebViewRenderer()  // Platform coupling!
    #endif
}

// ✅ CORRECT - Platform depends on library abstraction
protocol HTMLToPDFRenderer {  // Library defines interface
    func renderToPDF(html: String) async throws -> Data
}

class PDFEngine {
    init(renderer: HTMLToPDFRenderer) {  // Injected dependency
        self.renderer = renderer
    }
}
```

### 2. Test-First Development
Every feature MUST have tests BEFORE implementation:
1. Write failing tests that define expected behavior
2. Implement minimal code to make tests pass
3. Refactor while keeping tests green
4. Never commit code without passing tests

### 3. Protocol-Oriented Design
Platform-specific code is isolated behind protocols:
- Library defines protocols (abstractions)
- App provides implementations (concrete types)
- Library never knows about UIKit, AppKit, or platform details

---

## 🚀 Quick Start

```swift
import CVPDFExporter

// App provides platform-specific renderer
let renderer = MyAppPDFRenderer()  // Your implementation

// Create engine with dependency injection
let engine = PDFExportEngineFactory.create(with: renderer)

// Export CV to PDF
let cvDocument = createCVDocument()
let pdfData = try await engine.exportToPDF(
    document: cvDocument,
    options: .default
)
```

---

## 📖 Development Workflow

### Step 1: Write Tests First (TDD)
```bash
# 1. Create test file for new feature
touch Tests/CVPDFExporterTests/NewFeatureTests.swift

# 2. Write failing tests that define behavior
# 3. Run tests to ensure they fail
swift test

# 4. See red (failing tests) ❌
```

### Step 2: Implement Feature
```bash
# 1. Write minimal code to pass tests
# 2. Keep running tests during development
swift test --filter NewFeatureTests

# 3. See green (passing tests) ✅
```

### Step 3: Refactor
```bash
# 1. Improve code while keeping tests green
# 2. Extract common patterns
# 3. Ensure no platform coupling
swift test  # Must stay green!
```

### Step 4: Integration Testing
```bash
# Test with mock renderer (platform-agnostic)
swift test

# Test with demo app (uses real renderer)
swift run --package-path ../CVPDFExporterExamples CVPDFExporterDemo

# Run on different platforms to verify
swift test --enable-test-discovery  # Linux
```

### Step 5: Commit
```bash
# Only commit when:
# ✅ All tests pass
# ✅ No platform dependencies in library
# ✅ Coverage > 70%

git add .
git commit -m "Add feature with tests"
```

---

## 🧪 Testing Strategy

### Unit Testing Architecture
```swift
// Mock renderer for testing - no platform dependencies
final class MockPDFRenderer: HTMLToPDFRenderer {
    var renderCallCount = 0
    var lastHTMLInput: String?

    func renderToPDF(html: String, options: ExportOptions) async -> Data {
        renderCallCount += 1
        lastHTMLInput = html
        return Data([0x25, 0x50, 0x44, 0x46])  // PDF header
    }
}

// Test with mock - runs anywhere
func testPDFGeneration() async throws {
    let mockRenderer = MockPDFRenderer()
    let engine = PDFExportEngineFactory.create(with: mockRenderer)

    let pdf = try await engine.exportToPDF(document: doc, options: .default)

    XCTAssertEqual(mockRenderer.renderCallCount, 1)
    XCTAssertTrue(mockRenderer.lastHTMLInput?.contains("Expected HTML"))
}
```

### Test Categories
1. **Core Tests** - Platform-agnostic, use mocks
2. **Integration Tests** - Platform-specific, in separate targets
3. **Demo App** - Manual testing with real renderers

### Coverage Requirements
- **Minimum**: 70% overall coverage
- **Core Logic**: 90% coverage
- **New Features**: 100% coverage for public API

---

## 🔌 Dependency Injection Pattern

### Library Side (Platform-Agnostic)
```swift
// Library defines protocols - no platform code!
public protocol HTMLToPDFRenderer: Sendable {
    func renderToPDF(html: String, options: ExportOptions) async throws -> Data
}

public final class PDFExportEngineImpl: PDFExportEngine {
    private let renderer: HTMLToPDFRenderer  // Injected

    public init(renderer: HTMLToPDFRenderer) {
        self.renderer = renderer  // No platform coupling!
    }
}
```

### App Side (Platform-Specific)
```swift
// App provides platform implementations
#if canImport(UIKit)
final class iOSPDFRenderer: HTMLToPDFRenderer {
    func renderToPDF(html: String, options: ExportOptions) async -> Data {
        // iOS-specific implementation using WKWebView
    }
}
#endif

// App injects renderer
let renderer = iOSPDFRenderer()
let engine = PDFExportEngineFactory.create(with: renderer)
```

---

## 📝 Development Rules

### 1. Platform Independence Rules
- **NEVER** use `#if canImport(UIKit)` in library code
- **NEVER** import platform frameworks in library
- **ALWAYS** use dependency injection for platform features
- **ALWAYS** define abstractions (protocols) in library

### 2. Testing Rules
- **NEVER** commit without tests
- **NEVER** write implementation before tests
- **ALWAYS** use mocks for unit tests
- **ALWAYS** keep platform tests separate

### 3. Architecture Rules
- **FOLLOW** SOLID principles
- **USE** dependency inversion for platform code
- **KEEP** core logic platform-agnostic
- **ISOLATE** platform code in app layer

### 4. Code Quality Rules
- **MAINTAIN** > 70% test coverage
- **WRITE** self-documenting code
- **EXTRACT** common patterns
- **AVOID** code duplication

### 5. Git Commit Rules
- **ONE** feature per commit
- **ALL** tests must pass
- **NO** platform code in library
- **CLEAR** commit messages

---

## 🏃‍♂️ Sprint Development Process

### Sprint Planning
1. **Define acceptance criteria** as tests
2. **Write failing tests** for all features
3. **Estimate based on** test complexity
4. **Track progress by** tests passing

### Daily Development
1. **Pick next failing test**
2. **Write minimal code** to pass
3. **Refactor** if needed
4. **Commit** when green

### Sprint Review
- **All tests passing** = Sprint complete
- **Coverage maintained** > 70%
- **No platform coupling** in library
- **Demo working** with real renderer

---

## 📊 Testing Commands

```bash
# Run all tests
swift test

# Run specific test
swift test --filter TestName

# Run with coverage
swift test --enable-code-coverage

# Generate coverage report
swift test --show-code-coverage

# Run tests on Linux (Docker)
docker run --rm -v "$PWD":/app -w /app swift:latest swift test

# Run demo app (macOS only): it installs the bundled templates into a temporary registry, the way
# the app does at launch, and writes one <id>_preview.png per template to Resources/Templates,
# or to the folder given as its argument
swift run --package-path ../CVPDFExporterExamples CVPDFExporterDemo [output folder]

# Build for all platforms
swift build
swift build -c release

# Verify no warnings
swift build -Xswiftc -warnings-as-errors
```

---

## 🚫 What NOT to Do

### Never Add Platform Code to Library
```swift
// ❌ WRONG - Platform code in library
import UIKit  // Never in library!

class PDFEngine {
    func render() {
        let renderer = UIGraphicsBeginPDF()  // Platform coupling!
    }
}
```

### Never Skip Tests
```swift
// ❌ WRONG - Implementation without tests
func newFeature() {
    // Complex logic without tests
}

// ✅ CORRECT - Test first
func testNewFeature() {
    // Define expected behavior
}
```

### Never Couple to Concrete Types
```swift
// ❌ WRONG - Depends on concrete type
class Engine {
    let renderer: WKWebViewRenderer  // Concrete coupling!
}

// ✅ CORRECT - Depends on abstraction
class Engine {
    let renderer: HTMLToPDFRenderer  // Protocol abstraction
}
```

---

## ✅ Definition of Done

A feature is complete when:
1. ✅ **Tests written** and passing (TDD)
2. ✅ **No platform code** in library
3. ✅ **Protocols defined** for abstractions
4. ✅ **Mocks created** for testing
5. ✅ **Coverage > 70%** maintained
6. ✅ **Demo updated** if needed
7. ✅ **Documentation** updated
8. ✅ **Code reviewed** for SOLID principles
9. ✅ **Integration tested** with real renderer
10. ✅ **Committed** with clear message

---

## 📚 Architecture Documentation

### Clean Architecture Layers
```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│         (Demo App, Tests)               │
├─────────────────────────────────────────┤
│         Application Layer               │
│    (PDFExportEngine, Use Cases)        │
├─────────────────────────────────────────┤
│           Domain Layer                  │
│   (Models, Protocols, Business Logic)   │
├─────────────────────────────────────────┤
│         Infrastructure Layer            │
│   (Injected from App - Renderers)      │
└─────────────────────────────────────────┘
```

### Dependency Flow
```
App Layer (Concrete) → Library Layer (Abstract)
    ↓                         ↓
iOS/macOS Renderer  →  HTMLToPDFRenderer Protocol
    ↓                         ↓
Injected into       →  PDFExportEngine
```

---

## 📞 Support

For questions about:
- **Architecture**: Review this README's principles
- **Testing**: Check test examples in Tests/
- **Platform Integration**: See Demo/PlatformRenderer.swift
- **Dependency Injection**: Review factory pattern

Remember:
- Library = Platform-agnostic abstractions
- App = Platform-specific implementations
- Tests = Mock implementations

---

## License

Copyright © 2024 PrestoCV. All rights reserved.

---

**Last Updated**: 2024-11-27
**Version**: 2.0.0 (Dependency Injection Architecture)
**Status**: Active Development