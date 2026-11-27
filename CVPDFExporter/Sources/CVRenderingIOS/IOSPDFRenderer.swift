#if os(iOS)   // iOS-only adapter (R11): the whole file is platform-guarded
import UIKit
import WebKit
import CVRendering
import CVRenderingWebKitSupport

/// The iOS PDF renderer (ADR 0003). The HTML is loaded into a secure web view (R8) and paginated by the print system
/// at the page size, so the design's page-break rules apply. A document longer than the page limit keeps its first
/// pages and reports how many it needed.
public struct IOSPDFRenderer: PDFRendering {
    public enum Failure: Error, Equatable, Sendable { case invalidPageSetup, nothingToPrint, unreadableOutput }

    private let engine: IOSPrintEngine

    /// `rules` is the list the composition root compiled once (R4).
    @MainActor
    public init(rules: WKContentRuleList, loadTimeout: Duration = .seconds(30), readinessTimeout: Duration = .seconds(10)) {
        engine = IOSPrintEngine(rules: rules, loadTimeout: loadTimeout, readinessTimeout: readinessTimeout,
                                isCancelled: { _ in Task.isCancelled })
    }

    /// A renderer over a given engine: the tests choose where it sees a cancellation.
    init(engine: IOSPrintEngine) { self.engine = engine }

    /// Cancellation, before or during the work, ends in `CancellationError`.
    public func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        try Task.checkCancellation()
        return try await engine.render(html, page)
    }
}

/// Does the work on the main actor, where WebKit and the print system live.
@MainActor
final class IOSPrintEngine {
    /// Where the synchronous part of a render looks for a cancellation: after the load, before each page, and once the
    /// PDF is drawn and read back, so a cancellation during the last page still ends in `CancellationError`.
    enum CancellationPoint: Equatable, Sendable { case afterLoad, beforePage(Int), beforeReturn }

    /// Renders between the start of their load and their end. The tests read it to cancel a render that is working.
    private(set) static var rendersInFlight = 0

    let rules: WKContentRuleList
    let loadTimeout: Duration, readinessTimeout: Duration
    /// Whether the render was cancelled, asked at each point; the renderer asks the task.
    let isCancelled: @MainActor (CancellationPoint) -> Bool

    init(rules: WKContentRuleList, loadTimeout: Duration, readinessTimeout: Duration,
         isCancelled: @escaping @MainActor (CancellationPoint) -> Bool) {
        self.rules = rules; self.loadTimeout = loadTimeout; self.readinessTimeout = readinessTimeout
        self.isCancelled = isCancelled
    }

    func render(_ html: String, _ page: PageSetup) async throws -> RenderedPDF {
        guard page.maxPages >= 1, page.widthPoints > 0, page.heightPoints > 2 * page.verticalMarginPoints else {
            throw IOSPDFRenderer.Failure.invalidPageSetup
        }
        Self.rendersInFlight += 1
        defer { Self.rendersInFlight -= 1 }
        let paper = CGRect(x: 0, y: 0, width: page.widthPoints, height: page.heightPoints)
        // The print formatter lays the page out at the web view's width. The view is never shown: printing on iOS
        // needs no window, and the readiness wait needs no animation frame.
        let view = WKWebView(frame: paper, configuration: SecureWebViewConfiguration.make(rules: rules))
        let delegate = SingleLoadNavigationDelegate()
        // The web view holds its navigation delegate weakly: it must refuse every later navigation until the end (R8).
        defer { withExtendedLifetime(delegate) {} }

        do { try await delegate.load(html, in: view, timeout: loadTimeout) }
        catch .cancelled { throw CancellationError() }
        do { try await DocumentReadiness.wait(in: view, timeout: readinessTimeout) }
        catch .cancelled { throw CancellationError() }
        try stopIfCancelled(at: .afterLoad)

        let renderer = PagePrintRenderer(paper: paper, verticalMargin: page.verticalMarginPoints)
        let formatter = view.viewPrintFormatter()
        formatter.maximumContentWidth = paper.width   // the left and right margins are the design's padding
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        let required = renderer.numberOfPages
        guard required > 0 else { throw IOSPDFRenderer.Failure.nothingToPrint }
        let kept = min(required, page.maxPages)
        let data = try draw(renderer, pages: kept)
        try await Self.check(data, holds: kept)
        try stopIfCancelled(at: .beforeReturn)
        return RenderedPDF(data: data, pageCount: kept, requiredPages: required)
    }

    private func stopIfCancelled(at point: CancellationPoint) throws {
        if isCancelled(point) { throw CancellationError() }
    }

    /// Draws the first `pages` pages, checking for cancellation before each one.
    private func draw(_ renderer: PagePrintRenderer, pages: Int) throws -> Data {
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: pages))
        var cancelled = false
        let data = UIGraphicsPDFRenderer(bounds: renderer.paperRect).pdfData { context in
            for index in 0..<pages {
                if isCancelled(.beforePage(index)) { cancelled = true; return }
                context.beginPage()
                renderer.drawPage(at: index, in: renderer.paperRect)
            }
        }
        if cancelled { throw CancellationError() }
        return data
    }

    /// The PDF must read back with the pages it was drawn with.
    /// Core Graphics parses the whole PDF to count its pages, and needs no main thread for it, so the check runs off
    /// the main actor: WebKit's load and UIKit's print layout before it are what must stay there.
    @concurrent private nonisolated static func check(_ data: Data, holds pages: Int) async throws {
        guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider),
              document.numberOfPages == pages else {
            throw IOSPDFRenderer.Failure.unreadableOutput
        }
    }
}

/// A print renderer with a fixed paper and printable area, which `UIPrintPageRenderer` otherwise takes from a printer.
/// Every page keeps the vertical margin free at its top and bottom; the left and right margins are the design's.
private final class PagePrintRenderer: UIPrintPageRenderer {
    private let paper: CGRect, printable: CGRect

    init(paper: CGRect, verticalMargin: Double) {
        self.paper = paper
        printable = paper.insetBy(dx: 0, dy: verticalMargin)
        super.init()
    }

    override var paperRect: CGRect { paper }
    override var printableRect: CGRect { printable }
}
#endif
