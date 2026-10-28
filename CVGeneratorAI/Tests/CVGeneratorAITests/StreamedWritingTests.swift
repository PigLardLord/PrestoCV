import Foundation
import Testing
@testable import CVGeneratorAI

/// The second pass streams its answer, and an answer cut by its token limit keeps what the model wrote before the cut (#354): it was
/// thrown away and asked again, which wrote the same cut answer and ran out of the pass's time with nothing written.
@Suite("A streamed second pass keeps what it wrote before a cut")
struct StreamedWritingTests {
    private struct Cut: Error {}
    private struct Verdict: Error {}

    private func stream(_ elements: [Int], endingWith error: (any Error)? = nil) -> AsyncThrowingStream<Int, any Error> {
        AsyncThrowingStream { continuation in
            for element in elements { continuation.yield(element) }
            continuation.finish(throwing: error)
        }
    }

    private func keepsAfterACut(_ error: any Error) -> Bool { error is Cut }

    // MARK: - StreamedAnswer

    @Test("A stream that ends on its own gives its last element, complete")
    func completeStream() async throws {
        let last = try await StreamedAnswer.last(of: stream([1, 2, 3]), keepingPartialAfter: keepsAfterACut)

        #expect(last?.answer == 3)
        #expect(last?.isComplete == true)
    }

    @Test("A stream with no element gives nothing")
    func emptyStream() async throws {
        let last = try await StreamedAnswer.last(of: stream([]), keepingPartialAfter: keepsAfterACut)

        #expect(last == nil)
    }

    @Test("A stream cut after an element gives that element, not complete")
    func cutAfterAnElement() async throws {
        let last = try await StreamedAnswer.last(of: stream([1, 2], endingWith: Cut()), keepingPartialAfter: keepsAfterACut)

        #expect(last?.answer == 2)
        #expect(last?.isComplete == false)
    }

    @Test("A cut before any element, and any other failure after one, is thrown")
    func otherFailuresAreThrown() async {
        await #expect(throws: Cut.self) {
            _ = try await StreamedAnswer.last(of: stream([], endingWith: Cut()), keepingPartialAfter: keepsAfterACut)
        }
        await #expect(throws: Verdict.self) {
            _ = try await StreamedAnswer.last(of: stream([1], endingWith: Verdict()), keepingPartialAfter: keepsAfterACut)
        }
    }

    @Test("A cancellation is thrown, even after an element and when every failure would keep it")
    func cancellationIsThrown() async {
        await #expect(throws: CancellationError.self) {
            _ = try await StreamedAnswer.last(of: stream([1], endingWith: CancellationError()), keepingPartialAfter: { _ in true })
        }
    }

    // MARK: - WritingSnapshot

    private let brief = DraftBrief(
        language: "English", headline: "nurse",
        roles: [.init(title: "nurse", hasEnded: false), .init(title: "waiter", hasEnded: true)],
        studies: [], namedSkills: []
    )

    private let technologies = ["Patient care", "Wound dressing", "Medication rounds", "Care plans"]
    private let softSkills = ["Empathy", "Teamwork", "Calm under pressure"]
    private let summary = "A caring nurse who looks after patients. Works well with doctors and families."

    @Test("A complete answer is kept whole, each description at its role's number")
    func completeAnswerIsKept() {
        let snapshot = WritingSnapshot(
            technologies: technologies, softSkills: softSkills, summary: summary,
            roles: [.init(number: 2, text: "Served tables"), .init(number: 1, text: "Looks after patients.")]
        )

        let writing = snapshot.writing(for: brief, isComplete: true)

        #expect(writing == DraftWriting(
            summary: summary, roleDescriptions: ["Looks after patients.", "Served tables"],
            technologies: technologies, softSkills: softSkills
        ))
    }

    @Test("A cut in a role keeps the roles before it and the whole sentences of the cut one")
    func cutInARole() {
        let cut = WritingSnapshot(
            technologies: technologies, softSkills: softSkills, summary: summary,
            roles: [.init(number: 1, text: "Looks after patients. Gives medic"), .init(number: 2, text: "Served")]
        )
        let cutInTheFirst = WritingSnapshot(
            technologies: technologies, softSkills: softSkills, summary: summary,
            roles: [.init(number: 1, text: "Looks after patients. Gives medic")]
        )

        #expect(cut.writing(for: brief, isComplete: false).roleDescriptions == ["Looks after patients. Gives medic", nil])
        #expect(cutInTheFirst.writing(for: brief, isComplete: false).roleDescriptions == ["Looks after patients.", nil])
        #expect(cut.writing(for: brief, isComplete: false).summary == summary)
    }

    @Test("A cut in the summary keeps its whole sentences and the skills, and no role")
    func cutInTheSummary() {
        let cut = WritingSnapshot(
            technologies: technologies, softSkills: softSkills,
            summary: "A caring nurse who looks after patients. Works well with doc", roles: nil
        )
        let cutInTheFirstSentence = WritingSnapshot(technologies: technologies, softSkills: softSkills, summary: "A caring nur", roles: nil)

        let writing = cut.writing(for: brief, isComplete: false)

        #expect(writing.summary == "A caring nurse who looks after patients.")
        #expect(writing.technologies == technologies)
        #expect(writing.softSkills == softSkills)
        #expect(writing.roleDescriptions == [nil, nil])
        #expect(cutInTheFirstSentence.writing(for: brief, isComplete: false).summary == nil)
    }

    @Test("A cut in a list of skills keeps the skills before the cut one, and the lists before it")
    func cutInTheSkills() {
        let cutInTheSoftSkills = WritingSnapshot(
            technologies: technologies, softSkills: ["Empathy", "Team"], summary: nil, roles: nil
        )
        let cutInTheTechnologies = WritingSnapshot(technologies: ["Patient care", "Wound dre"], softSkills: nil, summary: nil, roles: nil)

        #expect(cutInTheSoftSkills.writing(for: brief, isComplete: false).softSkills == ["Empathy"])
        #expect(cutInTheSoftSkills.writing(for: brief, isComplete: false).technologies == technologies)
        #expect(cutInTheTechnologies.writing(for: brief, isComplete: false).technologies == ["Patient care"])
        #expect(cutInTheTechnologies.writing(for: brief, isComplete: false).summary == nil)
    }
}
