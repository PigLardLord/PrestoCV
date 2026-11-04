import DiagnosticTrace
import Foundation
import Testing

@Suite("The stored form of a run, its summary, its file name and the retention rule")
struct TraceDocumentTests {
    // MARK: Document

    @Test("A run reads back from its document, with its header, steps and outcome")
    func roundTrip() throws {
        let run = TraceRun.sample(outcome: .failed(code: "grounding"))

        let read = try TraceRun(document: run.document())

        #expect(read.id == run.id)
        #expect(read.kind == run.kind)
        #expect(read.started == run.started)
        #expect(read.build == run.build)
        #expect(read.outcome == .failed(code: "grounding"))
        #expect(read.steps.map(\.name) == run.steps.map(\.name))
        #expect(read.steps.map(\.fields) == run.steps.map(\.fields))
        #expect(read.steps.map(\.elapsed) == run.steps.map(\.elapsed))
    }

    @Test("The document has schema 1 and sorted keys, so two runs diff line by line")
    func documentIsStable() throws {
        let text = try #require(String(data: TraceRun.sample(outcome: .finished).document(), encoding: .utf8))

        #expect(text.contains(#""schema" : 1"#))
        #expect(text.contains(#""started" : "2026-10-28T12:00:00.125Z""#))
        #expect(text.contains(#""outcome" : {"#))
        let keys = text.split(separator: "\n").compactMap { line -> String? in
            let trimmed = line.drop { $0 == " " }
            return trimmed.hasPrefix("\"") ? String(trimmed.prefix { $0 != ":" }) : nil
        }
        #expect(keys.prefix(7) == [#""build" "#, #""appVersion" "#, #""build" "#, #""deviceModel" "#, #""distribution" "#, #""osVersion" "#, #""id" "#])
        #expect(try TraceRun.sample(outcome: .finished).document() == TraceRun.sample(outcome: .finished).document())
    }

    @Test("A document that is not a run does not read")
    func corruptDocument() {
        #expect(throws: (any Error).self) { try TraceRun(document: Data("{\"schema\": 1}".utf8)) }
        #expect(throws: (any Error).self) { try TraceRun(document: Data("not json".utf8)) }
    }

    @Test("An open run has no outcome in its document")
    func openRun() throws {
        let read = try TraceRun(document: TraceRun.sample(outcome: nil).document())
        #expect(read.outcome == nil)
    }

    @Test("A run keeps its file name stem through its document, for a start at any millisecond")
    func stemSurvivesTheDocument() throws {
        let starts = (0..<3_000).map { Date(timeIntervalSince1970: 1_793_188_800 + Double($0) * 0.001 + (Double($0 % 2) * 0.0002 + 0.0003)) }
        for started in starts {
            let run = TraceRun(
                id: TraceRun.sample(outcome: nil).id, kind: .aiDraft, started: started,
                build: TraceRun.sample(outcome: nil).build, steps: [], outcome: nil
            )
            let read = try TraceRun(document: run.document())
            #expect(read.fileStem == run.fileStem, "a start of \(started.timeIntervalSince1970)")
        }
    }

    // MARK: File name

    @Test("The file name stem holds the UTC start time, the kind and the first eight characters of the id")
    func fileStem() {
        #expect(TraceRun.sample(outcome: nil).fileStem == "run-20261028T120000.125Z-aiDraft-1a2b3c4d")
    }

    // MARK: Summary

    @Test("The summary names the run, its build, its outcome, and each step in order with its fields")
    func summary() {
        let summary = TraceSummary.text(of: .sample(outcome: .failed(code: "grounding")))

        #expect(summary == """
        AI draft 1A2B3C4D-0000-0000-0000-000000000001
        Started: 2026-10-28T12:00:00.125Z
        App 1.0 (121), sandbox, iOS 26.5, iPhone17,1
        Outcome: failed (grounding)

        #1 +0.010s input
          description: "Ten years of nursing."
          length: 21
        #2 +0.250s removal
          removed: true
          stage: grounding
        #3 +1.500s timing
          model: 1.250s

        """)
    }

    @Test("A long text is cut in the summary, and says how long it was; the document keeps it whole")
    func summaryCutsLongText() throws {
        let long = String(repeating: "x", count: 1_000)
        let run = TraceRun.sample(outcome: nil, steps: [TraceStep(sequence: 1, elapsed: .zero, name: .response, fields: [.text("raw", long)])])

        let summary = TraceSummary.text(of: run)

        #expect(summary.contains("raw: \"" + String(repeating: "x", count: TraceSummary.textLimit) + "…\" (1000 bytes)"))
        #expect(summary.contains("Outcome: open"))
        #expect(try TraceRun(document: run.document()).steps[0].fields == [.text("raw", long)])
    }

    // MARK: Retention

    @Test("Retention keeps the ten newest runs by their file names, and lists the others")
    func retention() {
        let stems = (1...12).map { String(format: "run-202610%02dT120000.000Z-aiDraft-0000000%x", $0, $0) }

        let expired = TraceRetention.expired(stems.shuffled())

        #expect(expired == [stems[1], stems[0]])
        #expect(TraceRetention.expired(Array(stems.prefix(10))).isEmpty)
    }

    @Test("The session events keep the last 200")
    func sessionEvents() {
        let old = (0..<150).map { TraceSessionEvent.sample(line: "old \($0)") }
        let new = (0..<80).map { TraceSessionEvent.sample(line: "new \($0)") }

        let kept = TraceSessionLog.appending(new, to: old)

        #expect(kept.count == 200)
        #expect(kept.first?.line == "old 30")
        #expect(kept.last?.line == "new 79")
    }

    @Test("The session events read back from their document")
    func sessionDocument() throws {
        let events = [TraceSessionEvent.sample(line: "draft.started")]
        #expect(try TraceSessionLog.events(document: TraceSessionLog.document(events)) == events)
    }
}

// MARK: - Samples

extension TraceRun {
    static func sample(outcome: TraceOutcome?, steps: [TraceStep]? = nil) -> TraceRun {
        TraceRun(
            id: UUID(uuid: (0x1A, 0x2B, 0x3C, 0x4D, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
            kind: .aiDraft,
            started: Date(timeIntervalSince1970: 1_793_188_800.125),
            build: TraceBuild(appVersion: "1.0", build: "121", distribution: "sandbox", osVersion: "iOS 26.5", deviceModel: "iPhone17,1"),
            steps: steps ?? [
                TraceStep(sequence: 1, elapsed: .milliseconds(10), name: .input, fields: [.text("description", "Ten years of nursing."), .count("length", 21)]),
                TraceStep(sequence: 2, elapsed: .milliseconds(250), name: .removal, fields: [.flag("removed", true), .token("stage", "grounding")]),
                TraceStep(sequence: 3, elapsed: .milliseconds(1_500), name: .timing, fields: [.duration("model", .milliseconds(1_250))]),
            ],
            outcome: outcome
        )
    }
}

extension TraceSessionEvent {
    static func sample(line: String) -> TraceSessionEvent {
        TraceSessionEvent(time: Date(timeIntervalSince1970: 1_793_188_800.125), category: "draft", level: "info", line: line)
    }
}
