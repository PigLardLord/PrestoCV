#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import WebKit

// MARK: - macOS PDF Renderer

/// macOS implementation of HTMLToPDFRenderer using WKWebView
/// Sprint 0: Basic PDF generation from HTML for macOS
@MainActor
public class NSViewPDFRenderer: NSObject, HTMLToPDFRenderer {

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Void, Never>?

    public override init() {
        super.init()
    }

    public func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        // Create web view configuration
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true

        // Create web view with page size frame
        let frame = NSRect(x: 0, y: 0, width: options.pageSize.width, height: options.pageSize.height)
        let webView = WKWebView(frame: frame, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView

        // Load HTML
        webView.loadHTMLString(html, baseURL: nil)

        // Wait for content to load
        await waitForLoad()

        // Generate PDF using macOS print operation
        let printInfo = NSPrintInfo()

        // Configure page size
        printInfo.paperSize = NSSize(width: options.pageSize.width, height: options.pageSize.height)

        // Configure margins
        printInfo.topMargin = CGFloat(options.margins.top)
        printInfo.leftMargin = CGFloat(options.margins.left)
        printInfo.bottomMargin = CGFloat(options.margins.bottom)
        printInfo.rightMargin = CGFloat(options.margins.right)

        // Set print settings
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        // Generate PDF data directly from the web view
        let printRect = NSRect(x: 0, y: 0, width: options.pageSize.width, height: options.pageSize.height)
        let pdfRep = webView.dataWithPDF(inside: printRect)

        // Clean up
        self.webView = nil

        return pdfRep
    }

    private func waitForLoad() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}

// MARK: - WKNavigationDelegate

extension NSViewPDFRenderer: WKNavigationDelegate {

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