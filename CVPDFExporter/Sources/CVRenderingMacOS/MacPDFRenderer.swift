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

    private let engine: MacPrintEngine

    /// `rules` is the list the composition root compiled once (DIP).
    @MainActor
    public init(rules: WKContentRuleList, loadTimeout: Duration = .seconds(30), readinessTimeout: Duration = .seconds(10),
                printTimeout: Duration = .seconds(60)) {
        engine = MacPrintEngine(rules: rules, loadTimeout: loadTimeout, readinessTimeout: readinessTimeout, printTimeout: printTimeout)
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
    let loadTimeout: Duration, readinessTimeout: Duration, printTimeout: Duration

    init(rules: WKContentRuleList, loadTimeout: Duration, readinessTimeout: Duration, printTimeout: Duration) {
        self.rules = rules; self.loadTimeout = loadTimeout; self.readinessTimeout = readinessTimeout; self.printTimeout = printTimeout
    }

    func render(_ html: String, _ page: PageSetup) async throws -> RenderedPDF {
        guard page.maxPages >= 1, page.widthPoints > 0, page.heightPoints > 2 * page.verticalMarginPoints else {
            throw MacPDFRenderer.Failure.invalidPageSetup
        }
        // A print AppKit never finishes keeps its window and web view; bounding the prints still running bounds that.
        // This early check saves a load; the print job enforces the limit where it starts a print.
        guard PrintJob.runningCount < PrintJob.maxRunning else { throw MacPDFRenderer.Failure.tooManyPrints }
        let frame = NSRect(x: 0, y: 0, width: page.widthPoints, height: page.heightPoints)
        let view = WKWebView(frame: frame, configuration: SecureWebViewConfiguration.make(rules: rules))
        // Printing a web view needs a window. This one is never shown.
        let window = NSWindow(contentRect: frame.offsetBy(dx: -20_000, dy: -20_000), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        let delegate = SingleLoadNavigationDelegate()
        let job = PrintJob(window: window, navigation: delegate,
                           file: FileManager.default.temporaryDirectory.appendingPathComponent("cv-print-\(UUID().uuidString).pdf"))
        defer { job.release() }

        do { try await delegate.load(html, in: view, timeout: loadTimeout) }
        catch .cancelled { throw CancellationError() }
        do { try await DocumentReadiness.wait(in: view, timeout: readinessTimeout) }
        catch .cancelled { throw CancellationError() }
        try Task.checkCancellation()
        let full = try await printPages(view, job: job, page)
        try Task.checkCancellation()
        let rendered = try await Self.keepFirstPages(of: full, upTo: page.maxPages)
        try Task.checkCancellation()
        return rendered
    }

    /// Reads the page count from the PDF and keeps the first pages up to the limit, off the main actor, checking for
    /// cancellation on every page. `limit` is at least 1.
    nonisolated static func keepFirstPages(of full: Data, upTo limit: Int) async throws -> RenderedPDF {
        guard let provider = CGDataProvider(data: full as CFData), let document = CGPDFDocument(provider), document.numberOfPages > 0 else {
            throw MacPDFRenderer.Failure.unreadableOutput
        }
        let required = document.numberOfPages
        let kept = min(required, limit)
        guard kept < required else { return RenderedPDF(data: full, pageCount: kept, requiredPages: required) }
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData), let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw MacPDFRenderer.Failure.unreadableOutput
        }
        for number in 1...kept {
            try Task.checkCancellation()
            guard let pdfPage = document.page(at: number) else { throw MacPDFRenderer.Failure.unreadableOutput }
            var box = pdfPage.getBoxRect(.mediaBox)
            context.beginPage(mediaBox: &box)
            context.drawPDFPage(pdfPage)
            context.endPage()
        }
        context.closePDF()
        return RenderedPDF(data: output as Data, pageCount: kept, requiredPages: required)
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

        switch await job.run(operation, timeout: printTimeout) {
        case .printed(true): break
        case .printed(false): throw MacPDFRenderer.Failure.printFailed
        case .timedOut: throw MacPDFRenderer.Failure.printTimedOut
        case .cancelled: throw CancellationError()
        case .refused: throw MacPDFRenderer.Failure.tooManyPrints
        }
        do { return try Data(contentsOf: job.file) } catch { throw MacPDFRenderer.Failure.unreadableOutput }
    }
}

/// One modal print. It owns the offscreen window, and through it the web view, the navigation delegate that guards it,
/// and the temporary file, and tears them down only once AppKit is done with them. A render that stops waiting, on a timeout or a cancellation, abandons the
/// job: AppKit offers no way to stop a modal print, so the job keeps what it prints from until its callback arrives, and
/// the set of running jobs keeps the job alive until then, since the operation does not retain its delegate.
@MainActor
final class PrintJob: NSObject {
    enum Outcome: Sendable { case printed(Bool), timedOut, cancelled, refused }

    /// Prints still running, abandoned ones included. A render refuses to start another past `maxRunning`.
    private static var running: Set<PrintJob> = []
    static let maxRunning = 2
    static var runningCount: Int { running.count }

    let window: NSWindow, file: URL
    private let navigation: SingleLoadNavigationDelegate   // the web view holds it weakly; it must outlive the print
    private var continuation: CheckedContinuation<Outcome, Never>?
    private var timer: Task<Void, Never>?
    private var printing = false, released = false

    init(window: NSWindow, navigation: SingleLoadNavigationDelegate, file: URL) {
        self.window = window; self.navigation = navigation; self.file = file
    }

    /// Refused when `maxRunning` prints are still running. The check and the insertion happen together on the main
    /// actor, with no suspension between them, so concurrent renders cannot exceed the limit.
    func run(_ operation: NSPrintOperation, timeout: Duration) async -> Outcome {
        guard Self.running.count < Self.maxRunning else { return .refused }
        printing = true
        Self.running.insert(self)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Outcome, Never>) in
                self.continuation = continuation
                timer = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    self?.resume(.timedOut)
                }
                operation.runModal(for: window, delegate: self,
                                   didRun: #selector(PrintJob.printOperationDidRun(_:success:contextInfo:)), contextInfo: nil)
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.resume(.cancelled) }
        }
    }

    /// The render is done with the job, whatever happened: tear down now, or when an abandoned print ends.
    func release() {
        released = true
        if !printing { tearDown() }
    }

    private func resume(_ outcome: Outcome) {
        timer?.cancel()
        continuation?.resume(returning: outcome)
        continuation = nil
    }

    /// AppKit calls this on a thread of its own, not the main thread.
    @objc nonisolated func printOperationDidRun(_ operation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
        Task { @MainActor in self.printed(success) }
    }

    private func printed(_ success: Bool) {
        printing = false
        resume(.printed(success))
        if released { tearDown() }
        Self.running.remove(self)
    }

    private func tearDown() {
        window.contentView = nil
        window.close()
        _ = unlink(file.path)
    }
}
#endif
