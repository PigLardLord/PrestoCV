import Foundation

/// A stored run, as the diagnostics screen lists it.
public struct TraceRunListing: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let kind: TraceKind
    public let started: Date
    public let outcome: TraceOutcome?
    /// The stored plain-text summary, as it will be shared.
    public let summary: String

    public init(id: UUID, kind: TraceKind, started: Date, outcome: TraceOutcome?, summary: String) {
        self.id = id
        self.kind = kind
        self.started = started
        self.outcome = outcome
        self.summary = summary
    }
}

/// Reads the stored runs back, for the person to look at and share (ADR 0032). The copies to share are the stored bytes,
/// in a temporary folder that `discardCopies` removes; nothing leaves the device but by the person's own act.
public protocol TraceReading: Sendable {
    /// The stored runs, newest first.
    func runs() async -> [TraceRunListing]
    /// Copies of a run's files to share: its document, then its summary, then the session's events when there are any.
    func shareCopies(of id: UUID) async throws -> [URL]
    /// Removes the copies made to share.
    func discardCopies() async
}
