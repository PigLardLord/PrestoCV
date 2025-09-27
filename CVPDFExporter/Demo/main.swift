#if canImport(UIKit)
import Foundation
import CVPDFExporter

@MainActor
func runDemo() async throws {
    print("🚀 CVPDFExporter Demo - Sprint 0")
    print("=" * 50)

    // Create adapter and get sample CV data
    let adapter = PrestoCVCoreAdapter()
    let cvDocument = adapter.convertToCV(from: nil)

    print("\n📄 Document Info:")
    print("  Name: \(cvDocument.personalInfo.name)")
    print("  Email: \(cvDocument.personalInfo.email)")
    print("  Sections: \(cvDocument.sections.count)")

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
#else
// macOS demo version
import Foundation
import CVPDFExporter

func runDemo() async throws {
    print("🚀 CVPDFExporter Demo - Sprint 0 (macOS)")
    print(String(repeating: "=", count: 50))

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

    print("\n📊 Sample Data Verification:")
    print("  ✓ Personal info loaded")
    print("  ✓ Work experience: \(cvDocument.sections.first { $0.type == .work }?.items.count ?? 0) positions")
    print("  ✓ Education: \(cvDocument.sections.first { $0.type == .education }?.items.count ?? 0) entries")
    print("  ✓ Skills: \(cvDocument.sections.first { $0.type == .skills }?.items.count ?? 0) categories")

    print("\n⚠️  Note: PDF rendering is only available on iOS")
    print("    Run this demo on an iOS device or simulator for full functionality")

    print("\n✨ Demo data validation completed!")
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
#endif