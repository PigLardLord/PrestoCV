# CVPDFExporter - Comprehensive Project Roadmap

## Project Vision

**Goal**: Create a fast, offline-capable PDF export system for CVs with beautiful, customizable templates.

**Core Principles**:
- ✅ Native iOS/macOS implementation (no external services)
- ✅ Offline-first (all features work without internet)
- ✅ Commercial-friendly licensing (no GPL dependencies)
- ✅ Fast rendering (< 1 second for typical CV)
- ✅ Maximum 4 pages (focused, tailored CVs)
- ✅ Designer-friendly templates (HTML/CSS)
- ✅ Minimal user customization (palettes + fonts only)

---

## Complete Requirements & Specifications

### Business Requirements
1. **Template System**
   - Start with 3 bundled templates (Professional, Modern, Minimal)
   - Future: Premium downloadable templates (paid)
   - Templates control layout and design
   - Users cannot modify template structure

2. **Customization Limits**
   - **Colors**: 4 predefined palettes only
   - **Fonts**: 3 font schemes only
   - **No custom CSS/HTML editing**
   - **No layout modifications**

3. **Performance Requirements**
   - PDF generation: < 1 second
   - Preview generation: < 500ms
   - Memory usage: < 50MB
   - Bundle size increase: < 5MB

4. **Export Requirements**
   - PDF format only initially
   - Share via iOS share sheet
   - Save to Files app
   - Print directly
   - Email attachment support

5. **CV Constraints**
   - Maximum 4 pages
   - If content exceeds 4 pages, show warning
   - Suggest content prioritization
   - Support tailored versions for specific applications

### Technical Specifications

#### Data Flow
```
PrestoCVCore Data → PrestoCVCoreAdapter → CVDocument → TemplateEngine → HTML → WKWebView → PDF
```

#### Template Variables Structure
```javascript
{
  "basics": {
    "name": "John Doe",
    "label": "Software Engineer",
    "email": "john@example.com",
    "phone": "+1 234 567 8900",
    "url": "https://johndoe.com",
    "summary": "Experienced software engineer...",
    "location": {
      "city": "San Francisco",
      "region": "CA",
      "countryCode": "US"
    },
    "profiles": [
      {
        "network": "LinkedIn",
        "url": "https://linkedin.com/in/johndoe"
      }
    ]
  },
  "sections": [
    {
      "type": "work",
      "title": "Work Experience",
      "items": [
        {
          "title": "Senior Developer",
          "subtitle": "Tech Corp",
          "startDate": "2020-01",
          "endDate": "Present",
          "description": "Leading development team...",
          "highlights": ["Achievement 1", "Achievement 2"]
        }
      ]
    }
  ],
  "customization": {
    "primaryColor": "#2C3E50",
    "secondaryColor": "#34495E",
    "accentColor": "#3498DB",
    "backgroundColor": "#FFFFFF",
    "textColor": "#333333",
    "fontFamily": "-apple-system, BlinkMacSystemFont, 'Helvetica Neue'",
    "fontSize": "11pt"
  }
}
```

#### Color Palettes (Complete Definitions)
```swift
enum ColorPalette: String, CaseIterable {
    case professional = "professional"
    case modern = "modern"
    case minimal = "minimal"
    case creative = "creative"

    var colors: (primary: String, secondary: String, accent: String, background: String, text: String) {
        switch self {
        case .professional:
            return (
                primary: "#2C3E50",      // Dark blue-gray
                secondary: "#34495E",     // Darker blue-gray
                accent: "#3498DB",        // Bright blue
                background: "#FFFFFF",    // White
                text: "#2C3E50"          // Dark blue-gray
            )
        case .modern:
            return (
                primary: "#1A5F7A",      // Teal
                secondary: "#57C4E5",     // Light blue
                accent: "#F97068",        // Coral
                background: "#FAFAFA",    // Off-white
                text: "#212121"          // Almost black
            )
        case .minimal:
            return (
                primary: "#000000",      // Black
                secondary: "#666666",     // Gray
                accent: "#000000",        // Black
                background: "#FFFFFF",    // White
                text: "#000000"          // Black
            )
        case .creative:
            return (
                primary: "#6B46C1",      // Purple
                secondary: "#9333EA",     // Lighter purple
                accent: "#F97316",        // Orange
                background: "#FEF3C7",    // Light yellow
                text: "#1F2937"          // Dark gray
            )
        }
    }
}
```

