#if os(macOS)   // macOS-only adapter (PlatformAdapters): the whole file is platform-guarded
import AppKit
import WebKit
import CVRenderingWebKitSupport

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
#endif
