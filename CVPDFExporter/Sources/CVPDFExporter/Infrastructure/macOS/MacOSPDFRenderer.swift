#if canImport(AppKit) && canImport(WebKit)
import AppKit
import WebKit

/// macOS implementation of PDF renderer using WKWebView
@MainActor
public final class MacOSPDFRenderer: NSObject, PDFRendererProtocol {

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

        // Create web view with a large frame to fit all content
        let frame = NSRect(x: 0, y: 0, width: options.pageSize.width, height: 5000)
        let webView = WKWebView(frame: frame, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView

        // Load HTML with proper base URL for resources
        webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)

        // Wait for content to load
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }

        // Wait a bit more for JavaScript and CSS to fully render
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Get actual content dimensions
        let contentHeight: CGFloat = (try? await webView.evaluateJavaScript("""
            Math.max(
                document.body.scrollHeight,
                document.body.offsetHeight,
                document.documentElement.clientHeight,
                document.documentElement.scrollHeight,
                document.documentElement.offsetHeight
            )
        """) as? CGFloat) ?? 2000

        let contentWidth: CGFloat = (try? await webView.evaluateJavaScript("""
            Math.max(
                document.body.scrollWidth,
                document.body.offsetWidth,
                document.documentElement.clientWidth,
                document.documentElement.scrollWidth,
                document.documentElement.offsetWidth
            )
        """) as? CGFloat) ?? options.pageSize.width

        // Update web view frame to actual content size
        webView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)

        // Force layout update
        webView.layoutSubtreeIfNeeded()

        // Generate PDF using print operation for better quality
        let printInfo = NSPrintInfo()
        printInfo.paperSize = NSSize(width: options.pageSize.width, height: options.pageSize.height)
        printInfo.topMargin = CGFloat(options.margins.top)
        printInfo.leftMargin = CGFloat(options.margins.left)
        printInfo.bottomMargin = CGFloat(options.margins.bottom)
        printInfo.rightMargin = CGFloat(options.margins.right)
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        // Create print operation
        let printOperation = webView.printOperation(with: printInfo)
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false

        // Create PDF data using a different approach
        let pdfInfo = NSMutableDictionary()
        pdfInfo[kCGPDFContextTitle as String] = "CV Export"

        let pdfData = NSMutableData()

        // Create PDF graphics context
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: nil, pdfInfo as CFDictionary) else {
            // Fallback to simple dataWithPDF
            let pdfData = webView.dataWithPDF(inside: webView.frame)
            self.webView = nil
            return pdfData
        }

        // Use NSPrintOperation to generate PDF
        NSGraphicsContext.saveGraphicsState()
        let graphicsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.current = graphicsContext

        // Draw the web view's content
        let pageRect = CGRect(x: 0, y: 0, width: options.pageSize.width, height: options.pageSize.height)

        // Calculate number of pages needed
        let pageHeight = options.pageSize.height - options.margins.top - options.margins.bottom
        let numberOfPages = Int(ceil(contentHeight / pageHeight))

        for pageIndex in 0..<numberOfPages {
            pdfContext.beginPDFPage(nil)

            // Calculate the visible rect for this page
            let yOffset = CGFloat(pageIndex) * pageHeight
            let visibleRect = NSRect(
                x: 0,
                y: yOffset,
                width: contentWidth,
                height: min(pageHeight, contentHeight - yOffset)
            )

            // Draw the portion of the web view
            graphicsContext.saveGraphicsState()
            graphicsContext.cgContext.translateBy(x: CGFloat(options.margins.left), y: CGFloat(options.margins.bottom))
            graphicsContext.cgContext.translateBy(x: 0, y: -yOffset)

            webView.layer?.render(in: graphicsContext.cgContext)

            graphicsContext.restoreGraphicsState()
            pdfContext.endPDFPage()
        }

        NSGraphicsContext.restoreGraphicsState()
        pdfContext.closePDF()

        // If the complex approach resulted in small PDF, fall back to simple method
        if pdfData.length < 1000 {
            let simplePdfData = webView.dataWithPDF(inside: webView.frame)
            self.webView = nil
            return simplePdfData
        }

        self.webView = nil
        return pdfData as Data
    }

    nonisolated public var isAvailable: Bool {
        true
    }

    nonisolated public var maxPages: Int {
        100
    }
}

// MARK: - WKNavigationDelegate

extension MacOSPDFRenderer: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Give content time to fully render
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            continuation?.resume()
            continuation = nil
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume()
        continuation = nil
    }
}

#endif