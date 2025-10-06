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
    private var javascriptContinuation: CheckedContinuation<String?, Error>?
    private var renderReadyContinuation: CheckedContinuation<Void, Error>?
    private var renderReadyTimeoutTask: Task<Void, Never>?
    private var isRenderReady = false
    private let pageBreakManager: PageBreakManager

    // Configuration
    private let javascriptTimeout: TimeInterval = 5.0
    private let renderReadyTimeout: TimeInterval = 10.0
    private let pageLoadTimeout: TimeInterval = 30.0

    // MARK: - Initialization

    public override init() {
        self.pageBreakManager = PageBreakManager()
        super.init()
    }

    // MARK: - Public Methods

    /// Render HTML to PDF with enhanced features
    public func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        do {
            let enhancedHTML = pageBreakManager.insertPageBreaks(in: html)

            let webView = try await createWebView(options: options)
            prepareRenderReadiness()
            self.webView = webView
            defer {
                cleanupRenderReadiness(for: webView)
                self.webView = nil
            }

            try await loadHTML(enhancedHTML, in: webView)
            try await waitForJavaScriptRendering(in: webView)
            try await adjustContentForPagination(in: webView, options: options)

            return try await generatePDF(from: webView, options: options)
        } catch {
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

        // Inject render readiness helper
        let readinessScript = """
            (function() {
                if (window.__cvWaitForRender) { return; }

                window.__cvWaitForRender = function() {
                    if (window.__cvRenderPromise) { return window.__cvRenderPromise; }

                    window.__cvRenderPromise = new Promise((resolve) => {
                        const notifyReady = () => {
                            if (window.__cvRenderReadySignaled) { return; }
                            window.__cvRenderReadySignaled = true;

                            requestAnimationFrame(() => requestAnimationFrame(() => resolve(true)));

                            try {
                                const handlers = window.webkit && window.webkit.messageHandlers;
                                if (handlers && handlers.renderReady) {
                                    handlers.renderReady.postMessage(null);
                                }
                            } catch (error) {
                                // Ignore message handler failures
                            }
                        };

                        const waitForImages = () => {
                            const images = Array.from(document.images || []);
                            if (images.length === 0) { return Promise.resolve(); }
                            return Promise.all(images.map(image => {
                                if (image.complete) { return Promise.resolve(); }
                                return new Promise(innerResolve => {
                                    image.addEventListener('load', innerResolve, { once: true });
                                    image.addEventListener('error', innerResolve, { once: true });
                                });
                            }));
                        };

                        const domReady = new Promise(resolve => {
                            if (document.readyState === 'complete') {
                                resolve();
                            } else {
                                window.addEventListener('load', resolve, { once: true });
                            }
                        });

                        const fontsReady = (document.fonts && document.fonts.ready)
                            ? document.fonts.ready.catch(() => {})
                            : Promise.resolve();

                        Promise.all([domReady, fontsReady, waitForImages()])
                            .then(notifyReady)
                            .catch(notifyReady);
                    });

                    return window.__cvRenderPromise;
                };
            })();
        """

        let readinessUserScript = WKUserScript(
            source: readinessScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(readinessUserScript)
        userContentController.add(self, name: "renderReady")

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
            Task { [weak self] in
                guard let self else { return }
                try await Task.sleep(nanoseconds: UInt64(pageLoadTimeout * 1_000_000_000))
                if let continuation = self.loadContinuation {
                    continuation.resume(throwing: PDFExportError.renderingFailed("HTML load timed out"))
                    self.loadContinuation = nil
                }
            }

            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func waitForJavaScriptRendering(in webView: WKWebView) async throws {
        if isRenderReady {
            isRenderReady = false
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            renderReadyContinuation = continuation

            renderReadyTimeoutTask?.cancel()
            renderReadyTimeoutTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await Task.sleep(nanoseconds: UInt64(renderReadyTimeout * 1_000_000_000))
                    await self.handleRenderTimeout()
                } catch {
                    // Task cancelled - ignore
                }
            }

            startRenderReadinessMonitoring(in: webView)
        }
    }

    func startRenderReadinessMonitoring(in webView: WKWebView) {
        let startScript = """
            (function() {
                if (window.__cvWaitForRender) {
                    return window.__cvWaitForRender();
                }

                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.renderReady) {
                    window.webkit.messageHandlers.renderReady.postMessage(null);
                }

                return true;
            })();
        """

        webView.evaluateJavaScript(startScript) { [weak self] _, error in
            guard let self else { return }
            if let error {
                self.handleRenderReadyScriptError(error)
            }
        }
    }

    @MainActor
    func handleRenderReadyScriptError(_ error: Error) {
        logger.error("Render readiness script failed: \(error.localizedDescription)")
        renderReadyTimeoutTask?.cancel()
        renderReadyTimeoutTask = nil

        if let continuation = renderReadyContinuation {
            renderReadyContinuation = nil
            continuation.resume(throwing: error)
        }
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

    func evaluateJavaScript(_ script: String, in webView: WKWebView) async throws -> String? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String?, Error>) in
            self.javascriptContinuation = continuation

            // Start timeout timer
            Task { [weak self] in
                guard let self else { return }
                try await Task.sleep(nanoseconds: UInt64(javascriptTimeout * 1_000_000_000))
                if let continuation = self.javascriptContinuation {
                    continuation.resume(throwing: PDFExportError.renderingFailed("JavaScript rendering timed out"))
                    self.javascriptContinuation = nil
                }
            }

            webView.evaluateJavaScript(script) { [weak self] result, error in
                guard let self else { return }
                guard let continuation = self.javascriptContinuation else { return }

                if let error = error {
                    continuation.resume(throwing: error)
                    self.javascriptContinuation = nil
                    return
                }

                if let stringResult = result as? String {
                    continuation.resume(returning: stringResult)
                } else if let convertible = result {
                    continuation.resume(returning: String(describing: convertible))
                } else {
                    continuation.resume(returning: nil)
                }

                self.javascriptContinuation = nil
            }
        }
    }

    func generatePDF(from webView: WKWebView, options: ExportOptions) async throws -> Data {
        // Get accurate content size
        let contentSizeScript = "JSON.stringify({width: document.body.scrollWidth, height: document.body.scrollHeight})"
        let sizeResult = try await evaluateJavaScript(contentSizeScript, in: webView)

        if let jsonString = sizeResult,
           let data = jsonString.data(using: .utf8),
           let size = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let height = size["height"] as? Double {
            logger.debug("Estimated content height: \(height)")
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
            renderer.drawPage(at: pageIndex, in: paperRect)
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

// MARK: - WKScriptMessageHandler

extension EnhancedWKWebViewPDFRenderer: WKScriptMessageHandler {

    public nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "renderReady" else { return }

        Task { @MainActor [weak self] in
            self?.handleRenderReady()
        }
    }
}

// MARK: - Render Readiness Helpers

private extension EnhancedWKWebViewPDFRenderer {

    @MainActor
    func prepareRenderReadiness() {
        isRenderReady = false
        renderReadyContinuation = nil
        renderReadyTimeoutTask?.cancel()
        renderReadyTimeoutTask = nil
    }

    @MainActor
    func cleanupRenderReadiness(for webView: WKWebView) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "renderReady")

        if let continuation = renderReadyContinuation {
            renderReadyContinuation = nil
            continuation.resume(throwing: PDFExportError.renderingFailed("Render pipeline interrupted"))
        }

        renderReadyTimeoutTask?.cancel()
        renderReadyTimeoutTask = nil
        isRenderReady = false
    }

    @MainActor
    func handleRenderReady() {
        renderReadyTimeoutTask?.cancel()
        renderReadyTimeoutTask = nil

        if let continuation = renderReadyContinuation {
            renderReadyContinuation = nil
            continuation.resume(returning: ())
        } else {
            isRenderReady = true
        }
    }

    @MainActor
    func handleRenderTimeout() {
        guard let continuation = renderReadyContinuation else {
            isRenderReady = false
            return
        }

        renderReadyContinuation = nil
        continuation.resume(throwing: PDFExportError.renderingFailed("Document preparation timed out"))
    }
}

#endif
