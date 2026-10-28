/// Where the AI draft and the import write each step of a run, with the text it read and wrote (ADR 0032).
///
/// A type that traces takes one in its initialiser, with no default; only the composition root makes the recorder, the
/// gate and the store, and chooses them by build. Every call is synchronous, never throws and never waits on I/O, as
/// `DiagnosticLogger`'s does: the store writes on its own task.
public protocol DiagnosticTracer: Sendable {
    /// Opens a run of a kind, and returns where its steps go.
    func begin(_ kind: TraceKind) -> any TraceRunRecording
    /// Adds a step to the open run of a kind: for a part that does not hold the run, such as the model service.
    /// Without an open run of that kind, the step is dropped.
    func record(_ name: TraceStepName, _ fields: [TraceField], into kind: TraceKind)
    /// Adds a log entry to the open run of its kind, or to the session's events when there is none.
    func mirror(_ event: TraceEvent)
}

/// One open run.
public protocol TraceRunRecording: Sendable {
    func record(_ name: TraceStepName, _ fields: [TraceField])
    /// Closes the run. Steps and outcomes after the first finish change nothing.
    func finish(_ outcome: TraceOutcome)
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
