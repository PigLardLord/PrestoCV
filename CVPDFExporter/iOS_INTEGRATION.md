# iOS Integration Guide for CVPDFExporter

## Quick Start

The CVPDFExporter library provides a complete solution for exporting CVs to PDF with QuickLook preview on iOS.

### 1. Basic Integration (SwiftUI)

```swift
import CVPDFExporter

// In your view, just add the export button:
CVExportButton(
    cvData: yourCVModel,
    templateId: "modern",
    customization: CustomizationOptions()
)
```

That's it! The button will:
- ✅ Convert your CV data to PDF
- ✅ Show a loading indicator while generating
- ✅ Display the PDF in QuickLook automatically
- ✅ Allow sharing via the standard iOS share sheet

### 2. UIKit Integration

```swift
import CVPDFExporter

class YourViewController: UIViewController {
    let exportManager = CVExportManager()

    @IBAction func exportButtonTapped(_ sender: UIButton) {
        Task {
            try await exportManager.exportAndPreview(
                cvData: yourCVModel,
                templateId: "modern",
                customization: CustomizationOptions(),
                from: self
            )
        }
    }
}
```

## Features

### 📱 Native iOS Experience
- Uses WKWebView for high-quality PDF rendering
- QuickLook integration for native PDF preview
- Share sheet support for sending via email, AirDrop, etc.

### 🎨 Templates
Three built-in templates:
- **Modern**: Clean design with gradient header
- **Professional**: Corporate-friendly layout
- **Minimal**: Simple and elegant

### 🎯 Customization
```swift
let customization = CustomizationOptions(
    colorPalette: .professional,  // or .modern, .creative, .minimal
    fontScheme: .modern           // or .classic, .serif
)
```

### 🚀 Performance
- Automatic caching of generated PDFs
- Renderer pooling for memory efficiency
- Background PDF generation

## Complete Example

```swift
import SwiftUI
import CVPDFExporter

struct CVExportView: View {
    @State private var selectedTemplate = "modern"
    @State private var colorPalette = ColorPalette.professional

    var body: some View {
        VStack(spacing: 20) {
            // Your CV preview UI

            // Export button with customization
            CVExportButton(
                cvData: getCVData(),
                templateId: selectedTemplate,
                customization: CustomizationOptions(
                    colorPalette: colorPalette,
                    fontScheme: .modern
                )
            )
        }
    }

    func getCVData() -> Any {
        // Return your CV model from PrestoCVCore
        return CVModel(...)
    }
}
```

## How It Works

1. **User taps Export button**
   - Shows loading indicator

2. **PDF Generation**
   - Converts CV data to structured document
   - Applies selected template
   - Renders HTML to PDF using WKWebView

3. **QuickLook Preview**
   - Automatically opens PDF in QuickLook
   - User can zoom, scroll, and share

4. **Sharing**
   - Built-in share button in QuickLook
   - Send via email, Messages, AirDrop
   - Save to Files app
   - Print directly

## Requirements

- iOS 16.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/CVPDFExporter.git", from: "1.0.0")
]
```

## Advanced Usage

### Custom Templates

You can create custom templates:

```swift
let customTemplate = Template(
    id: "custom",
    name: "My Template",
    description: "Custom design",
    htmlContent: yourHTMLString,
    supportedVariables: [...]
)
```

### Direct PDF Export (without QuickLook)

```swift
let exportManager = CVExportManager()
let pdfData = try await exportManager.exportToPDF(
    cvData: yourCVModel,
    templateId: "modern"
)
// Use pdfData as needed
```

### Error Handling

```swift
do {
    try await exportManager.exportAndPreview(...)
} catch PDFExportError.timeout {
    // Handle timeout
} catch PDFExportError.invalidContent(let message) {
    // Handle invalid content
} catch {
    // Handle other errors
}
```

## Testing

The library includes comprehensive tests. To run on iOS Simulator:

```bash
xcodebuild test -scheme CVPDFExporter -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Architecture

The library uses Clean Architecture with:
- **Domain Layer**: Use cases and protocols
- **Application Layer**: Template engine and adapters
- **Infrastructure Layer**: iOS-specific renderers

## Support

For issues or questions, please open an issue on GitHub.