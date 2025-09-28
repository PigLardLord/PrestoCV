#if canImport(UIKit) && canImport(WebKit)
import UIKit
import WebKit
import os.log

/// Enhanced WKWebView-based PDF renderer with production features
/// Implements page break management, performance monitoring, and error handling
@MainActor
public final class EnhancedWKWebViewPDFRenderer: NSObject {

    // MARK: - Properties

    private let logger = Logger(subsystem: "CVPDFExporter", category: "PDFRenderer")
    private var webView: WKWebView?
    private var loadContinuation: CheckedContinuation<Void, Error>?
    private var javascriptContinuation: CheckedContinuation<Any?, Error>?
    private let pageBreakManager: PageBreakManager
    private let performanceMonitor: PerformanceMonitor

    // Configuration
    private let javascriptTimeout: TimeInterval = 5.0
    private let pageLoadTimeout: TimeInterval = 30.0

    // MARK: - Initialization

    public override init() {
        self.pageBreakManager = PageBreakManager()
        self.performanceMonitor = PerformanceMonitor()
        super.init()
    }

    // MARK: - Public Methods

    /// Render HTML to PDF with enhanced features
    public func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        let measurementId = await performanceMonitor.startMeasurement(operation: "pdf_render")

        do {
            // Inject page break CSS
            let enhancedHTML = await pageBreakManager.injectPageBreakCSS(into: html)

            // Configure and create web view
            let webView = try await createWebView(options: options)
            self.webView = webView

            // Load HTML with timeout
            try await loadHTML(enhancedHTML, in: webView)

            // Wait for JavaScript rendering
            try await waitForJavaScriptRendering(in: webView)

            // Adjust content for optimal pagination
            try await adjustContentForPagination(in: webView, options: options)

            // Generate PDF
            let pdfData = try await generatePDF(from: webView, options: options)

            // Record performance metrics
            await performanceMonitor.endMeasurement(id: measurementId)
            let metrics = await performanceMonitor.getMetrics()
            logger.info("PDF generation completed in \(metrics.averageTime)ms")

            // Cleanup
            self.webView = nil

            return pdfData
        } catch {
            await performanceMonitor.endMeasurement(id: measurementId)
            logger.error("PDF generation failed: \(error.localizedDescription)")
            throw PDFExportError.renderingFailed(error.localizedDescription)
        }
    }
}

// MARK: - Private Methods

private extension EnhancedWKWebViewPDFRenderer {

    func createWebView(options: ExportOptions) async throws -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Enable JavaScript for dynamic content
        configuration.preferences.javaScriptEnabled = true

        // Suppress incremental rendering for better PDF output
        configuration.suppressesIncrementalRendering = true

        // Allow inline media playback (for embedded content)
        configuration.allowsInlineMediaPlayback = true

        // Create user content controller for JavaScript injection
        let userContentController = WKUserContentController()

        // Add print media CSS
        let printMediaScript = """
            var style = document.createElement('style');
            style.innerHTML = '@media print { * { -webkit-print-color-adjust: exact !important; color-adjust: exact !important; } }';
            document.head.appendChild(style);
        """
        let printMediaUserScript = WKUserScript(
            source: printMediaScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(printMediaUserScript)

        configuration.userContentController = userContentController

        // Create web view with appropriate frame
        let frame = CGRect(
            x: 0,
            y: 0,
            width: options.pageSize.width,
            height: options.pageSize.height * 10 // Allow for scrolling
        )

        let webView = WKWebView(frame: frame, configuration: configuration)
        webView.navigationDelegate = self
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false

        return webView
    }

    func loadHTML(_ html: String, in webView: WKWebView) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.loadContinuation = continuation

            // Start timeout timer
            Task {
                try await Task.sleep(nanoseconds: UInt64(pageLoadTimeout * 1_000_000_000))
                if self.loadContinuation != nil {
                    self.loadContinuation?.resume(throwing: PDFExportError.timeout)
                    self.loadContinuation = nil
                }
            }

            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func waitForJavaScriptRendering(in webView: WKWebView) async throws {
        // Wait for any dynamic content to render
        let waitScript = """
            new Promise((resolve) => {
                if (document.readyState === 'complete') {
                    // Wait for any pending animations or async operations
                    setTimeout(() => resolve(true), 500);
                } else {
                    window.addEventListener('load', () => {
                        setTimeout(() => resolve(true), 500);
                    });
                }
            })
        """

        _ = try await evaluateJavaScript(waitScript, in: webView)
    }