#### Font Schemes (Complete Definitions)
```swift
enum FontScheme: String, CaseIterable {
    case classic = "classic"
    case modern = "modern"
    case serif = "serif"

    var fonts: (heading: String, body: String, size: String) {
        switch self {
        case .classic:
            return (
                heading: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif",
                body: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif",
                size: "11pt"
            )
        case .modern:
            return (
                heading: "ui-rounded, 'SF Pro Rounded', -apple-system, BlinkMacSystemFont, sans-serif",
                body: "ui-sans-serif, 'SF Pro Text', -apple-system, BlinkMacSystemFont, sans-serif",
                size: "10.5pt"
            )
        case .serif:
            return (
                heading: "ui-serif, Georgia, Cambria, 'Times New Roman', Times, serif",
                body: "ui-serif, Georgia, Cambria, 'Times New Roman', Times, serif",
                size: "12pt"
            )
        }
    }
}
```

---

## Architecture Overview

### Clean Architecture Layers

```
┌─────────────────────────────────────────┐
│          Presentation Layer             │
│    (SwiftUI Views & View Models)        │
├─────────────────────────────────────────┤
│          Application Layer              │
│    (Use Cases & Coordinators)           │
├─────────────────────────────────────────┤
│           Domain Layer                  │
│   (Models, Protocols & Business Logic)  │
├─────────────────────────────────────────┤
│         Infrastructure Layer            │
│  (WKWebView, FileSystem, Adapters)      │
└─────────────────────────────────────────┘
```

### Complete File Structure

```
CVPDFExporter/
├── Package.swift
├── README.md
├── ROADMAP.md
├── Sources/
│   └── CVPDFExporter/
│       ├── Core/
│       │   ├── PDFExportEngine.swift       # Main orchestrator protocol
│       │   ├── PDFExportEngineImpl.swift   # Concrete implementation
│       │   ├── TemplateEngine.swift        # Template protocol
│       │   └── MustacheTemplateEngine.swift # Mustache implementation
│       ├── Templates/
│       │   ├── TemplateRepository.swift    # Template management protocol
│       │   ├── BundledTemplateRepository.swift # Bundle loader
│       │   ├── Template.swift              # Template model
│       │   └── Bundled/
│       │       ├── Professional.html
│       │       ├── Modern.html
│       │       └── Minimal.html
│       ├── Rendering/
│       │   ├── HTMLToPDFRenderer.swift     # Renderer protocol
│       │   ├── WKWebViewPDFRenderer.swift  # WKWebView implementation
│       │   └── PDFRenderOptions.swift      # Rendering configuration
│       ├── Models/
│       │   ├── CVDocument.swift            # Internal CV model
│       │   ├── JSONResumeDocument.swift    # JSON Resume model
│       │   ├── ExportOptions.swift         # Export configuration
│       │   ├── ColorPalette.swift          # Color palette definitions
│       │   └── FontScheme.swift            # Font scheme definitions
│       ├── Adapters/
│       │   ├── CVDataAdapter.swift         # Adapter protocol
│       │   ├── PrestoCVCoreAdapter.swift       # PrestoCVCore → CVDocument
│       │   └── JSONResumeAdapter.swift     # CVDocument ↔ JSON Resume
│       └── Utils/
│           ├── PageBreakManager.swift      # Smart page breaks
│           └── TemplateCache.swift         # Template caching
└── Tests/
    └── CVPDFExporterTests/
        ├── PDFExportTests.swift
        ├── TemplateTests.swift
        ├── AdapterTests.swift
        └── Fixtures/
            └── SampleCV.json
```

---

## Complete Implementation Details

### Sprint 0: MVP Implementation

