#if canImport(AppKit)
import Foundation
import CVPDFExporter
import AppKit
import WebKit

/// Generate PNG preview images for all bundled templates
/// This tool renders each template with sample CV data and creates preview images
@MainActor
struct GenerateTemplatePreviews {

    static func main() async {
        print("🎨 Template Preview Generator")
        print(String(repeating: "=", count: 50))

        do {
            // 1. Load all bundled templates
            print("\n📚 Loading bundled templates...")
            let repository = BundledTemplateRepository()
            let templates = try await repository.getTemplates()
            print("✅ Found \(templates.count) templates: \(templates.map { $0.name }.joined(separator: ", "))")

            // 2. Create sample CV data
            print("\n📝 Creating sample CV data...")
            let cvDocument = SampleCVData.complete
            print("✅ Sample CV ready: \(cvDocument.personalInfo.name)")

            // 3. Set up template engine
            let templateEngine = MustacheTemplateEngine()

            // 4. Define color schemes for each template
            let colorSchemes: [String: CustomizationOptions] = [
                "professional": CustomizationOptions(
                    colorPalette: .professional,
                    fontScheme: .classic
                ),
                "modern": CustomizationOptions(
                    colorPalette: .modern,
                    fontScheme: .modern
                ),
                "minimal": CustomizationOptions(
                    colorPalette: .minimal,
                    fontScheme: .classic
                )
            ]

            // 5. Generate preview for each template
            let outputDir = outputDirectory()

            // Ensure output directory exists
            try FileManager.default.createDirectory(
                atPath: outputDir,
                withIntermediateDirectories: true,
                attributes: nil
            )

            for template in templates {
                print("\n🎨 Generating preview for: \(template.name)")

                // Get customization for this template
                let customization = colorSchemes[template.id] ?? CustomizationOptions()

                // Render HTML
                print("  🔧 Rendering HTML...")
                let html = try await templateEngine.render(
                    template: template,
                    data: cvDocument,
                    customization: customization
                )
                print("  ✅ HTML rendered (\(html.count) bytes)")

                // Generate PNG preview
                let outputPath = "\(outputDir)/\(template.id)_preview.png"
                print("  📸 Creating PNG snapshot...")

                let success = try await generatePNGPreview(
                    html: html,
                    outputPath: outputPath
                )

                if success {
                    // Get file size
                    let attributes = try FileManager.default.attributesOfItem(atPath: outputPath)
                    let fileSize = attributes[.size] as? Int ?? 0
                    let sizeKB = Double(fileSize) / 1024.0

                    print("  ✅ Preview saved: \(template.id)_preview.png (\(String(format: "%.1f", sizeKB)) KB)")
                } else {
                    print("  ❌ Failed to generate preview for \(template.name)")
                }
            }

            // 6. Generate default template preview (copy of professional)
            print("\n🎨 Generating default template preview...")
            if let professionalPath = templates.first(where: { $0.id == "professional" }) {
                let customization = colorSchemes["professional"] ?? CustomizationOptions()
                let html = try await templateEngine.render(
                    template: professionalPath,
                    data: cvDocument,
                    customization: customization
                )

                let defaultOutputPath = "\(outputDir)/default_template_preview.png"
                let success = try await generatePNGPreview(
                    html: html,
                    outputPath: defaultOutputPath
                )

                if success {
                    print("  ✅ Default preview saved: default_template_preview.png")
                }
            }

            // 7. Summary
            print("\n" + String(repeating: "=", count: 50))
            print("✨ Preview generation complete!")
            print("\nGenerated files in:")
            print("  \(outputDir)")
            print("\nPreviews created:")
            for template in templates {
                print("  • \(template.id)_preview.png")
            }
            print("  • default_template_preview.png")

        } catch {
            print("\n❌ Error: \(error)")
            print("   \(error.localizedDescription)")
            exit(1)
        }
    }

    /// The folder the previews go to: the first command-line argument, or else the exporter's template resources in
    /// this repository (`CVPDFExporter/Resources/Templates`), found from where this source file is.
    private static func outputDirectory() -> String {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.count > 1 {
            return arguments[1]
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Demo
            .deletingLastPathComponent()  // CVPDFExporterExamples
            .deletingLastPathComponent()  // the repository root
            .appendingPathComponent("CVPDFExporter/Resources/Templates")
            .path
    }

    /// Generate a PNG preview from HTML using WKWebView snapshot
    private static func generatePNGPreview(html: String, outputPath: String) async throws -> Bool {
        let generator = PreviewSnapshotGenerator()
        return try await generator.snapshot(html: html, outputPath: outputPath)
    }
}

/// Helper class to generate PNG snapshots from HTML using WKWebView
@MainActor
private class PreviewSnapshotGenerator: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Void, Never>?

    func snapshot(html: String, outputPath: String) async throws -> Bool {
        // Create web view configuration
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true

        // A4 size in points at 72 DPI: 595 x 842
        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 595, height: 842),
            configuration: configuration
        )
        webView.navigationDelegate = self
        self.webView = webView

        // Load HTML
        webView.loadHTMLString(html, baseURL: nil)

        // Wait for content to load
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }

        // Additional wait for rendering to complete
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Take snapshot
        let config = WKSnapshotConfiguration()
        config.rect = CGRect(x: 0, y: 0, width: 595, height: 842)

        return await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: config) { image, error in
                guard let image = image, error == nil else {
                    print("    ⚠️  Snapshot error: \(error?.localizedDescription ?? "unknown")")
                    continuation.resume(returning: false)
                    return
                }

                // Convert NSImage to PNG data
                guard let tiffData = image.tiffRepresentation,
                      let bitmapImage = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
                    print("    ⚠️  Failed to convert image to PNG")
                    continuation.resume(returning: false)
                    return
                }

                // Write PNG to file
                do {
                    let url = URL(fileURLWithPath: outputPath)
                    try pngData.write(to: url)
                    continuation.resume(returning: true)
                } catch {
                    print("    ⚠️  Write error: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.continuation?.resume()
            self.continuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            print("    ⚠️  Navigation failed: \(error.localizedDescription)")
            self.continuation?.resume()
            self.continuation = nil
        }
    }
}

#endif
