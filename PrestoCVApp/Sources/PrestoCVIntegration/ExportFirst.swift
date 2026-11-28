import Synchronization
import CVRendering

/// Lets an export print before the check of the designs (#566). The check prints each bundled design through the
/// rendering gate while the app is open, and a print of the check would hold back the person's export: so a print of the
/// check waits for its turn while an export prints, and an export never waits for the check.
/// Only the prints are counted, not the whole export: an export can wait for its design's verdict, which the check gives,
/// so an export that held the check back while it waits would wait for ever.
/// The composition root makes one, and gives the export's renderer and the check's renderer through it.
public final class ExportFirst: Sendable {
    private struct State {
        var printing = 0
        var waiting: [Int: CheckedContinuation<Void, Never>] = [:]
        var nextWaiter = 0
    }

    private let state = Mutex(State())

    public init() {}

    /// The export's renderer: while one of its prints runs, the prints of the check wait.
    public func exporting(_ renderer: any PDFRendering) -> any PDFRendering { ExportRenderer(renderer: renderer, turns: self) }

    /// The check's renderer: each print waits until no export prints.
    public func checking(_ renderer: any PDFRendering) -> any PDFRendering { CheckRenderer(renderer: renderer, turns: self) }

    fileprivate func exportBegan() { state.withLock { $0.printing += 1 } }

    fileprivate func exportEnded() {
        let resumed = state.withLock { state -> [CheckedContinuation<Void, Never>] in
            state.printing -= 1
            guard state.printing == 0 else { return [] }
            defer { state.waiting = [:] }
            return Array(state.waiting.values)
        }
        for waiter in resumed { waiter.resume() }
    }

    /// Returns once no export prints. A cancelled task returns at once, with a `CancellationError`.
    @concurrent fileprivate func turn() async throws {
        while state.withLock({ $0.printing > 0 }) {
            try Task.checkCancellation()
            let id = state.withLock { state in
                defer { state.nextWaiter += 1 }
                return state.nextWaiter
            }
            await withTaskCancellationHandler {
                await withCheckedContinuation { (waiter: CheckedContinuation<Void, Never>) in
                    // The flag is set before the handler runs, and both take the lock: the waiter is resumed exactly once
                    let goesOn = state.withLock { state in
                        guard state.printing > 0, !Task.isCancelled else { return true }
                        state.waiting[id] = waiter
                        return false
                    }
                    if goesOn { waiter.resume() }
                }
            } onCancel: {
                state.withLock { $0.waiting.removeValue(forKey: id) }?.resume()
            }
        }
        try Task.checkCancellation()
    }
}

/// A print of the export: counted while it runs, so that the check's prints wait.
private struct ExportRenderer: PDFRendering {
    let renderer: any PDFRendering
    let turns: ExportFirst

    @concurrent func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        turns.exportBegan()
        defer { turns.exportEnded() }
        return try await renderer.render(html: html, page: page)
    }
}

/// A print of the check: it waits until no export prints.
private struct CheckRenderer: PDFRendering {
    let renderer: any PDFRendering
    let turns: ExportFirst

    @concurrent func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        try await turns.turn()
        return try await renderer.render(html: html, page: page)
    }
}