#### Task 1: WKWebViewPDFRenderer Implementation
```swift
import WebKit
import UIKit

@MainActor
public class WKWebViewPDFRenderer: NSObject, HTMLToPDFRenderer {
    private var webView: WKWebView?

    public func renderToPDF(html: String, options: PDFRenderOptions) async throws -> Data {
        // Create web view
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842), configuration: config)
        self.webView = webView

        // Load HTML
        webView.loadHTMLString(html, baseURL: nil)

        // Wait for load
        try await waitForLoad()

        // Generate PDF
        let printFormatter = webView.viewPrintFormatter()
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)

        // Configure page
        let pageSize = options.pageSize.dimensions
        let printableRect = CGRect(
            x: options.margins.left,
            y: options.margins.top,
            width: pageSize.width - options.margins.left - options.margins.right,
            height: pageSize.height - options.margins.top - options.margins.bottom
        )
        let paperRect = CGRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)

        renderer.setValue(paperRect, forKey: "paperRect")
        renderer.setValue(printableRect, forKey: "printableRect")

        // Render to PDF
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)

        for pageIndex in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: pageIndex, in: UIGraphicsGetPDFContextBounds())
        }

        UIGraphicsEndPDFContext()

        self.webView = nil
        return pdfData as Data
    }

    private func waitForLoad() async throws {
        // Implementation with JavaScript evaluation to check ready state
    }
}
```

#### Task 2: Professional HTML Template
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        :root {
            --color-primary: #2C3E50;
            --color-secondary: #34495E;
            --color-accent: #3498DB;
            --color-background: #FFFFFF;
            --color-text: #2C3E50;
            --font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
            --font-size: 11pt;
        }

        body {
            font-family: var(--font-family);
            font-size: var(--font-size);
            color: var(--color-text);
            background: var(--color-background);
            line-height: 1.6;
            padding: 40px;
        }

        header {
            border-bottom: 3px solid var(--color-primary);
            padding-bottom: 20px;
            margin-bottom: 30px;
        }

        h1 {
            color: var(--color-primary);
            font-size: 24pt;
            font-weight: 700;
            margin-bottom: 5px;
        }

        .contact-info {
            color: var(--color-secondary);
            font-size: 10pt;
        }

        .section {
            margin-bottom: 30px;
        }

        h2 {
            color: var(--color-primary);
            font-size: 14pt;
            font-weight: 600;
            border-bottom: 1px solid #E0E0E0;
            padding-bottom: 5px;
            margin-bottom: 15px;
        }

        .item {
            margin-bottom: 20px;
        }

        .item-header {
            display: flex;
            justify-content: space-between;
            margin-bottom: 5px;
        }

        .item-title {
            font-weight: 600;
            color: var(--color-primary);
        }

        .item-subtitle {
            color: var(--color-accent);
        }

        .item-date {
            color: var(--color-secondary);
            font-size: 10pt;
        }

        .item-description {
            margin-top: 5px;
            text-align: justify;
        }

        ul {
            margin-left: 20px;
            margin-top: 5px;
        }

        @media print {
            body {
                padding: 0;
            }

            .section {
                page-break-inside: avoid;
            }

            .item {
                page-break-inside: avoid;
            }
        }
    </style>
</head>
<body>
    <header>
        <h1>John Doe</h1>
        <div class="contact-info">
            john@example.com | +1 234 567 8900 | San Francisco, CA
        </div>
    </header>

    <section class="section">
        <h2>Professional Summary</h2>
        <p>Experienced software engineer with expertise in iOS development and system architecture.</p>
    </section>

    <section class="section">
        <h2>Work Experience</h2>
        <div class="item">
            <div class="item-header">
                <div>
                    <span class="item-title">Senior iOS Developer</span>
                    <span class="item-subtitle">at Tech Corp</span>
                </div>
                <span class="item-date">2020 - Present</span>
            </div>
            <div class="item-description">
                Leading iOS development team in building scalable mobile applications.
            </div>
        </div>
    </section>
</body>
</html>
```

#### Task 3: PrestoCVCore Adapter Implementation
```swift
import Foundation

public struct PrestoCVCoreAdapter {
    public func convert(from profile: Any) -> CVDocument {
        // For now, return sample data
        // TODO: Implement actual conversion from PrestoCVCore models

        let personalInfo = PersonalInfo(
            name: "John Doe",
            email: "john@example.com",
            phone: "+1 234 567 8900",
            location: "San Francisco, CA",
            website: "https://johndoe.com",
            summary: "Experienced software engineer..."
        )

        let workSection = CVSection(
            type: .work,
            title: "Work Experience",
            items: [
                CVItem(
                    title: "Senior iOS Developer",
                    subtitle: "Tech Corp",
                    description: "Leading iOS development team...",
                    startDate: "2020-01",
                    endDate: "Present"
                )
            ]
        )

        return CVDocument(
            personalInfo: personalInfo,
            sections: [workSection],
            metadata: DocumentMetadata()
        )
    }
}
```

#### Task 4: PDFExportEngine Implementation
```swift
import Foundation

