import DiagnosticLogging

/// Records nothing: for previews, and wherever no trace is wanted.
public struct NoTracer: DiagnosticTracer {
    public init() {}

    public func begin(_ kind: TraceKind) -> any TraceRunRecording { NoRun() }
    public func record(_ name: TraceStepName, _ fields: [TraceField], into kind: TraceKind) {}
    public func mirror(_ event: TraceEvent) {}
}

/// A run that keeps nothing.
struct NoRun: TraceRunRecording {
    var isRecording: Bool { false }
    func record(_ name: TraceStepName, _ fields: [TraceField]) {}
    func finish(_ outcome: TraceOutcome) {}
}

/// Passes runs, steps and events on only while its gate is open. A run begun while the gate was closed stays unrecorded
/// to its end, so nothing of it is held in memory either.
public struct GatedTracer: DiagnosticTracer {
    private let gate: any TraceGate
    private let next: any DiagnosticTracer

    public init(gate: any TraceGate, next: any DiagnosticTracer) {
        self.gate = gate
        self.next = next
    }

    public func begin(_ kind: TraceKind) -> any TraceRunRecording {
        gate.isOpen ? next.begin(kind) : NoRun()
    }

    public func record(_ name: TraceStepName, _ fields: [TraceField], into kind: TraceKind) {
        guard gate.isOpen else { return }
        next.record(name, fields, into: kind)
    }

    public func mirror(_ event: TraceEvent) {
        guard gate.isOpen else { return }
        next.mirror(event)
    }
}

/// A logger that hands every entry to the tracer as well, so that one run holds the whole story, then passes it on. The
/// entry's line carries no CV content (ADR 0030); the composition root says which category belongs to which kind of run.
public struct TracingLogger: DiagnosticLogger {
    private let tracer: any DiagnosticTracer
    private let next: any DiagnosticLogger
    private let kinds: [String: TraceKind]

    public init(tracer: any DiagnosticTracer, next: any DiagnosticLogger, kinds: [String: TraceKind]) {
        self.tracer = tracer
        self.next = next
        self.kinds = kinds
    }

    public func log(_ entry: LogEntry) {
        next.log(entry)
        tracer.mirror(TraceEvent(
            kind: kinds[entry.category.name],
            category: entry.category.name,
            level: String(describing: entry.level),
            line: entry.line
        ))
    }
}
