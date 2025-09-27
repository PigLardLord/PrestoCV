#if canImport(UIKit) && canImport(WebKit)
import UIKit
import WebKit

// MARK: - WKWebView PDF Renderer

/// Concrete implementation of HTMLToPDFRenderer using WKWebView
/// Sprint 0: Basic PDF generation from HTML
@MainActor
public class WKWebViewPDFRenderer: NSObject, HTMLToPDFRenderer {

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Void, Never>?

    public override init() {
        super.init()
    }

    public func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        // Create web view configuration
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true

        // Create web view with A4 size frame
        let pageSize = options.pageSize.dimensions
        let frame = CGRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)
        let webView = WKWebView(frame: frame, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView

        // Load HTML
        webView.loadHTMLString(html, baseURL: nil)

        // Wait for content to load
        await waitForLoad()

        // Generate PDF
        let printFormatter = webView.viewPrintFormatter()
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)

        // Configure page rect and printable rect
        let paperRect = CGRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)
        let printableRect = CGRect(
            x: options.margins.left,
            y: options.margins.top,
            width: pageSize.width - options.margins.left - options.margins.right,
            height: pageSize.height - options.margins.top - options.margins.bottom
        )

        renderer.setValue(paperRect, forKey: "paperRect")
        renderer.setValue(printableRect, forKey: "printableRect")

        // Create PDF context
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)

        // Render pages
        for pageIndex in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            let bounds = UIGraphicsGetPDFContextBounds()
            renderer.drawPage(at: pageIndex, in: bounds)
        }

        UIGraphicsEndPDFContext()

        // Clean up
        self.webView = nil

        return pdfData as Data
    }

    private func waitForLoad() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}

// MARK: - WKNavigationDelegate

extension WKWebViewPDFRenderer: WKNavigationDelegate {

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