@MainActor
public class PDFExportEngineImpl: PDFExportEngine {
    private let renderer: HTMLToPDFRenderer
    private let templateRepository: TemplateRepository
    private let adapter: PrestoCVCoreAdapter

    public init() {
        self.renderer = WKWebViewPDFRenderer()
        self.templateRepository = BundledTemplateRepository()
        self.adapter = PrestoCVCoreAdapter()
    }

    public func export(
        document: CVDocument,
        templateId: String,
        options: ExportOptions
    ) async throws -> Data {
        // For Sprint 0, use hardcoded HTML
        let html = templateRepository.loadStaticHTML()

        let renderOptions = PDFRenderOptions(
            pageSize: options.pageSize,
            margins: options.margins,
            quality: options.quality
        )

        return try await renderer.renderToPDF(html: html, options: renderOptions)
    }

    public func generatePreview(
        document: CVDocument,
        templateId: String,
        size: CGSize
    ) async throws -> PreviewImage {
        // Sprint 0: Return placeholder
        return Data()
    }

    public func getAvailableTemplates(from source: URL?) async throws -> [TemplateMetadata] {
        // Sprint 0: Return empty
        return []
    }
}
```

### Mustache Integration (Sprint 1)

Since we need commercial-friendly licensing, we'll use a lightweight Mustache implementation:

```swift
// Simple Mustache renderer using JavaScript Core
import JavaScriptCore

public class MustacheTemplateEngine: TemplateEngine {
    private let context = JSContext()

    public init() {
        // Load Mustache.js (MIT licensed, 10KB minified)
        let mustacheJS = """
        // Mustache.js v4.2.0 minified
        // Add minified Mustache.js here
        """
        context?.evaluateScript(mustacheJS)
    }

    public func render(
        template: String,
        data: JSONResumeDocument,
        variables: [String: Any]
    ) throws -> String {
        let jsonData = try JSONEncoder().encode(data)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        let renderFunction = context?.objectForKeyedSubscript("Mustache")?.objectForKeyedSubscript("render")
        let result = renderFunction?.call(withArguments: [template, jsonString])

        return result?.toString() ?? ""
    }
}
```

### Template Selection UI (Sprint 1)

```swift
import SwiftUI

struct TemplateSelectionView: View {
    @State private var selectedTemplate = "professional"
    let templates = [
        ("professional", "Professional", "Clean and traditional"),
        ("modern", "Modern", "Contemporary design"),
        ("minimal", "Minimal", "Simple and elegant")
    ]

    var body: some View {
        VStack(spacing: 20) {
            ForEach(templates, id: \.0) { template in
                TemplateCard(
                    id: template.0,
                    name: template.1,
                    description: template.2,
                    isSelected: selectedTemplate == template.0
                ) {
                    selectedTemplate = template.0
                }
            }
        }
    }
}
```

### Page Break Management (Sprint 4)

```swift
public class PageBreakManager {
    public func insertPageBreaks(in html: String, maxPages: Int = 4) -> String {
        var modifiedHTML = html

        // Add CSS for page breaks
        let pageBreakCSS = """
        @media print {
            .page-break { page-break-after: always; }
            .avoid-break { page-break-inside: avoid; }
            h2 { page-break-after: avoid; }
            .item { page-break-inside: avoid; }
        }
        """

        modifiedHTML = modifiedHTML.replacingOccurrences(
            of: "</style>",
            with: "\(pageBreakCSS)\n</style>"
        )

        return modifiedHTML
    }

    public func checkPageCount(html: String) -> Int {
        // Estimate page count based on content
        // Rough calculation: ~3000 characters per page
        let contentLength = html.count
        return min(4, (contentLength / 3000) + 1)
    }
}
```

---

## Testing Implementation

### Unit Test Example
```swift
import XCTest
@testable import CVPDFExporter

final class CVDocumentTests: XCTestCase {
    func testCVDocumentCreation() {
        let personalInfo = PersonalInfo(
            name: "Test User",
            email: "test@example.com"
        )

        let document = CVDocument(
            personalInfo: personalInfo,
            sections: []
        )

        XCTAssertEqual(document.personalInfo.name, "Test User")
        XCTAssertEqual(document.personalInfo.email, "test@example.com")
    }

