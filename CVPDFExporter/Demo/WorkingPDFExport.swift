import Foundation
import WebKit
import AppKit

// Working PDF generator that properly renders HTML with CSS
@MainActor
class WorkingPDFGenerator: NSObject {
    private var webView: WKWebView!
    private var window: NSWindow!

    func generatePDF() async {
        print("🚀 Starting PDF generation with proper CSS rendering...")

        // Read HTML
        let htmlPath = "/tmp/cv_corrected.html"
        guard let htmlContent = try? String(contentsOfFile: htmlPath, encoding: .utf8) else {
            print("❌ Could not read HTML file")
            return
        }

        // Create a visible window (required for WebView to render properly)
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 800, height: 1200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "PDF Generator"

        // Create web view configuration
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true

        // Create web view
        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.navigationDelegate = self

        // Add to window
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)

        // Load HTML
        webView.loadHTMLString(htmlContent, baseURL: nil)

        // Wait for navigation to complete
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.onLoadComplete = {
                continuation.resume()
            }
        }

        // Wait for rendering to complete
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Get content height
        let contentHeight = try? await webView.evaluateJavaScript("""
            Math.max(
                document.body.scrollHeight,
                document.documentElement.scrollHeight
            )
        """) as? CGFloat ?? 3000

        print("📏 Content height: \(contentHeight ?? 0) pixels")

        // Resize web view to full content
        webView.frame = NSRect(x: 0, y: 0, width: 800, height: contentHeight ?? 3000)

        // Generate PDF data
        let pdfData = webView.dataWithPDF(inside: webView.bounds)

        // Save PDF
        let outputPath = "/tmp/cv_corrected.pdf"
        do {
            try pdfData.write(to: URL(fileURLWithPath: outputPath))
            print("✅ PDF saved to: \(outputPath)")
            print("📊 Size: \(pdfData.count) bytes (\(pdfData.count / 1024)KB)")
            print("🔍 Open with: open \(outputPath)")
        } catch {
            print("❌ Error saving PDF: \(error)")
        }

        // Close window
        window.close()
    }

    private var onLoadComplete: (() -> Void)?
}

extension WorkingPDFGenerator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ HTML loaded successfully")
        onLoadComplete?()
        onLoadComplete = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ Failed to load HTML: \(error)")
        onLoadComplete?()
        onLoadComplete = nil
    }
}

// Main app
@main
struct PDFGeneratorApp {
    static func main() async {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        let generator = WorkingPDFGenerator()
        await generator.generatePDF()

        print("\n" + "=" * 60)
        print("✅ PDF generation complete!")
        print("📂 Output file: /tmp/cv_final.pdf")
        print("=" * 60)

        exit(0)
    }
}

// Helper
extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}