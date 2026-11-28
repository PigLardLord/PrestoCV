import Synchronization
import CVRendering

/// Lets an export print before the check of the designs (#566), within the prints the renderer runs at once. The check
/// prints each bundled design through the rendering gate while the app is open, and a print of the check must neither
/// hold back the person's export nor take the place it needs (macOS's renderer refuses a print past its limit).
/// - At most `prints` prints run at once, the export's and the check's together.
/// - An export prints as soon as a place is free, before every print of the check that waits.
/// - A print of the check waits while an export prints or waits, and leaves a place for an export: it prints only while
///   fewer than `prints - 1` prints run, or none when the renderer prints one at a time.
/// - A print takes its place when it is let in, under the lock that lets the others in, and gives it back when its render
///   returns. So an export that comes once a print of the check is let in, before that print reaches the renderer, finds
///   the place taken and prints within the limit, or waits for the first place that frees.
/// - A print cancelled before it is let in gives a `CancellationError`, takes no place and never begins.
/// - Only the prints are counted, not the whole export: an export can wait for its design's verdict, which the check
///   gives, so an export that held the check back while it waits would wait for ever.
/// - A print the renderer abandons on a timeout or a cancellation gives its place back when its render returns; the
///   renderer keeps its own count of what it still prints.
/// The composition root makes one, and gives the export's renderer and the check's renderer through it.
public final class ExportFirst: Sendable {
    fileprivate enum Kind { case export, check }

    private struct Waiter {
        let id: Int
        let admit: CheckedContinuation<Bool, Never>
    }

    private struct State {
        let capacity: Int
        var exports = 0, checks = 0
        var exportsWaiting: [Waiter] = [], checksWaiting: [Waiter] = []
        var nextWaiter = 0

        /// Whether a print of `kind` may begin now, the waiters before it aside.
        func hasPlace(for kind: Kind) -> Bool {
            switch kind {
            case .export: exports + checks < capacity
            case .check: exports == 0 && exportsWaiting.isEmpty && exports + checks < max(capacity - 1, 1)
            }
        }

        /// Lets in the waiters the free places take, the exports first and each kind in the order it came, and gives
        /// them to resume outside the lock. Each one's place is taken here.
        mutating func letIn() -> [CheckedContinuation<Bool, Never>] {
            var admitted: [CheckedContinuation<Bool, Never>] = []
            while !exportsWaiting.isEmpty, hasPlace(for: .export) {
                exports += 1
                admitted.append(exportsWaiting.removeFirst().admit)
            }
            while !checksWaiting.isEmpty, hasPlace(for: .check) {
                checks += 1
                admitted.append(checksWaiting.removeFirst().admit)
            }
            return admitted
        }

        mutating func enqueue(_ waiter: Waiter, _ kind: Kind) {
            switch kind {
            case .export: exportsWaiting.append(waiter)
            case .check: checksWaiting.append(waiter)
            }
        }

        /// Takes the waiter out, when it still waits.
        mutating func remove(_ id: Int) -> Waiter? {
            if let index = exportsWaiting.firstIndex(where: { $0.id == id }) { return exportsWaiting.remove(at: index) }
            if let index = checksWaiting.firstIndex(where: { $0.id == id }) { return checksWaiting.remove(at: index) }
            return nil
        }

        mutating func giveBack(_ kind: Kind) {
            switch kind {
            case .export: exports -= 1
            case .check: checks -= 1
            }
        }
    }

    private let state: Mutex<State>

    /// - Parameter prints: How many prints the renderer runs at once; at least one.
    public init(prints: Int) { state = Mutex(State(capacity: max(prints, 1))) }

    /// The export's renderer: its prints go before the check's, within the limit.
    public func exporting(_ renderer: any PDFRendering) -> any PDFRendering { ExportRenderer(renderer: renderer, turns: self) }

    /// The check's renderer: each print waits until no export prints or waits, and leaves a place for one.
    public func checking(_ renderer: any PDFRendering) -> any PDFRendering { CheckRenderer(renderer: renderer, turns: self) }

    /// Returns once the print has its place; it must give it back with `ended(_:)`. A task cancelled before it is let in
    /// gives a `CancellationError` and takes no place.
    @concurrent fileprivate func turn(_ kind: Kind) async throws {
        try Task.checkCancellation()
        let id = state.withLock { state in
            defer { state.nextWaiter += 1 }
            return state.nextWaiter
        }
        let admitted = await withTaskCancellationHandler {
            await withCheckedContinuation { (admit: CheckedContinuation<Bool, Never>) in
                // The flag is set before the handler runs, and both take the lock: the waiter is resumed exactly once
                let resumed = state.withLock { state -> [CheckedContinuation<Bool, Never>]? in
                    guard !Task.isCancelled else { return nil }
                    state.enqueue(Waiter(id: id, admit: admit), kind)
                    return state.letIn()
                }
                guard let resumed else { return admit.resume(returning: false) }
                for waiter in resumed { waiter.resume(returning: true) }
            }
        } onCancel: {
            let (removed, resumed) = state.withLock { state in
                let removed = state.remove(id)
                return (removed, removed == nil ? [] : state.letIn())
            }
            removed?.admit.resume(returning: false)
            for waiter in resumed { waiter.resume(returning: true) }
        }
        guard admitted else { throw CancellationError() }
    }

    /// Gives the print's place back, and lets in the waiters it frees.
    fileprivate func ended(_ kind: Kind) {
        let resumed = state.withLock { state in
            state.giveBack(kind)
            return state.letIn()
        }
        for waiter in resumed { waiter.resume(returning: true) }
    }
}

/// A print of the export: it takes a place before every print of the check that waits.
private struct ExportRenderer: PDFRendering {
    let renderer: any PDFRendering
    let turns: ExportFirst

    @concurrent func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        try await turns.turn(.export)
        defer { turns.ended(.export) }
        return try await renderer.render(html: html, page: page)
    }
}

/// A print of the check: it waits until no export prints or waits, and leaves a place for one.
private struct CheckRenderer: PDFRendering {
    let renderer: any PDFRendering
    let turns: ExportFirst

    @concurrent func render(html: String, page: PageSetup) async throws -> RenderedPDF {
        try await turns.turn(.check)
        defer { turns.ended(.check) }
        return try await renderer.render(html: html, page: page)
    }
}
