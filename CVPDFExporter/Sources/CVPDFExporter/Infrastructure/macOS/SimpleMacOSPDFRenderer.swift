#if canImport(AppKit) && canImport(WebKit)
import AppKit
import WebKit

/// Simple macOS PDF renderer using WKWebView's built-in PDF generation
@MainActor
public final class SimpleMacOSPDFRenderer: NSObject, PDFRendererProtocol {

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Void, Never>?

    nonisolated public override init() {
        super.init()
    }

    public func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        // Create web view configuration
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        configuration.preferences.javaScriptEnabled = true

        // Create web view - make it wide enough for content
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 3000), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView

        // Load HTML
        webView.loadHTMLString(html, baseURL: nil)

        // Wait for content to load
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }

        // Additional wait for rendering
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Get content height
        let contentHeight = (try? await webView.evaluateJavaScript("document.documentElement.scrollHeight") as? Double) ?? 3000

        // Create print operation for PDF generation
        let printInfo = NSPrintInfo()

        // A4 size
        printInfo.paperSize = NSSize(width: 595.28, height: 841.89)
        printInfo.topMargin = 20
        printInfo.bottomMargin = 20
        printInfo.leftMargin = 20
        printInfo.rightMargin = 20

        // Configure pagination
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        // Generate PDF using print operation
        let printOp = webView.printOperation(with: printInfo)
        printOp.showsPrintPanel = false
        printOp.showsProgressPanel = false

        // Simply use dataWithPDF - it's the most reliable on macOS
        let pdfData = webView.dataWithPDF(inside: webView.frame)
        self.webView = nil
        return pdfData
    }

    nonisolated public var isAvailable: Bool {
        true
    }

    nonisolated public var maxPages: Int {
        100
    }
}

// MARK: - WKNavigationDelegate

extension SimpleMacOSPDFRenderer: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume()
        continuation = nil
    }
}

#endif