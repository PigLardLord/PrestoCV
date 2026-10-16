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
    private var loadTimeout: Task<Void, Never>?
    private let pageBreakManager: PageBreakManager
    private let onePageFit: OnePageFit

    // Configuration
    private let pageLoadTimeout: Duration = .seconds(30)
    private let readinessTimeout: Duration = .seconds(5)

    // MARK: - Initialization

    public override init() {
        self.pageBreakManager = PageBreakManager()
        self.onePageFit = OnePageFit()
        super.init()
    }

    // MARK: - Public Methods

    /// Render HTML to PDF with enhanced features
    public func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        do {
            let enhancedHTML = pageBreakManager.insertPageBreaks(in: html)

            let webView = try await createWebView(options: options)
            self.webView = webView
            defer {
                self.webView = nil
            }

            try await loadHTML(enhancedHTML, in: webView)
            await awaitContentReadiness(in: webView)

            let renderer = try await paginate(webView, options: options)
            return try generatePDF(with: renderer, options: options)
        } catch let error as PDFExportError {
            logger.error("PDF generation failed: \(error.localizedDescription)")
            throw error
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
        if #available(iOS 14.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            configuration.preferences.javaScriptEnabled = true
        }

        // Suppress incremental rendering for better PDF output
        configuration.suppressesIncrementalRendering = true

        // Allow inline media playback (for embedded content)
        configuration.allowsInlineMediaPlayback = true

        // Disable text size adjustment to prevent font scaling
        configuration.preferences.setValue(false, forKey: "textInteractionEnabled")

        // Create user content controller for JavaScript injection
        let userContentController = WKUserContentController()

        // Add print media CSS and disable text size adjustment
        let printMediaScript = """
            (function() {
                // Add print color adjustment
                var style = document.createElement('style');
                style.innerHTML = '@media print { * { -webkit-print-color-adjust: exact !important; color-adjust: exact !important; } }';
                document.head.appendChild(style);

                // Ensure viewport is set correctly for PDF rendering
                var viewport = document.querySelector('meta[name="viewport"]');
                if (viewport) {
                    viewport.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
                }

                // Force text size adjustment to none
                document.documentElement.style.webkitTextSizeAdjust = '100%';
                document.documentElement.style.textSizeAdjust = '100%';
                document.body.style.webkitTextSizeAdjust = '100%';
                document.body.style.textSizeAdjust = '100%';
            })();
        """
        let printMediaUserScript = WKUserScript(
            source: printMediaScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(printMediaUserScript)

        userContentController.addUserScript(
            WKUserScript(
                source: PreviewReadinessScript.bootstrap,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
        userContentController.addUserScript(
            WKUserScript(
                source: PreviewReadinessScript.scalingBootstrap,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )

        configuration.userContentController = userContentController

        // Create web view with appropriate frame
        // Use printable width (page width minus margins) to ensure content fits without scaling
        let printableWidth = options.pageSize.width - options.margins.left - options.margins.right
        let frame = CGRect(
            x: 0,
            y: 0,
            width: printableWidth,
            height: options.pageSize.height * 10 // Allow for scrolling
        )

        let webView = WKWebView(frame: frame, configuration: configuration)
        webView.navigationDelegate = self
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false

        // Disable zoom and scaling
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.zoomScale = 1.0
        webView.scrollView.bouncesZoom = false

        // Ensure consistent text rendering
        if #available(iOS 14.0, *) {
            webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }

        return webView
    }

    func loadHTML(_ html: String, in webView: WKWebView) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.loadContinuation = continuation

            // The timer ends together with the load, so it cannot fire into a later render
            let timeout = self.pageLoadTimeout
            self.loadTimeout = Task { @MainActor [weak self, timeout] in
                do {
                    try await Task.sleep(for: timeout)
                } catch {
                    return
                }
                self?.finishLoading(with: .failure(PDFExportError.renderingFailed("HTML load timed out")))
            }

            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    /// Ends the pending load, once: whichever of the navigation delegate and the timer comes first wins.
    func finishLoading(with result: Result<Void, Error>) {
        loadTimeout?.cancel()
        loadTimeout = nil

        guard let continuation = loadContinuation else { return }
        loadContinuation = nil
        continuation.resume(with: result)
    }

    /// Waits for the page to report that its fonts and images are ready, but not longer than `readinessTimeout`.
    /// The web view is never put in a window, and a page that is not shown may not run its animation frames,
    /// which the readiness script waits for; the PDF is then drawn without waiting any longer.
    func awaitContentReadiness(in webView: WKWebView) async {
        let gate = ReadinessGate()
        let timeout = readinessTimeout

        let readiness = Task { @MainActor in
            _ = try? await webView.callAsyncJavaScript(
                PreviewReadinessScript.awaitReady,
                arguments: [:],
                in: nil,
                contentWorld: .page
            )
            gate.open()
        }
        let deadline = Task { @MainActor in
            try? await Task.sleep(for: timeout)
            gate.open()
        }

        await gate.wait()
        readiness.cancel()
        deadline.cancel()
    }

    /// The pages of the CV as its design lays them out, or with the design's spacing tightened when that brings a CV
    /// of two pages onto one (`OnePageFit`)
    func paginate(_ webView: WKWebView, options: ExportOptions) async throws -> PagePrintRenderer {
        let renderer = makePrintRenderer(for: webView, options: options)
        guard onePageFit.triesTightening(pageCount: renderer.numberOfPages) else { return renderer }

        try await setTightened(true, in: webView)
        let tightened = makePrintRenderer(for: webView, options: options)
        if onePageFit.keepsTightened(pageCount: tightened.numberOfPages) {
            return tightened
        }

        try await setTightened(false, in: webView)
        return makePrintRenderer(for: webView, options: options)
    }

    /// Sets or clears the class under which the design tightens its spacing, on the root element of the page
    func setTightened(_ tightened: Bool, in webView: WKWebView) async throws {
        _ = try await webView.callAsyncJavaScript(
            "document.documentElement.classList.toggle(className, tightened);",
            arguments: ["className": OnePageFit.className, "tightened": tightened],
            in: nil,
            contentWorld: .page
        )
    }

    /// Uses UIPrintPageRenderer, which paginates at the page size with margins;
    /// WKWebView.pdf() does not respect CSS @page rules reliably.
    /// The renderer lays out the page as it is when it is made, so it is made again after the page changes.
    func makePrintRenderer(for webView: WKWebView, options: ExportOptions) -> PagePrintRenderer {
        // Configure print formatter
        let printFormatter = webView.viewPrintFormatter()

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

        // Set the maximum content width to prevent scaling
        // This ensures the content width matches the printable area
        printFormatter.maximumContentWidth = printableRect.width

        let renderer = PagePrintRenderer(paperRect: paperRect, printableRect: printableRect)
        renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)
        return renderer
    }

    func generatePDF(with renderer: PagePrintRenderer, options: ExportOptions) throws -> Data {
        let paperRect = renderer.paperRect
        let pageCount = renderer.numberOfPages
        logger.debug("Rendering \(pageCount) pages")

        guard pageCount > 0 else {
            throw PDFExportError.renderingFailed("There is nothing to print")
        }
        guard pageCount <= options.maxPages else {
            throw PDFExportError.tooManyPages(count: pageCount, limit: options.maxPages)
        }
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: pageCount))

        // Create PDF context with metadata
        let pdfData = NSMutableData()
        var pdfInfo: [String: Any] = [kCGPDFContextCreator as String: "PrestoCV"]
        if let title = options.documentTitle {
            pdfInfo[kCGPDFContextTitle as String] = title
        }
        if let author = options.documentAuthor {
            pdfInfo[kCGPDFContextAuthor as String] = author
        }

        UIGraphicsBeginPDFContextToData(pdfData, paperRect, pdfInfo)

        for pageIndex in 0..<pageCount {
            UIGraphicsBeginPDFPageWithInfo(paperRect, nil)
            renderer.drawPage(at: pageIndex, in: paperRect)
        }

        UIGraphicsEndPDFContext()

        return pdfData as Data
    }
}

// MARK: - WKNavigationDelegate

extension EnhancedWKWebViewPDFRenderer: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.debug("WebView finished loading")
        finishLoading(with: .success(()))
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("WebView failed to load: \(error.localizedDescription)")
        finishLoading(with: .failure(error))
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logger.error("WebView failed provisional navigation: \(error.localizedDescription)")
        finishLoading(with: .failure(error))
    }
}

// MARK: - Page Print Renderer

/// A print renderer with a fixed paper and printable area, which `UIPrintPageRenderer` otherwise takes from a printer
private final class PagePrintRenderer: UIPrintPageRenderer {

    private let paper: CGRect
    private let printable: CGRect

    init(paperRect: CGRect, printableRect: CGRect) {
        self.paper = paperRect
        self.printable = printableRect
        super.init()
    }

    override var paperRect: CGRect { paper }
    override var printableRect: CGRect { printable }
}

// MARK: - Readiness Gate

/// Lets a waiter continue as soon as either of two racing tasks opens it, and only once
@MainActor
private final class ReadinessGate {

    private var isOpen = false
    private var waiter: CheckedContinuation<Void, Never>?

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func open() {
        isOpen = true
        waiter?.resume()
        waiter = nil
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
