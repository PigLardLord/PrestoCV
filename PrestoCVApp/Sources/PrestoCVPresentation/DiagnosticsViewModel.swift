import Foundation
import Observation
import PrestoCVWorkflowPorts

/// The Diagnostics screen of a test build (#405, ADR 0032): the stored runs, the summary of the chosen one and the copies
/// of its files to share, as codes the view words (R13).
@MainActor
@Observable
public final class DiagnosticsViewModel {

    public private(set) var state: DiagnosticsState = .loading
    public private(set) var rows: [DiagnosticsRow] = []
    public private(set) var selection: UUID?
    public private(set) var summary = ""
    public private(set) var shareFiles: [URL] = []
    /// The copies of the chosen run could not be made, so there is nothing to share and the view says why.
    public private(set) var copiesFailed = false

    private var runs: [DiagnosticRun] = []
    @ObservationIgnored private let reading: any DiagnosticsReading
    @ObservationIgnored private var latestSelection = 0
    @ObservationIgnored private var isClosed = false
    /// Counts the screen's openings, so that the runs read for an opening that closed are never listed
    @ObservationIgnored private var opening = 0
    /// The last copy or discard begun: each one runs after the one before it ends
    @ObservationIgnored private var turn: Task<Void, Never>?

    public init(reading: any DiagnosticsReading) {
        self.reading = reading
    }

    /// Reads the stored runs, lists them newest first and chooses the newest. Runs read after the screen closed are not
    /// listed, and no copy is made of them.
    public func load() async {
        opening += 1
        let thisOpening = opening
        isClosed = false
        let stored = await reading.runs()
        guard thisOpening == opening, !isClosed else { return }
        runs = stored.sorted { $0.started > $1.started }
        rows = runs.map { DiagnosticsRow(run: $0) }
        guard let newest = runs.first else {
            latestSelection += 1
            state = .empty
            selection = nil
            summary = ""
            shareFiles = []
            copiesFailed = false
            return
        }
        state = .listed
        await select(newest.id)
    }

    /// Chooses a run: shows its summary at once and makes the copies of its files to share. Only the latest choice sets the
    /// files: a copy that ends after a newer choice started, or after the screen closed, is not offered. The copies are
    /// made one choice at a time, because the store keeps one folder of copies and each copy empties it first; a choice
    /// that a newer one replaced before its turn came makes no copy. An id the screen does not list, or a choice on a
    /// closed screen, changes nothing.
    public func select(_ id: UUID) async {
        guard !isClosed, let run = runs.first(where: { $0.id == id }) else { return }
        latestSelection += 1
        let thisSelection = latestSelection
        selection = id
        summary = run.summary
        shareFiles = []
        copiesFailed = false
        await inTurn { [self] in await makeCopies(of: id, for: thisSelection) }
    }

    /// Discards the copies made to share, once the screen is closed: after every copy begun before, so that none is left.
    public func finish() async {
        isClosed = true
        latestSelection += 1
        shareFiles = []
        copiesFailed = false
        await inTurn { [reading] in await reading.discardCopies() }
    }

    private func makeCopies(of id: UUID, for thisSelection: Int) async {
        // A newer choice or the closed screen took this one's place before its turn came
        guard thisSelection == latestSelection else { return }
        let copies: [URL]
        do {
            copies = try await reading.shareCopies(of: id)
        } catch is CancellationError {
            return
        } catch {
            // The store logs why; with no copy there is nothing to share. Only the latest choice of an open screen says so
            if thisSelection == latestSelection { copiesFailed = true }
            return
        }
        // A copy that ends after the screen closed is removed by the discard that waits for it
        guard thisSelection == latestSelection else { return }
        shareFiles = copies
    }

    /// Runs the work once every copy and discard begun before it has ended.
    private func inTurn(_ work: @escaping @MainActor @Sendable () async -> Void) async {
        let earlier = turn
        let next = Task {
            await earlier?.value
            await work()
        }
        turn = next
        await next.value
    }
}

public enum DiagnosticsState: Hashable, Sendable { case loading, empty, listed }

public struct DiagnosticsRow: Hashable, Sendable, Identifiable {
    public enum Kind: Hashable, Sendable { case aiDraft, textImport }
    public enum Outcome: Hashable, Sendable { case finished, failed, cancelled, unfinished }

    public let id: UUID
    public let kind: Kind
    public let started: Date
    public let outcome: Outcome

    init(run: DiagnosticRun) {
        id = run.id
        started = run.started
        kind = switch run.kind {
        case .aiDraft: .aiDraft
        case .textImport: .textImport
        }
        outcome = switch run.outcome {
        case .finished: .finished
        case .failed: .failed
        case .cancelled: .cancelled
        case .unfinished: .unfinished
        }
    }
}