    func testJSONResumeConversion() {
        let adapter = JSONResumeAdapter()
        let cvDocument = createSampleCVDocument()

        let jsonResume = adapter.toJSONResume(from: cvDocument)
        XCTAssertEqual(jsonResume.basics.name, cvDocument.personalInfo.name)

        let convertedBack = adapter.fromJSONResume(jsonResume)
        XCTAssertEqual(convertedBack.personalInfo.name, cvDocument.personalInfo.name)
    }
}
```

### Integration Test Example
```swift
final class PDFExportIntegrationTests: XCTestCase {
    @MainActor
    func testPDFGeneration() async throws {
        let engine = PDFExportEngineImpl()
        let document = createSampleCVDocument()
        let options = ExportOptions.default

        let pdfData = try await engine.export(
            document: document,
            templateId: "professional",
            options: options
        )

        XCTAssertTrue(pdfData.count > 1000)
        XCTAssertTrue(pdfData.starts(with: "%PDF".data(using: .utf8)!))
    }
}
```

---

## Sprint Status

### Completed Sprints
- **Sprint 0**: Core PDFExportEngine with mock renderer ✅
- **Sprint 1**: Template system with Mustache engine ✅
- **Sprint 2**: Customization (color palettes, font schemes) ✅
- **Sprint 3**: Three complete templates (Professional, Modern, Minimal) ✅

### Completed Sprints (continued)
- **Sprint 4**: Platform-specific renderer & utilities ✅
  - [x] TestPDFRenderer for platform-agnostic testing
  - [x] Page break management with smart CSS rules
  - [x] Template caching with actor-based thread safety

### Upcoming
- **Sprint 5**: Export formats support
- **Sprint 6**: Performance optimization

---

## Commit Message Format

Each commit should follow this format:
```
[Sprint X] TaskID: Brief description

- Detailed point 1
- Detailed point 2
```

Examples:
```
[Sprint 0] CVPDF-001: Add WKWebViewPDFRenderer

- Implement HTML to PDF conversion using WKWebView
- Add page size and margin configuration
- Include async/await support

[Sprint 1] CVPDF-004: Integrate Mustache template engine

- Add JavaScriptCore-based Mustache renderer
- Support variable substitution
- Include template validation
```

---

## API Design

### Public API (for PrestoCV app integration)

```swift
// Main export function
public protocol CVPDFExporter {
    func exportToPDF(
        profile: PrestoCVProfile,
        template: String,
        customization: ExportCustomization?
    ) async throws -> Data

    func availableTemplates() -> [TemplateInfo]

    func previewTemplate(
        _ template: String,
        with profile: PrestoCVProfile
    ) async throws -> UIImage
}

// Customization options
public struct ExportCustomization {
    let colorPalette: ColorPalette
    let fontScheme: FontScheme
    let pageSize: PageSize

    public init(
        colorPalette: ColorPalette = .professional,
        fontScheme: FontScheme = .classic,
        pageSize: PageSize = .a4
    ) {
        self.colorPalette = colorPalette
        self.fontScheme = fontScheme
        self.pageSize = pageSize
    }
}

// Template information
public struct TemplateInfo {
    public let id: String
    public let name: String
    public let description: String
    public let thumbnail: UIImage?
}
```

### Usage in PrestoCV App

```swift
import CVPDFExporter

class ExportViewModel: ObservableObject {
    private let exporter = CVPDFExporterFactory.create()

    func exportCV() async {
        do {
            let customization = ExportCustomization(
                colorPalette: .modern,
                fontScheme: .classic
            )

            let pdfData = try await exporter.exportToPDF(
                profile: currentProfile,
                template: "professional",
                customization: customization
            )

            // Share PDF
            await shareController.share(pdfData, filename: "CV.pdf")
        } catch {
            // Handle error
        }
    }
}
```

---

## Package.swift Configuration

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CVPDFExporter",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CVPDFExporter",
            targets: ["CVPDFExporter"]
        )
    ],
    dependencies: [
        // No external dependencies for Sprint 0
        // Sprint 1: Consider pure Swift Mustache implementation
    ],
    targets: [
        .target(
            name: "CVPDFExporter",
            dependencies: [],
            resources: [
                .process("Templates/Bundled")
            ]
        ),
        .testTarget(
            name: "CVPDFExporterTests",
            dependencies: ["CVPDFExporter"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
```

