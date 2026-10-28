import DiagnosticLoggingTestSupport
import DiagnosticTrace
import DiagnosticTraceTestSupport
import Foundation
import Testing

@Suite("The recorder keeps each run's steps in order, and hands every change to the store")
struct TraceRecorderTests {
    // MARK: Steps

    @Test("Steps keep their order, their sequence numbers and the time since the run began, on the injected clock")
    func stepsInOrder() throws {
        let store = RecordingTraceStore()
        let recorder = TraceRecorder.sample(store: store, clock: TickingClock(step: .milliseconds(10)))

        let run = recorder.begin(.aiDraft)
        run.record(.input, .text("description", "Ten years of nursing."), .count("length", 21))
        run.record(.timing, .duration("model", .milliseconds(250)))
        run.finish(.finished)

        let saved = try #require(store.latest(.aiDraft))
        #expect(saved.steps.map(\.sequence) == [1, 2])
        #expect(saved.steps.map(\.name) == [.input, .timing])
        #expect(saved.steps.map(\.elapsed) == [.milliseconds(10), .milliseconds(20)])
        #expect(saved.steps[0].fields == [.text("description", "Ten years of nursing."), .count("length", 21)])
        #expect(saved.outcome == .finished)
        #expect(store.runWrites == 3)
    }

    @Test("A run carries its id, its kind, its start time and the build that made it")
    func runHeader() throws {
        let store = RecordingTraceStore()
        let recorder = TraceRecorder.sample(store: store, clock: TickingClock(step: .milliseconds(1)))

        recorder.begin(.textImport).finish(.cancelled)

        let saved = try #require(store.latest(.textImport))
        #expect(saved.id == TraceRecorder.sampleID)
        #expect(saved.kind == .textImport)
        #expect(saved.started == TraceRecorder.sampleStart)
        #expect(saved.build == TraceBuild.sample)
        #expect(saved.outcome == .cancelled)
    }

    @Test("A step after the run finished, and a second finish, change nothing")
    func finishedRunIsClosed() throws {
        let store = RecordingTraceStore()
        let recorder = TraceRecorder.sample(store: store, clock: TickingClock(step: .milliseconds(1)))

        let run = recorder.begin(.aiDraft)
        run.finish(.failed(code: "model"))
        run.record(.input, .text("description", "late"))
        run.finish(.finished)
        recorder.record(.response, [.text("raw", "late")], into: .aiDraft)

        let saved = try #require(store.latest(.aiDraft))
        #expect(saved.steps.isEmpty)
        #expect(saved.outcome == .failed(code: "model"))
        #expect(store.runWrites == 1)
    }

    @Test("A step recorded into a kind goes to the open run of that kind, and is dropped when none is open")
    func recordIntoOpenRun() throws {
        let store = RecordingTraceStore()
        let recorder = TraceRecorder.sample(store: store, clock: TickingClock(step: .milliseconds(1)))

        recorder.record(.request, [.text("prompt", "before")], into: .aiDraft)
        let run = recorder.begin(.aiDraft)
        recorder.record(.request, [.text("prompt", "during")], into: .aiDraft)
        recorder.record(.input, [.text("text", "other kind")], into: .textImport)
        run.finish(.finished)

        let saved = try #require(store.latest(.aiDraft))
        #expect(saved.steps.map(\.fields) == [[.text("prompt", "during")]])
        #expect(store.latest(.textImport) == nil)
    }

    // MARK: Limits

    @Test("A text longer than 32 KB is cut on a character boundary, and keeps its original length")
    func longTextIsCut() {
        let long = String(repeating: "é", count: 20_000)

        let text = TraceText(long)

        #expect(text.truncated)
        #expect(text.originalLength == 40_000)
        #expect(text.text.utf8.count <= TraceText.limit)
        #expect(text.text.utf8.count > TraceText.limit - 2)
        #expect(text.text.allSatisfy { $0 == "é" })
        #expect(TraceText("short") == TraceText(text: "short", truncated: false, originalLength: 5))
    }

    @Test("Past 1 MB, the rest of a run becomes one truncated step that counts the steps left out")
    func runIsCapped() throws {
        let store = RecordingTraceStore()
        let recorder = TraceRecorder.sample(store: store, clock: TickingClock(step: .milliseconds(1)))
        let block = String(repeating: "a", count: 30_000)

        let run = recorder.begin(.aiDraft)
        for _ in 0..<40 { run.record(.response, .text("raw", block)) }
        run.finish(.finished)

        let saved = try #require(store.latest(.aiDraft))
        let kept = saved.steps.filter { $0.name == .response }.count
        #expect(kept == 34)
        #expect(saved.steps.last?.name == .truncated)
        #expect(saved.steps.last?.fields == [.count("stepsLeftOut", 6)])
        #expect(saved.outcome == .finished)
    }

    // MARK: Events

    @Test("An event goes into the open run of its kind, and to the session events when no run of that kind is open")
    func eventsFollowTheOpenRun() throws {
        let store = RecordingTraceStore()
        let recorder = TraceRecorder.sample(store: store, clock: TickingClock(step: .milliseconds(1)))

        let run = recorder.begin(.aiDraft)
        recorder.mirror(TraceEvent(kind: .aiDraft, category: "draft", level: "info", line: "draft.started"))
        recorder.mirror(TraceEvent(kind: .textImport, category: "import", level: "info", line: "import.finished"))
        recorder.mirror(TraceEvent(kind: nil, category: "export", level: "error", line: "export.failed"))
        run.finish(.finished)

        let saved = try #require(store.latest(.aiDraft))
        #expect(saved.steps.map(\.name) == [.event])
        #expect(saved.steps[0].fields == [.token("category", "draft"), .token("level", "info"), .text("line", "draft.started")])
        #expect(store.sessionEvents.map(\.line) == ["import.finished", "export.failed"])
        #expect(store.sessionEvents.map(\.time) == [TraceRecorder.sampleStart, TraceRecorder.sampleStart])
    }
}

// MARK: - Samples

extension TraceBuild {
    static let sample = TraceBuild(appVersion: "1.0", build: "121", distribution: "sandbox", osVersion: "iOS 26.5", deviceModel: "iPhone17,1")
}

extension TraceRecorder {
    static let sampleID = UUID(uuid: (0x1A, 0x2B, 0x3C, 0x4D, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    static let sampleStart = Date(timeIntervalSince1970: 1_793_188_800.125)

    static func sample(store: any TraceStoring, clock: TickingClock) -> TraceRecorder {
        TraceRecorder(store: store, build: { .sample }, clock: clock, now: { sampleStart }, newID: { sampleID })
    }
}
