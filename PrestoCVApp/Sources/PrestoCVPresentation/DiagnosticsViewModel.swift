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

    private var runs: [DiagnosticRun] = []
    @ObservationIgnored private let reading: any DiagnosticsReading
    @ObservationIgnored private var latestSelection = 0
    @ObservationIgnored private var isClosed = false

    public init(reading: any DiagnosticsReading) {
        self.reading = reading
    }

    /// Reads the stored runs, lists them newest first and chooses the newest.
    public func load() async {
        isClosed = false
        runs = await reading.runs().sorted { $0.started > $1.started }
        rows = runs.map { DiagnosticsRow(run: $0) }
        guard let newest = runs.first else {
            latestSelection += 1
            state = .empty
            selection = nil
            summary = ""
            shareFiles = []
            return
        }
        state = .listed
        await select(newest.id)
    }

    /// Chooses a run: shows its summary at once and makes the copies of its files to share. Only the latest choice sets the
    /// files: a copy that ends after a newer choice started, or after the screen closed, is not offered. An id the screen
    /// does not list changes nothing.
    public func select(_ id: UUID) async {
        guard let run = runs.first(where: { $0.id == id }) else { return }
        latestSelection += 1
        let thisSelection = latestSelection
        selection = id
        summary = run.summary
        shareFiles = []
        let copies: [URL]
        do {
            copies = try await reading.shareCopies(of: id)
        } catch is CancellationError {
            return
        } catch {
            // The store logs why; with no copy there is nothing to share
            return
        }
        if isClosed {
            await reading.discardCopies()
            return
        }
        guard thisSelection == latestSelection else { return }
        shareFiles = copies
    }

    /// Discards the copies made to share, once the screen is closed.
    public func finish() async {
        isClosed = true
        latestSelection += 1
        shareFiles = []
        await reading.discardCopies()
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
