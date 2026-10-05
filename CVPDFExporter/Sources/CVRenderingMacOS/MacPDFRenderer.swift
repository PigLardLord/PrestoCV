#if os(macOS)   // macOS-only adapter (PlatformAdapters): the whole file is platform-guarded
import AppKit
import WebKit
import CVRendering
import CVRenderingWebKitSupport

/// The macOS PDF renderer (ADR 0003). The HTML is loaded into a secure web view (ValidatingBoundary) and paginated by the print system
/// at the page size, so the design's page-break rules apply. The page count comes from the PDF itself; a document
/// longer than the page limit keeps its first pages and reports how many it needed.
public struct MacPDFRenderer: PDFRendering {
    public enum Failure: Error, Equatable, Sendable {
        /// The page setup has no page, no width, or no height left once the two vertical margins are taken off.
        case invalidPageSetup
        /// Two prints are already running. A render that gave up leaves its print running until the system ends it.
        case tooManyPrints
        /// The print system reported that printing failed.
        case printFailed
        /// The print had not finished when `Timeouts.printing` passed.
        case printTimedOut
        /// The printed file cannot be read, or is not a PDF with at least one page.
        case unreadableOutput
    }

    /// How long each step of a render may take before it fails.
    public struct Timeouts: Sendable, Equatable {
        /// How long loading the document may take. A load that takes longer fails with `SingleLoadNavigationDelegate.Failure.timedOut`.
        public var load: Duration
        /// How long the page may take to become ready to print: complete, with its fonts ready. A longer wait fails
        /// with `DocumentReadiness.Failure.timedOut`.
        public var readiness: Duration
        /// How long the print may take. A longer print fails with `Failure.printTimedOut`.
        public var printing: Duration

        /// The defaults are 30 seconds to load, 10 to become ready and 60 to print.
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
        let view = WKWebView(frame: page.frame, configuration: SecureWebViewConfiguration.make(rules: rules))
        let navigation = SingleLoadNavigationDelegate()
        let job = PrintJob.makeOffscreen(holding: view, navigation: navigation, frame: page.frame)
        defer { job.release() }

        try await prepare(view, with: html, using: navigation)
        try Task.checkCancellation()
        let full = try await printPages(view, job: job, page)
        try Task.checkCancellation()
        let rendered = try await PDFFirstPages.keep(of: full, upTo: page.maxPages)
        try Task.checkCancellation()
        return rendered
    }

    /// Loads `html` and waits until the page is ready to print. A step that the task's cancellation stopped ends in
    /// `CancellationError`, as the render's contract says.
    private func prepare(_ view: WKWebView, with html: String, using navigation: SingleLoadNavigationDelegate) async throws {
        do {
            try await navigation.load(html, in: view, timeout: timeouts.load)
            try await DocumentReadiness.wait(in: view, timeout: timeouts.readiness)
        } catch SingleLoadNavigationDelegate.Failure.cancelled, DocumentReadiness.Failure.cancelled {
            throw CancellationError()
        }
    }

    /// Prints every page into the job's file, asynchronously: a synchronous print waits on the web content process,
    /// which needs this run loop, and never returns.
    private func printPages(_ view: WKWebView, job: PrintJob, _ page: PageSetup) async throws -> Data {
        let operation = view.printOperation(with: printInfo(for: page, saving: job.file))
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        operation.view?.frame = page.frame
        try await job.run(operation, timeout: timeouts.printing).requirePrinted()
        do { return try Data(contentsOf: job.file) } catch { throw MacPDFRenderer.Failure.unreadableOutput }
    }
}

/// The print settings of a job that saves the pages of `page`'s size to `file`.
@MainActor
private func printInfo(for page: PageSetup, saving file: URL) -> NSPrintInfo {
    let info = NSPrintInfo()
    info.paperSize = NSSize(width: page.widthPoints, height: page.heightPoints)
    info.topMargin = page.verticalMarginPoints; info.bottomMargin = page.verticalMarginPoints
    info.leftMargin = 0; info.rightMargin = 0   // the design's padding
    info.horizontalPagination = .fit
    info.verticalPagination = .automatic
    info.isHorizontallyCentered = false; info.isVerticallyCentered = false
    info.jobDisposition = .save
    info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = file
    return info
}

private extension PrintJob.Outcome {
    /// Returns when the print succeeded; otherwise throws what the renderer reports for the way it ended.
    func requirePrinted() throws {
        switch self {
        case .printed(true): break
        case .printed(false): throw MacPDFRenderer.Failure.printFailed
        case .timedOut: throw MacPDFRenderer.Failure.printTimedOut
        case .cancelled: throw CancellationError()
        case .refused: throw MacPDFRenderer.Failure.tooManyPrints
        }
    }
}

private extension PageSetup {
    var frame: NSRect { NSRect(x: 0, y: 0, width: widthPoints, height: heightPoints) }

    /// At least one page, a width, and a height that the two vertical margins leave room in.
    var isPrintable: Bool { maxPages >= 1 && widthPoints > 0 && heightPoints > 2 * verticalMarginPoints }
}
#endif
