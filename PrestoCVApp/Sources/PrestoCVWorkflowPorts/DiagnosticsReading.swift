import Foundation

/// What the Diagnostics screen of a test build reads (#405, ADR 0032): whether the screen is offered, the stored runs of
/// the AI draft and of the import, and the copies of a run's files to share. The screen owns this port (R3); its adapter
/// is the composition's, over the trace, so that no trace type reaches a view model (R5).
public protocol DiagnosticsReading: Sendable {
    /// Whether the screen is offered: the trace records on this launch. It answers once the build has its answer, and
    /// `false` for every build that may not record.
    func isAvailable() async -> Bool
    /// The stored runs, newest first.
    func runs() async -> [DiagnosticRun]
    /// Copies of a run's files to share, in a temporary folder that `discardCopies` removes. Each reader keeps one set of
    /// copies of its own, which each copy replaces: one reader's copies and discard never touch another's. A copy that
    /// cannot be made throws; a cancelled task stays a `CancellationError` (R3, R7).
    func shareCopies(of id: UUID) async throws -> [URL]
    /// Removes this reader's copies made to share.
    func discardCopies() async
}

/// One stored run: what it traced, when it started, how it ended and its plain-text summary as it is shared.
public struct DiagnosticRun: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let kind: DiagnosticRunKind
    public let started: Date
    public let outcome: DiagnosticRunOutcome
    public let summary: String

    public init(id: UUID, kind: DiagnosticRunKind, started: Date, outcome: DiagnosticRunOutcome, summary: String) {
        self.id = id
        self.kind = kind
        self.started = started
        self.outcome = outcome
        self.summary = summary
    }
}

public enum DiagnosticRunKind: Hashable, Sendable {
    case aiDraft, textImport
}

/// How a run ended; `unfinished` is a run that never ended.
public enum DiagnosticRunOutcome: Hashable, Sendable {
    case finished, failed, cancelled, unfinished
}
