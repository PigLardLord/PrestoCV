import Foundation
import Testing
@testable import CVGeneratorAI

/// The first pass streams its answer and stops it when the model writes one stretch again and again (#354): greedy sampling looped on
/// one sentence of jobs-de until the window overflowed, after the time of the extraction had run out.
@Suite("An answer that repeats one stretch is caught as it grows")
struct RepeatingAnswerTests {
    private let sentence = "Ich pflege die Beete und plane die Arbeit der Kolonne. "

    private func stream(_ elements: [String], endingWith error: (any Error)? = nil) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            for element in elements { continuation.yield(element) }
            continuation.finish(throwing: error)
        }
    }

    /// The prefixes of `text` a stream gives as the answer grows, a few characters at a time.
    private func growing(_ text: String, by step: Int = 8) -> [String] {
        stride(from: step, through: text.count + step - 1, by: step).map { String(text.prefix($0)) }
    }

    private func watch(_ elements: [String]) async throws -> RepeatingAnswer.Watched<String>? {
        try await RepeatingAnswer.watch(stream(elements), texts: { [$0] }, length: { $0.utf8.count })
    }

    // MARK: - endsRepeating

    @Test("A sentence written four times back to back repeats, also when the fourth stops in the middle")
    func sentenceFourTimes() {
        #expect(RepeatingAnswer.endsRepeating("Seit 2020 bin ich Vorarbeiterin. " + String(repeating: sentence, count: 4)))
        #expect(RepeatingAnswer.endsRepeating(String(repeating: sentence, count: 4) + "Ich pflege die"))
    }

    @Test("A sentence written three times, or four times with other text after, does not repeat")
    func sentenceThreeTimes() {
        #expect(!RepeatingAnswer.endsRepeating(String(repeating: sentence, count: 3)))
        #expect(!RepeatingAnswer.endsRepeating(String(repeating: sentence, count: 4) + "Danach habe ich die Parkanlagen gepflegt."))
    }

    @Test("A short word or number written a few times does not repeat, and written again and again it does")
    func shortStretches() {
        #expect(!RepeatingAnswer.endsRepeating(String(repeating: "2020, ", count: 8)))
        #expect(!RepeatingAnswer.endsRepeating("Sehr, sehr, sehr, sehr"))
        #expect(RepeatingAnswer.endsRepeating(String(repeating: "2020, ", count: 12)))
    }

    @Test("A list that gives one item again and again repeats, each item as one line")
    func repeatedItems() {
        let items = String(repeating: "\"Pflege der Parkanlagen\"\n", count: 4)

        #expect(RepeatingAnswer.repeats(["Gartenbau", items], length: items.utf8.count))
        #expect(!RepeatingAnswer.repeats(["\"Minibagger\"\n\"Rüttelplatte\"\n\"Motorsäge\"\n\"Bewässerungsanlagen\"\n"], length: 60))
    }

    @Test("A stretch longer than any it reads still repeats once the answer is over the longest")
    func longestAnswer() {
        #expect(RepeatingAnswer.repeats(["Gartenbau"], length: RepeatingAnswer.longest + 1))
        #expect(!RepeatingAnswer.repeats(["Gartenbau"], length: RepeatingAnswer.longest))
    }

    @Test("A recorded answer of a whole job does not repeat")
    func ordinaryAnswer() {
        let duties = "Ich teile die Kolonne ein und plane die Pflege der Parkanlagen. Ich fahre Minibagger und arbeite mit Rüttelplatte "
            + "und Motorsäge. Ich verlege Pflasterflächen und baue Bewässerungsanlagen ein."

        #expect(!RepeatingAnswer.repeats(["Vorarbeiterin", "Stadtgärtnerei Hollerbach", duties], length: 400))
    }

    // MARK: - watch

    @Test("A stream that repeats is left at the element that repeats, before its end")
    func watchStopsAStreamThatRepeats() async throws {
        let elements = growing(String(repeating: sentence, count: 12))

        let watched = try await watch(elements)

        #expect(watched?.repeats == true)
        let answer = try #require(watched?.answer)
        #expect(answer.count < elements.last?.count ?? 0)
        #expect(answer.count >= sentence.count * RepeatingAnswer.times)
    }

    @Test("A stream that does not repeat gives its last element")
    func watchKeepsAnAnswer() async throws {
        let text = "Ich teile die Kolonne ein und plane die Pflege der Parkanlagen. Ich fahre Minibagger und arbeite mit Motorsäge."

        let watched = try await watch(growing(text))

        #expect(watched?.answer == text)
        #expect(watched?.repeats == false)
    }

    @Test("A stream whose last stretch repeats between two checks repeats at its end")
    func watchChecksTheEnd() async throws {
        let text = String(repeating: sentence, count: 4)

        let watched = try await watch([String(repeating: sentence, count: 3), text])

        #expect(watched?.answer == text)
        #expect(watched?.repeats == true)
    }

    @Test("A stream with no element gives nothing, and a failing stream throws")
    func watchEmptyAndFailing() async throws {
        struct Failure: Error {}

        #expect(try await watch([]) == nil)
        await #expect(throws: Failure.self) {
            _ = try await RepeatingAnswer.watch(stream(["a"], endingWith: Failure()), texts: { [$0] }, length: { $0.utf8.count })
        }
    }
}
