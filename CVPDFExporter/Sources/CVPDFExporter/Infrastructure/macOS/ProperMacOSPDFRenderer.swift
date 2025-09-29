#if canImport(AppKit) && canImport(WebKit)
import AppKit
import WebKit

/// Proper macOS PDF renderer that actually captures WKWebView content
@MainActor
public final class ProperMacOSPDFRenderer: NSObject, PDFRendererProtocol {

    private var webView: WKWebView?
    private var window: NSWindow?
    private var continuation: CheckedContinuation<Void, Never>?

    nonisolated public override init() {
        super.init()
    }

    public func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        // Create an actual window (required for proper rendering)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: options.pageSize.width, height: options.pageSize.height * 2),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        self.window = window

        // Configure web view
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Create web view in the window
        let webView = WKWebView(frame: window.contentLayoutRect, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView

        // Add to window
        window.contentView = webView
        window.orderBack(nil) // Show window in background

        // Load HTML
        webView.loadHTMLString(html, baseURL: nil)

        // Wait for load
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }

        // Wait for JavaScript and CSS to render
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Get actual content size via JavaScript
        let contentHeight = try? await webView.evaluateJavaScript("""
            Math.max(
                document.body.scrollHeight,
                document.documentElement.scrollHeight,
                document.body.offsetHeight,
                document.documentElement.offsetHeight
            )
        """) as? CGFloat ?? options.pageSize.height * 3

        // Update frame to content size
        webView.frame = NSRect(x: 0, y: 0, width: options.pageSize.width, height: contentHeight ?? 2000)
        window.setContentSize(NSSize(width: options.pageSize.width, height: contentHeight ?? 2000))

        // Force re-layout
        webView.needsLayout = true
        webView.layoutSubtreeIfNeeded()

        // Wait a bit more for layout
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Create PDF using print operation
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

        // Create a temporary file for PDF output
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        // Run the print operation synchronously
        printOperation.run()

        // After print operation, get the PDF data directly from the web view
        // The print operation prepares the view for PDF export

        // Fallback: Use dataWithPDF directly
        let pdfData = webView.dataWithPDF(inside: webView.bounds)

        // Clean up
        window.close()
        self.window = nil
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
extension ProperMacOSPDFRenderer: WKNavigationDelegate {
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