    func adjustContentForPagination(in webView: WKWebView, options: ExportOptions) async throws {
        // Inject pagination optimization script
        let paginationScript = """
            (function() {
                // Avoid breaking inside certain elements
                const elements = document.querySelectorAll('h1, h2, h3, h4, h5, h6, .cv-section, .cv-item');
                elements.forEach(el => {
                    el.style.pageBreakInside = 'avoid';
                    el.style.breakInside = 'avoid';
                });

                // Add page break before major sections (except first)
                const sections = document.querySelectorAll('.cv-section:not(:first-child)');
                sections.forEach(section => {
                    const rect = section.getBoundingClientRect();
                    const pageHeight = \(options.pageSize.height - options.margins.top - options.margins.bottom);

                    // If section starts in bottom third of page, break before it
                    if (rect.top % pageHeight > pageHeight * 0.67) {
                        section.style.pageBreakBefore = 'always';
                        section.style.breakBefore = 'page';
                    }
                });

                return true;
            })()
        """

        _ = try await evaluateJavaScript(paginationScript, in: webView)
    }

    func evaluateJavaScript(_ script: String, in webView: WKWebView) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            self.javascriptContinuation = continuation

            // Start timeout timer
            Task {
                try await Task.sleep(nanoseconds: UInt64(javascriptTimeout * 1_000_000_000))
                if self.javascriptContinuation != nil {
                    self.javascriptContinuation?.resume(throwing: PDFExportError.timeout)
                    self.javascriptContinuation = nil
                }
            }

            webView.evaluateJavaScript(script) { result, error in
                if let continuation = self.javascriptContinuation {
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: result)
                    }
                    self.javascriptContinuation = nil
                }
            }
        }
    }

    func generatePDF(from webView: WKWebView, options: ExportOptions) async throws -> Data {
        // Get accurate content size
        let contentSizeScript = "JSON.stringify({width: document.body.scrollWidth, height: document.body.scrollHeight})"
        let sizeResult = try await evaluateJavaScript(contentSizeScript, in: webView)

        var contentHeight = options.pageSize.height * 10 // Default
        if let jsonString = sizeResult as? String,
           let data = jsonString.data(using: .utf8),
           let size = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let height = size["height"] as? Double {
            contentHeight = CGFloat(height)
        }

        // Configure print formatter
        let printFormatter = webView.viewPrintFormatter()
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)

        // Set up page dimensions
        let paperRect = CGRect(
            x: 0,
            y: 0,
            width: options.pageSize.width,
            height: options.pageSize.height
        )

        let printableRect = CGRect(
            x: options.margins.left,
            y: options.margins.top,
            width: options.pageSize.width - options.margins.left - options.margins.right,
            height: options.pageSize.height - options.margins.top - options.margins.bottom
        )

        renderer.setValue(paperRect, forKey: "paperRect")
        renderer.setValue(printableRect, forKey: "printableRect")

        // Create PDF context with metadata
        let pdfData = NSMutableData()
        let pdfInfo: [String: Any] = [
            kCGPDFContextCreator as String: "CVPDFExporter",
            kCGPDFContextAuthor as String: "PrestoCV App",
            kCGPDFContextTitle as String: "Curriculum Vitae"
        ]

        UIGraphicsBeginPDFContextToData(pdfData, paperRect, pdfInfo)

        // Render pages with progress tracking
        let pageCount = renderer.numberOfPages
        logger.debug("Rendering \(pageCount) pages")

        for pageIndex in 0..<min(pageCount, options.maxPages) {
            UIGraphicsBeginPDFPageWithInfo(paperRect, nil)
            let context = UIGraphicsGetCurrentContext()

            // Apply any custom transformations
            context?.translateBy(x: 0, y: paperRect.height)
            context?.scaleBy(x: 1.0, y: -1.0)

            // Draw the page
            renderer.drawPage(at: pageIndex, in: paperRect)

            // Reset transformations
            context?.scaleBy(x: 1.0, y: -1.0)
            context?.translateBy(x: 0, y: -paperRect.height)
        }

        UIGraphicsEndPDFContext()

        if pageCount > options.maxPages {
            logger.warning("Content truncated: \(pageCount) pages reduced to \(options.maxPages)")
        }

        return pdfData as Data
    }
}

// MARK: - WKNavigationDelegate

extension EnhancedWKWebViewPDFRenderer: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.debug("WebView finished loading")
        loadContinuation?.resume()
        loadContinuation = nil
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("WebView failed to load: \(error.localizedDescription)")
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logger.error("WebView failed provisional navigation: \(error.localizedDescription)")
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }
}

// MARK: - PDFRendererProtocol Conformance

extension EnhancedWKWebViewPDFRenderer: PDFRendererProtocol {

    public nonisolated var isAvailable: Bool {
        #if targetEnvironment(simulator) || os(iOS)
        return true
        #else
        return false
        #endif
    }

    public nonisolated var maxPages: Int {
        100
    }
}

#endif