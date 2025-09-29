import Foundation
import WebKit
import AppKit

// Standalone PDF generator that creates a proper PDF from HTML
@MainActor
class PDFGenerator: NSObject {
    private var webView: WKWebView!
    private var completion: ((Data?) -> Void)?

    func generatePDF(from htmlPath: String, completion: @escaping (Data?) -> Void) {
        self.completion = completion

        // Read HTML
        guard let html = try? String(contentsOfFile: htmlPath, encoding: .utf8) else {
            print("❌ Could not read HTML file")
            completion(nil)
            return
        }

        // Create window for WebView (needs to be visible for proper rendering)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )

        // Create web view
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.navigationDelegate = self
        window.contentView = webView

        // Make window visible (required for rendering)
        window.makeKeyAndOrderFront(nil)

        // Load HTML
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func createPDF() {
        // Wait for render
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }

            // Create print info
            let printInfo = NSPrintInfo()
            printInfo.paperSize = NSSize(width: 595.28, height: 841.89) // A4
            printInfo.topMargin = 20
            printInfo.bottomMargin = 20
            printInfo.leftMargin = 20
            printInfo.rightMargin = 20
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic

            // Create print operation
            let printOp = self.webView.printOperation(with: printInfo)
            printOp.showsPrintPanel = false
            printOp.showsProgressPanel = false

            // Generate PDF data
            let pdfData = self.webView.dataWithPDF(inside: self.webView.frame)

            // Save to file
            let outputPath = "/tmp/cv_export_final.pdf"
            do {
                try pdfData.write(to: URL(fileURLWithPath: outputPath))
                print("✅ PDF saved to: \(outputPath)")
                print("   Size: \(pdfData.count) bytes")
            } catch {
                print("❌ Error saving PDF: \(error)")
            }

            self.completion?(pdfData)
            NSApplication.shared.terminate(nil)
        }
    }
}

extension PDFGenerator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        createPDF()
    }
}

// Main execution
Task { @MainActor in
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)

    let generator = PDFGenerator()

    generator.generatePDF(from: "/tmp/cv_preview.html") { data in
        if let data = data {
            print("📄 PDF generated: \(data.count) bytes")
            print("🔍 Open with: open /tmp/cv_export_final.pdf")
        }
    }

    app.run()
}