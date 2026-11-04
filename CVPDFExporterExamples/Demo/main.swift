import Foundation
import CVPDFExporter

func runDemo() async throws {
    print("🚀 CVPDFExporter Demo - Dependency Injection")
    print("=" * 50)

    // The app provides its own renderer - the library doesn't care about platform
    print("\n🖥️  Platform Info:")
    print("  Renderer: \(PlatformRendererFactory.rendererName)")
    print("  Library is platform-agnostic ✅")

    // Create adapter and get sample CV data
    let adapter = PrestoCVCoreAdapter()
    let cvDocument = adapter.convertToCV(from: nil)

    print("\n📄 Document Info:")
    print("  Name: \(cvDocument.personalInfo.name)")
    print("  Email: \(cvDocument.personalInfo.email)")
    print("  Sections: \(cvDocument.sections.count)")

    print("\n📋 Sections:")
    for section in cvDocument.sections {
        print("  - \(section.title) (\(section.items.count) items)")
    }

    // Create renderer (app responsibility, not library)
    print("\n🔧 Creating platform-specific renderer...")
    let renderer = PlatformRendererFactory.createRenderer()
    print("  ✅ Renderer created: \(type(of: renderer))")

    // Create PDF export engine with injected renderer
    print("\n💉 Injecting renderer into PDF engine...")
    let engine = PDFExportEngineFactory.create(with: renderer)
    print("  ✅ Engine created with dependency injection")

    // Test different export configurations
    let configurations: [(String, ExportOptions)] = [
        ("A4 with default margins", .default),
        ("Letter with narrow margins", ExportOptions(pageSize: .letter, margins: .uniform(36))),
        ("A4 with wide margins", ExportOptions(pageSize: .a4, margins: .uniform(108)))
    ]

    for (name, options) in configurations {
        print("\n📐 Exporting with \(name)...")

        let startTime = Date()
        let pdfData = try await engine.exportToPDF(document: cvDocument, options: options)
        let endTime = Date()

        let timeElapsed = endTime.timeIntervalSince(startTime)
        let sizeKB = Double(pdfData.count) / 1024.0

        print("  ✅ Success!")
        print("  ⏱️  Time: \(String(format: "%.2f", timeElapsed))s")
        print("  📦 Size: \(String(format: "%.1f", sizeKB)) KB")

        // Save to file for inspection
        let fileName = "cv_\(name.replacingOccurrences(of: " ", with: "_")).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try pdfData.write(to: url)
        print("  💾 Saved to: \(url.path)")
    }

    print("\n✨ Demo completed successfully!")
}

// Main entry point
@main
struct DemoApp {
    static func main() async {
        // Run the template preview generator
        #if canImport(AppKit)
        await GenerateTemplatePreviews.main()
        #else
        print("❌ Template preview generation requires macOS (AppKit)")
        exit(1)
        #endif
        return

        // Original demo below (disabled)
        do {
            try await runDemo()
        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
    }
}

// String repeat extension for demo output
extension String {
    static func * (left: String, right: Int) -> String {
        String(repeating: left, count: right)
    }
}