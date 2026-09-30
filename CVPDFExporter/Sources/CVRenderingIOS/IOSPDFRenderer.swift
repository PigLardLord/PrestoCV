#if os(iOS)   // iOS-only adapter (R11): the whole file is platform-guarded
import UIKit
import WebKit
import CVRendering
import CVRenderingWebKitSupport

/// The iOS PDF renderer (ADR 0003). The HTML is loaded into a secure web view (R8) and paginated by the print system
/// at the page size, so the design's page-break rules apply. The page count is the print system's; a document longer
/// than the page limit keeps its first pages and reports how many it needed.
///
/// The web view is not in a window: iOS lays it out and prints it offscreen, as the contract tests show on the
/// simulator, and a window would need a scene that an extension or a background export may not have. UIKit paginates
/// on the main actor in one synchronous step, which nothing can interrupt; the document's size is bounded
/// (`CVDocumentValidator`), and drawing stops between pages when the task is cancelled.
public struct IOSPDFRenderer: PDFRendering {
    public enum Failure: Error, Equatable, Sendable { case invalidPageSetup, nothingToPrint }

    private let engine: IOSPrintEngine

    /// `rules` is the list the composition root compiled once (R4).
    @MainActor
    public init(rules: WKContentRuleList, loadTimeout: Duration = .seconds(30), readinessTimeout: Duration = .seconds(10)) {
        engine = IOSPrintEngine(rules: rules, loadTimeout: loadTimeout, readinessTimeout: readinessTimeout)
    }

    /// Cancellation before the work, during the load or the readiness wait, or between pages ends in
    /// `CancellationError`.
    public func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        try Task.checkCancellation()
        return try await engine.render(html, page)
    }
}

/// Does the work on the main actor, where WebKit and UIKit printing live.
@MainActor
final class IOSPrintEngine {
    let rules: WKContentRuleList
    let loadTimeout: Duration, readinessTimeout: Duration

    init(rules: WKContentRuleList, loadTimeout: Duration, readinessTimeout: Duration) {
        self.rules = rules; self.loadTimeout = loadTimeout; self.readinessTimeout = readinessTimeout
    }

    func render(_ html: String, _ page: PageSetup) async throws -> RenderedPDF {
        guard page.maxPages >= 1, page.widthPoints > 0, page.heightPoints > 2 * page.verticalMarginPoints else {
            throw IOSPDFRenderer.Failure.invalidPageSetup
        }
        let paper = CGRect(x: 0, y: 0, width: page.widthPoints, height: page.heightPoints)
        let view = WKWebView(frame: paper, configuration: SecureWebViewConfiguration.make(rules: rules))
        let delegate = SingleLoadNavigationDelegate()
        do { try await delegate.load(html, in: view, timeout: loadTimeout) }
        catch .cancelled { throw CancellationError() }
        do { try await DocumentReadiness.wait(in: view, timeout: readinessTimeout) }
        catch .cancelled { throw CancellationError() }
        try Task.checkCancellation()

        let printer = PagePrintRenderer(paper: paper, margin: page.verticalMarginPoints)
        printer.addPrintFormatter(view.viewPrintFormatter(), startingAtPageAt: 0)
        let required = printer.numberOfPages
        guard required > 0 else { throw IOSPDFRenderer.Failure.nothingToPrint }
        let kept = min(required, page.maxPages)
        try Task.checkCancellation()
        printer.prepare(forDrawingPages: NSRange(location: 0, length: kept))
        var cancelled = false
        let data = UIGraphicsPDFRenderer(bounds: paper).pdfData { context in
            for index in 0..<kept {
                if Task.isCancelled { cancelled = true; return }
                context.beginPage()
                printer.drawPage(at: index, in: context.pdfContextBounds)
            }
        }
        if cancelled { throw CancellationError() }
        return RenderedPDF(data: data, pageCount: kept, requiredPages: required)
    }
}

/// A print renderer for one page size: the paper, and a printable area that keeps the vertical margin on every page.
/// The left and right margins are the design's.
final class PagePrintRenderer: UIPrintPageRenderer {
    private let paper: CGRect, printable: CGRect

    init(paper: CGRect, margin: Double) {
        self.paper = paper
        printable = CGRect(x: 0, y: margin, width: paper.width, height: paper.height - 2 * margin)
        super.init()
    }

    override var paperRect: CGRect { paper }
    override var printableRect: CGRect { printable }
}
#endif
