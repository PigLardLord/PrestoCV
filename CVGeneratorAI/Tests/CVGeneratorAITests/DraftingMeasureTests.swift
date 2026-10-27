import Testing
import Foundation
import CVGeneratorAI

// The harness of the drafting evaluation (#202) runs on the real model, on one host, on request. What it records of a run and how it
// reads a failure are plain code, tested here everywhere with runs made by hand: a refusal is counted, a claim check that gave no
// answer says why, and an example that lost its name is a miss.

@Suite("Drafting evaluation: what one run records")
struct DraftingMeasureTests {
    // MARK: - Why the claim check gave no answer

    @Test("The cause of an unchecked draft is the first call that failed on its own, else a wrong count, else the time", arguments: CauseCase.all)
    func cause(_ item: CauseCase) {
        #expect(UncheckedCause(events: item.events) == item.cause, "\(item)")
    }

    // MARK: - The recording checker

    @Test("The recording checker passes the answer through and records the call")
    func recordsAnAnswer() async throws {
        let log = CheckLog()
        let answer = [ClaimJudgement(stance: .fact, quote: "q"), ClaimJudgement(stance: .wish, quote: "")]
        let checker = CheckRecorder(wrapped: StubChecker(.success(answer)), log: log)

        let judged = try await checker.judgements(of: Self.candidates(2), in: "description")

        #expect(judged == answer)
        #expect(await log.events == [CheckEvent(candidates: 2, answers: 2, error: nil, cancelled: false)])
    }

    @Test("The recording checker rethrows the error, records it, and does not call it cancelled")
    func recordsAnError() async {
        let log = CheckLog()
        let checker = CheckRecorder(wrapped: StubChecker(.failure(StubError.boom)), log: log)

        await #expect(throws: StubError.boom) { try await checker.judgements(of: Self.candidates(3), in: "description") }

        let events = await log.events
        #expect(events.count == 1)
        #expect(events.first?.candidates == 3)
        #expect(events.first?.answers == nil)
        #expect(events.first?.error?.contains("boom") == true)
        #expect(events.first?.cancelled == false)
    }

    @Test("A call that fails once its task was cancelled is recorded as cancelled, whatever it threw")
    func recordsACancelledCall() async {
        let log = CheckLog()
        let checker = CheckRecorder(wrapped: StubChecker(.failure(StubError.boom)), log: log)

        let events = await Task {
            withUnsafeCurrentTask { $0?.cancel() }
            _ = try? await checker.judgements(of: Self.candidates(1), in: "description")
            return await log.events
        }.value

        #expect(events.map(\.cancelled) == [true])
        #expect(UncheckedCause(events: events) == .timedOut)
    }

    // MARK: - A run that ended well

    @Test("A run that ended well has no failure and no cause")
    func wellEnded() throws {
        let measured = try DraftMeasures.measure("en-plain")

        #expect(measured.failure == nil)
        #expect(measured.uncheckedCause == nil)
        #expect(!measured.unchecked)
        #expect(!measured.refused)
        #expect(measured.error == nil)
        #expect(measured.final != nil)
        #expect(measured.report.invented.isEmpty)
    }

