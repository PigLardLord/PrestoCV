#if os(macOS)   // macOS-only adapter (PlatformAdapters): the whole file is platform-guarded
import AppKit
import WebKit
import CVRendering
import CVRenderingWebKitSupport

/// The macOS PDF renderer (ADR 0003). The HTML is loaded into a secure web view (ValidatingBoundary) and paginated by the print system
/// at the page size, so the design's page-break rules apply. The page count comes from the PDF itself; a document
/// longer than the page limit keeps its first pages and reports how many it needed.
public struct MacPDFRenderer: PDFRendering {
    public enum Failure: Error, Equatable, Sendable { case invalidPageSetup, tooManyPrints, printFailed, printTimedOut, unreadableOutput }

    /// How long each step of a render may take before it fails.
    public struct Timeouts: Sendable, Equatable {
        public var load: Duration, readiness: Duration, printing: Duration

        public init(load: Duration = .seconds(30), readiness: Duration = .seconds(10), printing: Duration = .seconds(60)) {
            self.load = load; self.readiness = readiness; self.printing = printing
        }
    }

    private let engine: MacPrintEngine

    /// - Parameters:
    ///   - rules: the list the composition root compiled once (DIP).
    ///   - timeouts: how long loading, readiness and printing may each take.
    @MainActor
    public init(rules: WKContentRuleList, timeouts: Timeouts = Timeouts()) {
        engine = MacPrintEngine(rules: rules, timeouts: timeouts)
    }

    /// Cancellation, before or during the work, ends in `CancellationError`.
    public func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        try Task.checkCancellation()
        return try await engine.render(html, page)
    }
}

/// Does the work on the main actor, where WebKit and the print system live.
@MainActor
final class MacPrintEngine {
    let rules: WKContentRuleList
    let timeouts: MacPDFRenderer.Timeouts

    init(rules: WKContentRuleList, timeouts: MacPDFRenderer.Timeouts) {
        self.rules = rules; self.timeouts = timeouts
    }

    func render(_ html: String, _ page: PageSetup) async throws -> RenderedPDF {
        guard page.isPrintable else { throw MacPDFRenderer.Failure.invalidPageSetup }
        // A print AppKit never finishes keeps its window and web view; bounding the prints still running bounds that.
        // This early check saves a load; the print job enforces the limit where it starts a print.
        guard PrintJob.runningCount < PrintJob.maxRunning else { throw MacPDFRenderer.Failure.tooManyPrints }
        let frame = NSRect(x: 0, y: 0, width: page.widthPoints, height: page.heightPoints)
        let view = WKWebView(frame: frame, configuration: SecureWebViewConfiguration.make(rules: rules))
        let navigation = SingleLoadNavigationDelegate()
        let job = PrintJob.makeOffscreen(holding: view, navigation: navigation, frame: frame)
        defer { job.release() }

        try await load(html, in: view, using: navigation)
        try await awaitReadiness(of: view)
        try Task.checkCancellation()
        let full = try await printPages(view, job: job, page)
        try Task.checkCancellation()
        let rendered = try await PDFFirstPages.keep(of: full, upTo: page.maxPages)
        try Task.checkCancellation()
        return rendered
    }

    private func load(_ html: String, in view: WKWebView, using navigation: SingleLoadNavigationDelegate) async throws {
        do { try await navigation.load(html, in: view, timeout: timeouts.load) }
        catch .cancelled { throw CancellationError() }
    }

    private func awaitReadiness(of view: WKWebView) async throws {
        do { try await DocumentReadiness.wait(in: view, timeout: timeouts.readiness) }
        catch .cancelled { throw CancellationError() }
    }

    /// Prints every page into the job's file, asynchronously: a synchronous print waits on the web content process,
    /// which needs this run loop, and never returns.
    private func printPages(_ view: WKWebView, job: PrintJob, _ page: PageSetup) async throws -> Data {
        let info = NSPrintInfo()
        info.paperSize = NSSize(width: page.widthPoints, height: page.heightPoints)
        info.topMargin = page.verticalMarginPoints; info.bottomMargin = page.verticalMarginPoints
        info.leftMargin = 0; info.rightMargin = 0   // the design's padding
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false; info.isVerticallyCentered = false
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = job.file
        let operation = view.printOperation(with: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        operation.view?.frame = NSRect(x: 0, y: 0, width: page.widthPoints, height: page.heightPoints)

        switch await job.run(operation, timeout: timeouts.printing) {
        case .printed(true): break
        case .printed(false): throw MacPDFRenderer.Failure.printFailed
        case .timedOut: throw MacPDFRenderer.Failure.printTimedOut
        case .cancelled: throw CancellationError()
        case .refused: throw MacPDFRenderer.Failure.tooManyPrints
        }
        do { return try Data(contentsOf: job.file) } catch { throw MacPDFRenderer.Failure.unreadableOutput }
    }
}

private extension PageSetup {
    /// At least one page, a width, and a height that the two vertical margins leave room in.
    var isPrintable: Bool { maxPages >= 1 && widthPoints > 0 && heightPoints > 2 * verticalMarginPoints }
}
#endif
