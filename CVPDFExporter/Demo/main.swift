import Foundation
import CVPDFExporter

@MainActor
func runDemo() async throws {
    print("🚀 CVPDFExporter Demo - Sprint 0")
    print("=" * 50)

    // Check platform capabilities
    print("\n🖥️  Platform Info:")
    print("  Platform: \(PDFExportCapabilities.rendererName)")
    print("  PDF Export Available: \(PDFExportCapabilities.isAvailable)")

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

    // Only attempt PDF generation if supported on platform
    if PDFExportCapabilities.isAvailable {
        // Create PDF export engine
        let engine = PDFExportEngineFactory.create()

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
    } else {
        print("\n⚠️  PDF export not available on this platform")
        print("    Data validation completed successfully")
    }

    print("\n✨ Demo completed successfully!")
}

// Main entry point
@main
struct DemoApp {
    static func main() async {
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