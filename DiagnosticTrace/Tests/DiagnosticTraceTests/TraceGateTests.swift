import DiagnosticLogging
import DiagnosticLoggingTestSupport
import DiagnosticTrace
import DiagnosticTraceTestSupport
import Foundation
import Testing

@Suite("The gate opens the trace for a verified TestFlight build only, and fails closed")
struct TraceGateTests {
    // MARK: Truth table

    @Test("Only a verified sandbox answer allows the trace", arguments: DistributionAnswer.allCases)
    func onlySandboxAllows(answer: DistributionAnswer) {
        #expect(answer.allowsTrace == (answer == .sandbox))
    }

    @Test("The gate is closed until the distribution answers")
    func closedUntilAnswered() {
        #expect(!DistributionGate().isOpen)
        #expect(DistributionGate().answer == nil)
    }

    @Test("Asked, the gate takes the answer, and opens for sandbox only", arguments: DistributionAnswer.allCases)
    func asksTheDistribution(answer: DistributionAnswer) async {
        let gate = DistributionGate()

        await gate.ask(FixedDistribution(answer))

        #expect(gate.answer == answer)
        #expect(gate.isOpen == (answer == .sandbox))
    }

    @Test("A distribution that throws, such as an offline first launch, leaves the gate closed")
    func thrownAnswerIsClosed() async {
        let gate = DistributionGate()

        await gate.ask(FixedDistribution(throwing: FixedDistribution.Failure()))

        #expect(gate.answer == .failed)
        #expect(!gate.isOpen)
    }

    @Test("A constant gate stays as it was made")
    func constantGate() {
        #expect(ConstantGate(isOpen: true).isOpen)
        #expect(!ConstantGate(isOpen: false).isOpen)
    }

    // MARK: Nothing written when closed

    @Test("With the gate closed, a whole run, its steps and its events reach the store zero times")
    func closedGateWritesNothing() {
        let store = RecordingTraceStore()
        let tracer = GatedTracer(gate: DistributionGate(), next: TraceRecorder.sample(store: store, clock: TickingClock(step: .milliseconds(1))))

        let run = tracer.begin(.aiDraft)
        run.record(.input, .text("description", "marker-word"))
        tracer.record(.response, [.text("raw", "marker-word")], into: .aiDraft)
        tracer.mirror(TraceEvent(kind: nil, category: "draft", level: "info", line: "draft.started"))
        run.finish(.finished)

        #expect(store.runWrites == 0)
        #expect(store.sessionEvents.isEmpty)
    }

    @Test("With the gate open, the run, its steps and its events reach the recorder")
    func openGateRecords() throws {
        let store = RecordingTraceStore()
        let tracer = GatedTracer(gate: ConstantGate(isOpen: true), next: TraceRecorder.sample(store: store, clock: TickingClock(step: .milliseconds(1))))

        let run = tracer.begin(.aiDraft)
        run.record(.input, .text("description", "marker-word"))
        run.withinSync { tracer.record(.response, [.text("raw", "answer")], into: .aiDraft) }
        tracer.mirror(TraceEvent(kind: nil, category: "export", level: "info", line: "export.finished"))
        run.finish(.finished)

        let saved = try #require(store.latest(.aiDraft))
        #expect(saved.steps.map(\.name) == [.input, .response])
        #expect(store.sessionEvents.map(\.line) == ["export.finished"])
    }

    @Test("A run begun while the gate was closed stays unrecorded after it opens")
    func runBegunClosedStaysUnrecorded() async {
        let store = RecordingTraceStore()
        let gate = DistributionGate()
        let tracer = GatedTracer(gate: gate, next: TraceRecorder.sample(store: store, clock: TickingClock(step: .milliseconds(1))))

        let run = tracer.begin(.textImport)
        await gate.ask(FixedDistribution(.sandbox))
        run.record(.input, .text("text", "marker-word"))
        run.finish(.finished)

        #expect(store.runWrites == 0)
    }

    @Test("The no-op tracer records nothing")
    func noTracer() {
        let tracer = NoTracer()
        let run = tracer.begin(.aiDraft)
        run.record(.input, .text("description", "marker-word"))
        run.finish(.finished)
        tracer.record(.input, [], into: .aiDraft)
        tracer.mirror(TraceEvent(kind: nil, category: "draft", level: "info", line: "draft.started"))
    }
}

@Suite("The tracing logger mirrors every log entry into the trace, and passes it on")
struct TracingLoggerTests {
    @Test("An entry of a mapped category becomes an event step of the open run, and still reaches the next logger")
    func mirrorsIntoTheOpenRun() throws {
        let store = RecordingTraceStore()
        let recorder = TraceRecorder.sample(store: store, clock: TickingClock(step: .milliseconds(1)))
        let sink = RecordingLogger()
        let logger = TracingLogger(tracer: recorder, next: sink, kinds: ["draft": .aiDraft, "import": .textImport])

        let run = recorder.begin(.aiDraft)
        run.withinSync { logger.info(.draft, "draft.started", .count("characters", 21)) }
        run.finish(.finished)

        #expect(sink.events == ["draft.started"])
        let saved = try #require(store.latest(.aiDraft))
        #expect(saved.steps.map(\.fields) == [[.token("category", "draft"), .token("level", "info"), .text("line", "draft.started characters=21")]])
    }

    @Test("An entry outside every run's scope, or of a category with no kind, goes to the session events")
    func otherEntriesGoToTheSession() {
        let store = RecordingTraceStore()
        let recorder = TraceRecorder.sample(store: store, clock: TickingClock(step: .milliseconds(1)))
        let logger = TracingLogger(tracer: recorder, next: SilentLogger(), kinds: ["draft": .aiDraft])

        logger.notice(.draft, "draft.availability")
        logger.error(.export, "export.failed")

        #expect(store.sessionEvents.map(\.line) == ["draft.availability", "export.failed"])
        #expect(store.sessionEvents.map(\.level) == ["notice", "error"])
        #expect(store.sessionEvents.map(\.category) == ["draft", "export"])
    }
}

private extension LogCategory {
    static let draft = LogCategory("draft")
    static let export = LogCategory("export")
}
