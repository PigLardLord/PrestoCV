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

    /// A job that prints from a window that holds `view`: printing a web view needs a window, and this one is never shown.
    static func makeOffscreen(holding view: WKWebView, navigation: SingleLoadNavigationDelegate, frame: NSRect) -> PrintJob {
        let window = NSWindow(contentRect: frame.offsetBy(dx: -20_000, dy: -20_000), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("cv-print-\(UUID().uuidString).pdf")
        return PrintJob(window: window, navigation: navigation, file: file)
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
                startTimer(after: timeout)
                operation.runModal(for: window, delegate: self,
                                   didRun: #selector(PrintJob.printOperationDidRun(_:success:contextInfo:)), contextInfo: nil)
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.resume(.cancelled) }
        }
    }

    private func startTimer(after timeout: Duration) {
        timer = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            self?.resume(.timedOut)
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

private extension PageSetup {
    /// At least one page, a width, and a height that the two vertical margins leave room in.
    var isPrintable: Bool { maxPages >= 1 && widthPoints > 0 && heightPoints > 2 * verticalMarginPoints }
}

/// Keeps the first pages of a PDF, off the main actor.
enum PDFFirstPages {
    /// Reads the page count from the PDF and keeps the first pages up to the limit, checking for cancellation on every
    /// page. `limit` is at least 1.
    static func keep(of full: Data, upTo limit: Int) async throws -> RenderedPDF {
        let document = try openDocument(full)
        let required = document.numberOfPages
        let kept = min(required, limit)
        guard kept < required else { return RenderedPDF(data: full, pageCount: kept, requiredPages: required) }
        return RenderedPDF(data: try copyPages(kept, of: document), pageCount: kept, requiredPages: required)
    }

    private static func openDocument(_ data: Data) throws -> CGPDFDocument {
        guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider), document.numberOfPages > 0 else {
            throw MacPDFRenderer.Failure.unreadableOutput
        }
        return document
    }

    private static func copyPages(_ count: Int, of document: CGPDFDocument) throws -> Data {
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData), let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            throw MacPDFRenderer.Failure.unreadableOutput
        }
        for number in 1...count {
            try Task.checkCancellation()
            try copyPage(number, of: document, to: context)
        }
        context.closePDF()
        return output as Data
    }

    private static func copyPage(_ number: Int, of document: CGPDFDocument, to context: CGContext) throws {
        guard let page = document.page(at: number) else { throw MacPDFRenderer.Failure.unreadableOutput }
        var box = page.getBoxRect(.mediaBox)
        context.beginPage(mediaBox: &box)
        context.drawPDFPage(page)
        context.endPage()
    }
}
#endif
