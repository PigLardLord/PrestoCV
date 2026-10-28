import DiagnosticLoggingTestSupport
import DiagnosticTrace
import DiagnosticTraceTestSupport
import Foundation
import Testing

@Suite("A step recorded by kind goes to the run whose work records it, also when another run of that kind began since")
struct TraceScopeTests {
    private func twoRuns() -> (tracer: RecordingTracer, older: any TraceRunRecording, newer: any TraceRunRecording) {
        let tracer = RecordingTracer()
        let older = tracer.begin(.aiDraft)
        let newer = tracer.begin(.aiDraft)
        return (tracer, older, newer)
    }

    /// Every text the run holds, in order; empty for a run that holds no step
    private func texts(_ tracer: RecordingTracer, _ run: any TraceRunRecording) -> [String] {
        let saved = tracer.runs.first { $0.id == run.scope.id }
        return (saved?.steps ?? []).flatMap(\.fields).compactMap { field in
            if case .text(let text) = field.value { text.text } else { nil }
        }
    }

    @Test("The older run's steps stay in the older run when the newer one finishes first")
    func newerFinishesFirst() async {
        let (tracer, older, newer) = twoRuns()

        await older.within { tracer.record(.request, into: .aiDraft) { [.text("prompt", "older first")] } }
        await newer.within { tracer.record(.request, into: .aiDraft) { [.text("prompt", "newer")] } }
        newer.finish(.finished)
        await older.within {
            tracer.record(.response, into: .aiDraft) { [.text("raw", "older answer")] }
            tracer.mirror(TraceEvent(kind: .aiDraft, category: "draft", level: "info", line: "older event"))
        }
        older.finish(.finished)

        #expect(texts(tracer, older) == ["older first", "older answer", "older event"])
        #expect(texts(tracer, newer) == ["newer"])
        #expect(tracer.store.sessionEvents.isEmpty)
    }

    @Test("The newer run's steps stay in the newer run when the older one finishes first, and the older run's late steps are dropped")
    func olderFinishesFirst() async {
        let (tracer, older, newer) = twoRuns()

        older.finish(.cancelled)
        await older.within { tracer.record(.response, into: .aiDraft) { [.text("raw", "late answer of the older")] } }
        await newer.within {
            tracer.record(.request, into: .aiDraft) { [.text("prompt", "newer")] }
            tracer.mirror(TraceEvent(kind: .aiDraft, category: "draft", level: "info", line: "newer event"))
        }

        #expect(texts(tracer, older).isEmpty)
        #expect(texts(tracer, newer) == ["newer", "newer event"])
    }

    @Test("Work started inside a run's scope keeps the scope, and a step of another kind is dropped")
    func scopeFollowsTheWork() async {
        let (tracer, older, newer) = twoRuns()

        await older.within {
            await Task { tracer.record(.request, into: .aiDraft) { [.text("prompt", "from a child task")] } }.value
            tracer.record(.check, into: .textImport) { [.text("note", "an import step")] }
        }

        #expect(texts(tracer, older) == ["from a child task"])
        #expect(texts(tracer, newer).isEmpty)
        #expect(tracer.run(.textImport) == nil)
    }

    @Test("Outside every scope a step by kind is dropped, and never lands in the newest run")
    func unscopedStepIsDropped() {
        let (tracer, older, newer) = twoRuns()

        tracer.record(.request, into: .aiDraft) { [.text("prompt", "unscoped")] }

        #expect(texts(tracer, older).isEmpty)
        #expect(texts(tracer, newer).isEmpty)
    }

    @Test("Outside every scope a log entry goes to the session events, and never into a run")
    func unscopedEventGoesToTheSession() {
        let (tracer, older, newer) = twoRuns()

        tracer.mirror(TraceEvent(kind: .aiDraft, category: "draft", level: "info", line: "no scope"))

        #expect(texts(tracer, older).isEmpty)
        #expect(texts(tracer, newer).isEmpty)
        #expect(tracer.store.sessionEvents.map(\.line) == ["no scope"])
    }

    @Test("A task that leaves the scope, as a detached one does, records into no run")
    func detachedTaskLeavesTheScope() async {
        let (tracer, older, newer) = twoRuns()

        await older.within {
            await Task.detached {
                tracer.record(.request, into: .aiDraft) { [.text("prompt", "detached")] }
                tracer.mirror(TraceEvent(kind: .aiDraft, category: "draft", level: "info", line: "detached event"))
            }.value
        }

        #expect(texts(tracer, older).isEmpty)
        #expect(texts(tracer, newer).isEmpty)
        #expect(tracer.store.sessionEvents.map(\.line) == ["detached event"])
    }

    @Test("Synchronous work inside a run's scope records into that run")
    func synchronousWorkKeepsTheScope() {
        let (tracer, older, newer) = twoRuns()

        older.withinSync {
            tracer.record(.request, into: .aiDraft) { [.text("prompt", "sync")] }
            tracer.mirror(TraceEvent(kind: .aiDraft, category: "draft", level: "info", line: "sync event"))
        }

        #expect(texts(tracer, older) == ["sync", "sync event"])
        #expect(texts(tracer, newer).isEmpty)
    }

    // MARK: Runs begun behind the closed gate

    @Test("A run begun behind the closed gate has the suppressed scope, and a recording run its own")
    func scopes() {
        let closed = GatedTracer(gate: DistributionGate(), next: RecordingTracer())
        let open = RecordingTracer().begin(.aiDraft)

        #expect(closed.begin(.aiDraft).scope == .suppressed)
        #expect(NoTracer().begin(.aiDraft).scope == .suppressed)
        guard case .recording(_, let kind) = open.scope else { Issue.record("not recording"); return }
        #expect(kind == .aiDraft)
    }

    @Test("What a draft begun behind the closed gate records after the gate opens appears in no run, nor in the events")
    func suppressedWorkStaysUnrecorded() async {
        let store = RecordingTraceStore()
        let gate = DistributionGate()
        let tracer = GatedTracer(gate: gate, next: TraceRecorder.sample(store: store, clock: TickingClock(step: .milliseconds(1))))

        let first = tracer.begin(.aiDraft)
        await gate.ask(FixedDistribution(.sandbox))
        let retry = tracer.begin(.aiDraft)
        await retry.within { tracer.record(.request, into: .aiDraft) { [.text("prompt", "retry request")] } }
        await first.within {
            tracer.record(.response, into: .aiDraft) { [.text("raw", "response of the first")] }
            tracer.mirror(TraceEvent(kind: .aiDraft, category: "draft", level: "info", line: "event of the first"))
        }
        retry.finish(.finished)
        first.finish(.finished)

        let all = store.runs.map(\.allText).joined()
        #expect(store.runs.count == 1)
        #expect(store.latest(.aiDraft)?.steps.map(\.name) == [.request])
        #expect(!all.contains("response of the first"))
        #expect(!all.contains("event of the first"))
        #expect(store.sessionEvents.isEmpty)
    }
}
