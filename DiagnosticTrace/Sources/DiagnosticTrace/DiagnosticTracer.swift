import Foundation

/// Where the AI draft and the import write each step of a run, with the text it read and wrote (ADR 0032).
///
/// A type that traces takes one in its initialiser, with no default; only the composition root makes the recorder, the
/// gate and the store, and chooses them by build. Every call is synchronous, never throws and never waits on I/O, as
/// `DiagnosticLogger`'s does: the store writes on its own task.
public protocol DiagnosticTracer: Sendable {
    /// Opens a run of a kind, and returns where its steps go.
    func begin(_ kind: TraceKind) -> any TraceRunRecording
    /// Adds a step to the run whose scope the work is in (`TraceScope`), when it is of that kind: for a part that does not hold
    /// the run, such as the model service. Outside a recording scope, the step is dropped.
    func record(_ name: TraceStepName, _ fields: [TraceField], into kind: TraceKind)
    /// Adds a log entry to the run whose scope the work is in, when it is of the entry's kind and still open; to the session's
    /// events otherwise, also outside every scope; nowhere inside a suppressed one.
    func mirror(_ event: TraceEvent)
}

/// One open run.
public protocol TraceRunRecording: Sendable {
    func record(_ name: TraceStepName, _ fields: [TraceField])
    /// Closes the run. Steps and outcomes after the first finish change nothing.
    func finish(_ outcome: TraceOutcome)
    /// What names this run to the steps recorded by kind while its work runs (`within`): the run itself, or `suppressed`
    /// for a run that records nothing.
    var scope: TraceScope { get }
}

/// The run that the work of the current task belongs to. The model service and the logger do not hold the run: they record
/// by kind, and the recorder reads the scope to find the run of the work that is asking, so that two drafts of one kind in
/// flight, such as a cancelled one and its retry, each get their own steps. The scope is total: work is in a run, in a run
/// that records nothing, or in none, and only the first reaches a run. There is no fallback to the newest run of a kind.
public enum TraceScope: Sendable, Equatable {
    /// The work belongs to this run; its steps and log entries go to it.
    case recording(id: UUID, kind: TraceKind)
    /// The work belongs to a run that records nothing, such as one begun while the gate was closed. What it records by
    /// kind is discarded, also after the gate opens.
    case suppressed
    /// The work belongs to no run. A step recorded by kind is dropped; a log entry goes to the session's events.
    case none

    /// The id of the run the work belongs to, when it is in one.
    public var id: UUID? {
        if case .recording(let id, _) = self { id } else { nil }
    }

    @TaskLocal public static var current: TraceScope = .none
}

extension TraceRunRecording {
    /// Whether the run keeps what it is given. A caller that builds a large payload asks first, and skips the work when not.
    public var isRecording: Bool {
        if case .recording = scope { true } else { false }
    }

    /// Runs work whose steps and log entries belong to this run, wherever they are recorded by kind: the scope reaches the
    /// tasks the work starts as well, but not a detached one.
    public func within<T>(
        isolation: isolated (any Actor)? = #isolation, _ work: () async throws -> T
    ) async rethrows -> T {
        try await TraceScope.$current.withValue(scope, operation: work, isolation: isolation)
    }

    /// `within` for work that does not suspend, such as the text import.
    public func withinSync<T>(_ work: () throws -> T) rethrows -> T {
        try TraceScope.$current.withValue(scope, operation: work)
    }
}

extension TraceRunRecording {
    public func record(_ name: TraceStepName, _ fields: TraceField...) {
        record(name, fields)
    }
}

/// Where the recorder hands each new state of a run, and each session event. A store copies and writes them on its own
/// task: both calls return at once and never throw.
public protocol TraceStoring: Sendable {
    func save(_ run: TraceRun)
    func save(sessionEvent: TraceSessionEvent)
}
