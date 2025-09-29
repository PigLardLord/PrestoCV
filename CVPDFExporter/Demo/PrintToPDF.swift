import Foundation
import WebKit
import AppKit
import Quartz

// PDF generator using NSPrintOperation to file
@MainActor
class PrintToPDFGenerator: NSObject {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var continuation: CheckedContinuation<Void, Never>?

    func generatePDF() async {
        print("🖨️ Starting Print-to-PDF generation...")

        // Read HTML
        let htmlPath = "/tmp/cv_preview.html"
        guard let htmlContent = try? String(contentsOfFile: htmlPath, encoding: .utf8) else {
            print("❌ Could not read HTML file")
            return
        }

        // Create window
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 595, height: 842),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Generating PDF..."

        // Configure web view
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]

        window.contentView = webView
        window.makeKeyAndOrderFront(nil)

        // Load HTML
        webView.loadHTMLString(htmlContent, baseURL: nil)

        // Wait for load
        await withCheckedContinuation { cont in
            self.continuation = cont
        }

        // Wait for rendering
        print("⏳ Waiting for content to render...")
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // Get content size
        let height = try? await webView.evaluateJavaScript("document.body.scrollHeight") as? CGFloat ?? 842

        // Resize to content
        window.setContentSize(NSSize(width: 595, height: min(height, 3000)))
        webView.frame = window.contentView!.bounds

        // Create print info
        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: 595.28, height: 841.89) // A4
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic

        // Set output to PDF file
        let outputPath = "/tmp/cv_print.pdf"
        printInfo.dictionary()[.jobDisposition] = NSPrintInfo.JobDisposition.save
        printInfo.dictionary().setObject(URL(fileURLWithPath: outputPath), forKey: .jobSavingURL as NSCopying)

        // Create and configure print operation
        let printOp = webView.printOperation(with: printInfo)
        printOp.showsPrintPanel = false
        printOp.showsProgressPanel = false

        // Run print operation
        print("📄 Running print operation...")
        printOp.run()

        // Verify file was created
        if FileManager.default.fileExists(atPath: outputPath) {
            let attributes = try? FileManager.default.attributesOfItem(atPath: outputPath)
            let size = attributes?[.size] as? Int ?? 0
            print("✅ PDF created: \(outputPath)")
            print("📊 Size: \(size) bytes (\(size/1024)KB)")
        } else {
            print("❌ PDF file not created")
        }

        // Alternative: Create PDF using view's print operation
        print("\n🎯 Trying alternative PDF generation...")
        let pdfInfo = [
            kCGPDFContextCreator: "CVPDFExporter",
            kCGPDFContextTitle: "CV Export"
        ] as CFDictionary

        let pdfURL = URL(fileURLWithPath: "/tmp/cv_alternative.pdf")
        if let consumer = CGDataConsumer(url: pdfURL as CFURL),
           let pdfContext = CGContext(consumer: consumer, mediaBox: nil, pdfInfo) {

            let pageRect = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)

            // Begin PDF
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
            NSGraphicsContext.current = nsContext

            pdfContext.beginPDFPage(nil)

            // Draw web view content
            if let layer = webView.layer {
                layer.render(in: pdfContext)
            }

            pdfContext.endPDFPage()
            pdfContext.closePDF()
            NSGraphicsContext.restoreGraphicsState()

            print("✅ Alternative PDF created: /tmp/cv_alternative.pdf")
        }

        window.close()
        print("\n✨ Done! Check the generated PDFs:")
        print("  • /tmp/cv_print.pdf")
        print("  • /tmp/cv_alternative.pdf")
    }
}

extension PrintToPDFGenerator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ Page loaded")
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ Load failed: \(error)")
        continuation?.resume()
        continuation = nil
    }
}

// Main
@main
struct App {
    static func main() async {
        NSApplication.shared.setActivationPolicy(.regular)

        let generator = PrintToPDFGenerator()
        await generator.generatePDF()

        exit(0)
    }
}