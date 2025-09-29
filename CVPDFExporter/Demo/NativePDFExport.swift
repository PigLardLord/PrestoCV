import Foundation
import WebKit
import AppKit
import Quartz

// Native PDF generator using macOS built-in capabilities
class NativePDFGenerator: NSObject {

    func generatePDFFromHTML() {
        print("🚀 Starting native PDF generation...")

        // Read the HTML file
        let htmlPath = "/tmp/cv_preview.html"
        guard let htmlContent = try? String(contentsOfFile: htmlPath, encoding: .utf8) else {
            print("❌ Could not read HTML file")
            return
        }

        // Create an attributed string from HTML
        guard let data = htmlContent.data(using: .utf8) else {
            print("❌ Could not convert HTML to data")
            return
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            print("❌ Could not create attributed string from HTML")
            return
        }

        // Create a text view to render the content
        let textView = NSTextView()
        textView.textStorage?.setAttributedString(attributedString)

        // Set up print info for A4 page
        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: 595.28, height: 841.89) // A4 size in points
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36

        // Create print operation
        let printOp = NSPrintOperation(view: textView, printInfo: printInfo)
        printOp.showsPrintPanel = false
        printOp.showsProgressPanel = false

        // Set up PDF generation
        let pdfInfo = [
            kCGPDFContextTitle: "CV Export",
            kCGPDFContextAuthor: "CVPDFExporter",
            kCGPDFContextCreator: "macOS Native PDF Generator"
        ] as CFDictionary

        // Create PDF data
        let outputPath = "/tmp/cv_native.pdf"
        let outputURL = URL(fileURLWithPath: outputPath)

        // Use Core Graphics to create PDF
        var mediaBox = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)

        guard let pdfContext = CGContext(outputURL as CFURL, mediaBox: &mediaBox, pdfInfo) else {
            print("❌ Could not create PDF context")
            return
        }

        // Start PDF page
        pdfContext.beginPDFPage(nil)

        // Create graphics context and draw
        let graphicsContext = NSGraphicsContext(cgContext: pdfContext, flipped: true)
        NSGraphicsContext.current = graphicsContext

        // Draw the attributed string
        let drawingRect = CGRect(x: 36, y: 36, width: 595.28 - 72, height: 841.89 - 72)
        attributedString.draw(in: drawingRect)

        // End page and close PDF
        pdfContext.endPDFPage()
        pdfContext.closePDF()

        print("✅ Native PDF created: \(outputPath)")

        // Get file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: outputPath),
           let fileSize = attributes[.size] as? Int {
            print("📊 File size: \(fileSize) bytes")
        }

        print("🔍 Open with: open \(outputPath)")
    }
}

// Alternative: Use NSView's built-in PDF generation
class WebViewPDFGenerator: NSObject {
    private var webView: WKWebView?

    func generatePDF() {
        print("\n🌐 Starting WebView PDF generation...")

        // Create an off-screen web view
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = true
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 595.28, height: 841.89 * 3), configuration: config)
        webView.navigationDelegate = self
        self.webView = webView

        // Load the HTML
        let htmlPath = "/tmp/cv_preview.html"
        if let htmlContent = try? String(contentsOfFile: htmlPath, encoding: .utf8) {
            webView.loadHTMLString(htmlContent, baseURL: nil)
        } else {
            print("❌ Could not load HTML")
        }
    }

    private func savePDF() {
        guard let webView = webView else { return }

        // Use NSView's dataWithPDF to generate PDF
        let pdfData = webView.dataWithPDF(inside: webView.bounds)

        let outputPath = "/tmp/cv_webview.pdf"
        do {
            try pdfData.write(to: URL(fileURLWithPath: outputPath))
            print("✅ WebView PDF created: \(outputPath)")
            print("📊 File size: \(pdfData.count) bytes")
            print("🔍 Open with: open \(outputPath)")
        } catch {
            print("❌ Error saving PDF: \(error)")
        }
    }
}

extension WebViewPDFGenerator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait for content to fully render
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.savePDF()
        }
    }
}

// Run both generators
print("=" * 60)
print("Native macOS PDF Generation Demo")
print("=" * 60)

// Method 1: NSAttributedString approach
let nativeGenerator = NativePDFGenerator()
nativeGenerator.generatePDFFromHTML()

// Method 2: WKWebView in-memory approach
let webGenerator = WebViewPDFGenerator()
webGenerator.generatePDF()

// Keep script running for WebView to complete
RunLoop.main.run(until: Date(timeIntervalSinceNow: 3))

print("\n" + "=" * 60)
print("✅ PDF generation complete!")
print("Generated files:")
print("  1. /tmp/cv_native.pdf  - NSAttributedString method")
print("  2. /tmp/cv_webview.pdf - WKWebView method")
print("=" * 60)

// Helper for string repetition
extension String {
    static func *(left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}