    @Test("Every record carries the revision it measured")
    func carriesTheRevision() throws {
        let measured = try DraftMeasures.measure("it-plain", run: 2, revision: "feedbee")
        let encoded = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(measured)) as? [String: Any])

        #expect(measured.revision == "feedbee")
        #expect(encoded["revision"] as? String == "feedbee")
        #expect(encoded["id"] as? String == "it-plain")
        #expect(encoded["run"] as? Int == 2)
    }

    // MARK: - A run that failed

    @Test("A run that threw is a failure, counts no refusal, and loses every fact")
    func threw() throws {
        let input = try InventedFactsTests.input("en-plain")
        let measured = try DraftMeasures.measure("en-plain", Tweak(error: CVGenerationError.serviceFailed))

        #expect(measured.failure?.hasPrefix("threw") == true)
        #expect(measured.error != nil)
        #expect(!measured.refused)
        #expect(measured.final == nil)
        #expect(measured.report.kept.isEmpty)
        #expect(measured.report.lost == input.facts)
    }

    @Test("A run the use case refused is a refusal and a failure")
    func refused() throws {
        let measured = try DraftMeasures.measure("en-traps", Tweak(error: CVGenerationError.contentNotAllowed))

        #expect(measured.refused)
        #expect(measured.failure?.hasPrefix("refused") == true)
        #expect(measured.error != nil)
    }

    @Test("Another error of the use case is no refusal", arguments: [
        CVGenerationError.generationFailed, .busy, .serviceFailed, .emptyResult, .unsupportedLanguage, .descriptionTooShort,
    ])
    func otherErrors(_ error: CVGenerationError) throws {
        let measured = try DraftMeasures.measure("en-plain", Tweak(error: error))

        #expect(!measured.refused)
        #expect(measured.failure != nil)
    }

    @Test("A cancellation is no refusal")
    func cancellation() throws {
        #expect(try !DraftMeasures.measure("en-plain", Tweak(error: CancellationError())).refused)
    }

    @Test("A draft whose claim check gave no answer is a failure that says why")
    func unchecked() throws {
        let thrown = CheckEvent(candidates: 4, answers: nil, error: "serviceFailed", cancelled: false)
        let measured = try DraftMeasures.measure("pt-traps", Tweak(unchecked: true, checks: [thrown]))

        #expect(measured.unchecked)
        #expect(measured.error == nil)
        #expect(measured.final != nil)
        #expect(measured.uncheckedCause?.contains("serviceFailed") == true)
        #expect(measured.failure?.contains("the claim check gave no answer: a call threw serviceFailed") == true)
    }

    @Test("An unchecked draft whose check was never asked says so")
    func uncheckedNotAsked() throws {
        let measured = try DraftMeasures.measure("pt-traps", Tweak(unchecked: true))

        #expect(measured.uncheckedCause == UncheckedCause.notAsked.description)
        #expect(measured.failure != nil)
    }

    // MARK: - The invented fields

    @Test("The fields of the model's own draft that are invented are counted apart from the final draft's")
    func rawInvented() throws {
        let removed = Tweak(edit: { $0.interests.append("Origami") }, finalEdit: { $0.interests.removeLast() })
        let measured = try DraftMeasures.measure("en-plain", removed)

        #expect(measured.rawInvented.map(\.value) == ["Origami"])
        #expect(measured.report.invented.isEmpty)
        #expect(measured.raw != measured.final)
    }

    @Test("A field of the final draft that the counter proves invented is in its report")
    func finalInvented() throws {
        let measured = try DraftMeasures.measure("en-plain", Scenario.invented)

        #expect(measured.report.invented.map(\.value) == ["Origami"])
        #expect(measured.rawInvented.map(\.value) == ["Origami"])
    }

    // MARK: - The examples

    @Test("An example that keeps its name, its title and a job misses nothing")
    func exampleKept() throws {
        #expect(try DraftMeasures.measure("example-en").misses.isEmpty)
    }

    @Test("An example misses what its draft lost", arguments: [
        MissCase(label: "name", edit: { $0.name = nil }, miss: "lost the name"),
        MissCase(label: "title", edit: { $0.title = nil }, miss: "lost the title"),
        MissCase(label: "jobs", edit: { $0.experience = [] }, miss: "kept no job"),
    ])
    func exampleMisses(_ item: MissCase) throws {
        let measured = try DraftMeasures.measure("example-en", Tweak(edit: item.edit))

        #expect(measured.misses == [item.miss], "\(item.label)")
    }

    @Test("Only an example is gated on its name, its title and a job")
    func otherKindsHaveNoMisses() throws {
        #expect(try DraftMeasures.measure("en-plain", Tweak(edit: { $0.name = nil })).misses.isEmpty)
        #expect(try DraftMeasures.measure("en-traps", Tweak(edit: { $0.experience = [] })).misses.isEmpty)
    }

    @Test("An example whose run gave no draft has a failure, not three misses")
    func exampleThatThrew() throws {
        let measured = try DraftMeasures.measure("example-en", Tweak(error: CVGenerationError.generationFailed))

        #expect(measured.misses.isEmpty)
        #expect(measured.failure != nil)
    }

    // MARK: - Helpers

    static func candidates(_ count: Int) -> [ClaimCandidate] {
        (0..<count).map { ClaimCandidate(kind: .skill, value: "skill \($0)") }
    }
}

// MARK: - Cases

struct CauseCase: Sendable, CustomTestStringConvertible {
    let label: String
    let events: [CheckEvent]
    let cause: UncheckedCause

    var testDescription: String { label }

    private static func answer(_ candidates: Int, _ answers: Int) -> CheckEvent {
        CheckEvent(candidates: candidates, answers: answers, error: nil, cancelled: false)
    }

    private static func thrown(_ error: String, cancelled: Bool = false) -> CheckEvent {
        CheckEvent(candidates: 8, answers: nil, error: error, cancelled: cancelled)
    }

    static let all: [CauseCase] = [
        CauseCase(label: "no call", events: [], cause: .notAsked),
        CauseCase(label: "every call answered in full", events: [answer(8, 8), answer(2, 2)], cause: .timedOut),
        CauseCase(label: "a call threw", events: [answer(8, 8), thrown("boom")], cause: .threw("boom")),
        CauseCase(label: "the only call was cancelled", events: [thrown("CancellationError()", cancelled: true)], cause: .timedOut),
        CauseCase(label: "a call answered the wrong count", events: [answer(8, 3)], cause: .answerCount(candidates: 8, answers: 3)),
        CauseCase(
            label: "a cancelled call, then one that threw on its own", events: [thrown("late", cancelled: true), thrown("boom")],
            cause: .threw("boom")
        ),
        CauseCase(label: "a wrong count, then a throw", events: [answer(8, 3), thrown("boom")], cause: .threw("boom")),
    ]
}

struct MissCase: Sendable, CustomTestStringConvertible {
    let label: String
    let edit: @Sendable (inout Draft) -> Void
    let miss: String

    var testDescription: String { label }
}

enum StubError: Error, Equatable { case boom }

/// A claim check that answers, or fails, as it was told.
struct StubChecker: ClaimChecking {
    let result: Result<[ClaimJudgement], any Error>

    init(_ result: Result<[ClaimJudgement], any Error>) {
        self.result = result
    }

    func judgements(of candidates: [ClaimCandidate], in description: String) async throws -> [ClaimJudgement] {
        try result.get()
    }
}
