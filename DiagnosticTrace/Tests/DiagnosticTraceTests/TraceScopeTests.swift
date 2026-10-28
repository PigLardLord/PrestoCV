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
        let saved = tracer.runs.first { $0.id == run.scope?.id }
        return (saved?.steps ?? []).flatMap(\.fields).compactMap { field in
            if case .text(let text) = field.value { text.text } else { nil }
        }
    }

    @Test("The older run's steps stay in the older run when the newer one finishes first")
    func newerFinishesFirst() async {
        let (tracer, older, newer) = twoRuns()

        await older.within { tracer.record(.request, [.text("prompt", "older first")], into: .aiDraft) }
        await newer.within { tracer.record(.request, [.text("prompt", "newer")], into: .aiDraft) }
        newer.finish(.finished)
        await older.within {
            tracer.record(.response, [.text("raw", "older answer")], into: .aiDraft)
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
        await older.within { tracer.record(.response, [.text("raw", "late answer of the older")], into: .aiDraft) }
        await newer.within {
            tracer.record(.request, [.text("prompt", "newer")], into: .aiDraft)
            tracer.mirror(TraceEvent(kind: .aiDraft, category: "draft", level: "info", line: "newer event"))
        }

        #expect(texts(tracer, older).isEmpty)
        #expect(texts(tracer, newer) == ["newer", "newer event"])
    }

    @Test("Work started inside a run's scope keeps the scope, and a step of another kind goes by kind")
    func scopeFollowsTheWork() async {
        let (tracer, older, newer) = twoRuns()

        await older.within {
            await Task { tracer.record(.request, [.text("prompt", "from a child task")], into: .aiDraft) }.value
            tracer.record(.check, [.text("note", "an import step")], into: .textImport)
        }

        #expect(texts(tracer, older) == ["from a child task"])
        #expect(texts(tracer, newer).isEmpty)
    }

    @Test("Outside every scope a step still goes to the newest open run of its kind")
    func unscopedUsesTheNewest() {
        let (tracer, older, newer) = twoRuns()

        tracer.record(.request, [.text("prompt", "unscoped")], into: .aiDraft)

        #expect(texts(tracer, older).isEmpty)
        #expect(texts(tracer, newer) == ["unscoped"])
    }
}