---

## Error Handling Strategy

```swift
public enum CVPDFExportError: LocalizedError {
    case templateNotFound(String)
    case renderingFailed(String)
    case invalidContent(String)
    case pageLimitExceeded(current: Int, maximum: Int)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .templateNotFound(let id):
            return "Template '\(id)' not found"
        case .renderingFailed(let reason):
            return "PDF rendering failed: \(reason)"
        case .invalidContent(let reason):
            return "Invalid CV content: \(reason)"
        case .pageLimitExceeded(let current, let maximum):
            return "CV exceeds \(maximum) pages (current: \(current)). Please reduce content."
        case .networkError(let reason):
            return "Network error: \(reason)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .pageLimitExceeded:
            return "Consider creating a tailored version for this application"
        default:
            return nil
        }
    }
}
```

---

## Testing Strategy

### Comprehensive Testing Approach
CVPDFExporter uses a multi-layered testing strategy to ensure quality:

1. **Unit Tests** (70% coverage minimum)
   - Model validation (CVDocument, ExportOptions)
   - Component isolation (PDFExportEngine, Renderers)
   - Data transformation (Adapters)

2. **Integration Tests**
   - End-to-end PDF generation
   - Template rendering verification
   - Performance benchmarks

3. **Demo Application**
   - Manual visual verification
   - Performance metrics collection
   - Export quality assessment

### Test Coverage Requirements
- **Sprint 0**: Core functionality (>70% coverage) ✅
- **Sprint 1**: Template system (>80% coverage) ✅
- **Sprint 2**: Customization (>85% coverage) ✅
- **Sprint 3**: Templates implementation (>85% coverage) ✅
- **Sprint 4**: Platform renderer & utilities (>85% coverage) ✅

### Testing Before Each Commit
```bash
# 1. Run all tests
swift test

# 2. Check coverage
swift test --enable-code-coverage

# 3. Run demo for visual verification
swift run CVPDFExporterDemo

# 4. Verify no warnings
swift build -Xswiftc -warnings-as-errors
```

---

## Build Commands

```bash
# Sprint 0 - Build and test
cd CVPDFExporter
swift build
swift test

# Run full test suite with coverage
swift test --enable-code-coverage
swift test --show-code-coverage

# Run demo app
swift run CVPDFExporterDemo

# Check for warnings
swift build -Xswiftc -warnings-as-errors

# Build for iOS
xcodebuild -scheme CVPDFExporter -sdk iphoneos -configuration Release

# Run specific test
swift test --filter CVPDFExporterTests.PDFExportTests

# Generate documentation
swift package generate-documentation

# Clean build
swift package clean
rm -rf .build

# Format code
swift-format -i -r Sources/ Tests/
```

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2024-11-27 | Use WKWebView over UIMarkupTextPrintFormatter | Better image support, more reliable |
| 2024-11-27 | Mustache over Handlebars | Simpler, truly logic-less, lighter weight |
| 2024-11-27 | Bundled templates initially | Offline-first, faster, no server dependency |
| 2024-11-27 | Limited customization | Ensures quality, reduces complexity |
| 2024-11-27 | 4-page maximum | Forces focused, tailored CVs |
| 2024-11-27 | Native Swift implementation | Avoid external dependencies, commercial-friendly |
| 2024-11-27 | JavaScriptCore for Mustache | Built-in, no external dependency, MIT-compatible |
| 2024-11-27 | HTML/CSS templates | Designer-friendly, universal tooling |
| 2024-11-27 | Sprint-based development | Incremental value delivery, reduced risk |

---

## Next Immediate Actions

1. **Create WKWebViewPDFRenderer.swift** with the implementation above
2. **Create Professional.html** template in Templates/Bundled/
3. **Implement PrestoCVCoreAdapter.swift** with basic conversion
4. **Wire up PDFExportEngineImpl.swift**
5. **Add basic test** to verify PDF generation
6. **Commit**: "[Sprint 0] CVPDF-001: Implement WKWebViewPDFRenderer"

---

## Contact & Support

**Project**: PrestoCV
**Module**: CVPDFExporter
**Status**: Active Development - Sprint 0
**Last Updated**: 2024-11-27

---

**Legend**:
- ✅ Completed
- 🚧 In Progress
- ⏳ Planned
- 🔮 Future/Backlog
- ❌ Cancelled/Rejected