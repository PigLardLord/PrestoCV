import Testing
import Foundation
@testable import CVGeneratorAI

/// How the answer of a model to a batch of candidates is read (ADR 0028): it must number the items 1 to n, each once, and an item is a
/// fact only when the model quotes words of the description that contain it.
@Suite("Claim check: reading the answer of the model")
struct ClaimAnswerTests {
    private let description = """
        I speak English and German. My sister speaks Spanish.
        In my free time I like chess, and I know JavaScript.
        """
    private let candidates = [
        ClaimCandidate(kind: .language, value: "English"), ClaimCandidate(kind: .language, value: "German"),
        ClaimCandidate(kind: .language, value: "Spanish"), ClaimCandidate(kind: .interest, value: "chess"),
    ]
    private let quotes = [
        "I speak English and German.", "I speak English and German.", "My sister speaks Spanish.", "In my free time I like chess, and I know JavaScript.",
    ]

    /// The entries that number the candidates `items`, each quoting its sentence and stating it as a fact.
    private func answer(numbered items: [Int], stance: ClaimStance = .fact) -> [ClaimVerdictEntry] {
        items.enumerated().map { index, item in
            ClaimVerdictEntry(item: item, quote: quotes[min(index, quotes.count - 1)], stance: stance)
        }
    }

    private func judged(_ entries: [ClaimVerdictEntry], of candidates: [ClaimCandidate]? = nil, in description: String? = nil) throws -> [ClaimJudgement] {
        try ClaimAnswer.judgements(from: entries, of: candidates ?? self.candidates, in: description ?? self.description)
    }

    // MARK: - The numbers

    @Test("An answer that numbers the items 1 to n gives a judgement for each, in the order of the candidates")
    func wholeAnswer() throws {
        let judgements = try judged(answer(numbered: [1, 2, 3, 4]))

        #expect(judgements.map(\.stance) == [.fact, .fact, .fact, .fact])
        #expect(judgements.map(\.quote) == quotes)
    }

    @Test("The same answer in another order gives the same judgements")
    func anyOrder() throws {
        let entries = answer(numbered: [1, 2, 3, 4])

        #expect(try judged(entries.reversed()) == judged(entries))
    }

    @Test("An answer that skips, repeats, misnumbers, adds or leaves out an item is refused",
          arguments: [
              [1, 2, 4, 5],       // a gap
              [1, 2, 2, 4],       // a repeat
              [1, 2, 3, 3],       // a repeat of the last
              [0, 1, 2, 3],       // numbered from zero
              [2, 3, 4, 5],       // numbered from two
              [1, 2, 3],          // one short
              [1, 2, 3, 4, 5],    // one more
              [],                 // nothing
          ])
    func refusedNumbers(items: [Int]) {
        #expect(throws: ClaimCheckError.invalidAnswer) {
            try judged(answer(numbered: items))
        }
    }

    @Test("An answer with no candidate to answer is no answer, and an empty one is refused when there is one")
    func nothingAskedNothingAnswered() throws {
        #expect(try judged([], of: []) == [])
        #expect(throws: ClaimCheckError.invalidAnswer) { try judged(answer(numbered: [1]), of: []) }
    }

    // MARK: - The quote of a fact

    @Test("A fact with an empty quote is not a fact")
    func emptyQuote() throws {
        var entries = answer(numbered: [1, 2, 3, 4])
        entries[0] = ClaimVerdictEntry(item: 1, quote: "", stance: .fact)
        entries[1] = ClaimVerdictEntry(item: 2, quote: " \n ", stance: .fact)

        #expect(try judged(entries).map(\.stance) == [.notMentioned, .notMentioned, .fact, .fact])
    }

    @Test("A fact whose quote is not in the description is not a fact")
    func quoteNotInTheDescription() throws {
        var entries = answer(numbered: [1, 2, 3, 4])
        entries[1] = ClaimVerdictEntry(item: 2, quote: "I speak fluent German at work.", stance: .fact)

        #expect(try judged(entries).map(\.stance) == [.fact, .notMentioned, .fact, .fact])
    }

    @Test("A fact whose quote does not contain the item is not a fact")
    func quoteWithoutTheItem() throws {
        var entries = answer(numbered: [1, 2, 3, 4])
        entries[3] = ClaimVerdictEntry(item: 4, quote: "I speak English and German.", stance: .fact)

        #expect(try judged(entries).map(\.stance) == [.fact, .fact, .fact, .notMentioned])
    }

    @Test("A quote contains the item as whole words, not as a part of another word")
    func quoteWithAWordOfWhichTheItemIsAPart() throws {
        let candidates = [ClaimCandidate(kind: .skill, value: "Java")]
        let entries = [ClaimVerdictEntry(item: 1, quote: "I know JavaScript.", stance: .fact)]

        #expect(try judged(entries, of: candidates, in: "I know JavaScript.").map(\.stance) == [.notMentioned])
    }

    @Test("A quote may differ from the description in case, accents, spacing and the stop at its end")
    func quoteCopiedLoosely() throws {
        let candidates = [ClaimCandidate(kind: .language, value: "German")]
        let sentence = "Ich spreche Deutsch und German\nauf Arbeit."
        for quote in ["ich spreche DEUTSCH und german auf arbeit", "\"Ich spreche Deutsch und German auf Arbeit.\"", "und German auf Arbeit"] {
            let entries = [ClaimVerdictEntry(item: 1, quote: quote, stance: .fact)]
            #expect(try judged(entries, of: candidates, in: sentence).map(\.stance) == [.fact], "\(quote)")
        }
    }

    @Test("A quote shortened to one clause or one item of a list, inside one sentence, is backed")
    func quoteShortenedInsideASentence() throws {
        let sentence = "I speak English, German and Spanish, and at work I have used Kotlin and Swift."
        let cases = [
            ("German", "I speak German"), ("Spanish", "I speak Spanish."), ("Kotlin", "I have used Kotlin"),
            ("Swift", "at work I have used Swift"),
        ]
        for (value, quote) in cases {
            let entries = [ClaimVerdictEntry(item: 1, quote: quote, stance: .fact)]
            let candidates = [ClaimCandidate(kind: .skill, value: value)]
            #expect(try judged(entries, of: candidates, in: sentence).map(\.stance) == [.fact], "\(quote)")
        }
    }

    @Test("A quote whose words are not in the order of the description is not backed")
    func quoteInAnotherOrder() throws {
        let entries = [ClaimVerdictEntry(item: 1, quote: "German speak I", stance: .fact)]
        let candidates = [ClaimCandidate(kind: .language, value: "German")]

        #expect(try judged(entries, of: candidates, in: "I speak English, German and Spanish.").map(\.stance) == [.notMentioned])
    }

    @Test("A quote stitched from words of two sentences is not backed")
    func quoteStitchedFromTwoSentences() throws {
        let entries = [ClaimVerdictEntry(item: 1, quote: "I speak Spanish", stance: .fact)]

        #expect(try judged(entries, of: [candidates[2]]).map(\.stance) == [.notMentioned])
    }

    @Test("A quote of several whole sentences, as they stand, is backed")
    func quoteOfSeveralSentences() throws {
        let entries = [ClaimVerdictEntry(item: 1, quote: "I speak English and German. My sister speaks Spanish.", stance: .fact)]

        #expect(try judged(entries, of: [candidates[1]]).map(\.stance) == [.fact])
    }

    @Test("A quote with no word in it is not backed")
    func quoteWithoutWords() throws {
        let entries = [ClaimVerdictEntry(item: 1, quote: "...", stance: .fact)]

        #expect(try judged(entries, of: [candidates[3]]).map(\.stance) == [.notMentioned])
    }

    @Test("A stance other than fact stands as the model gave it, whatever its quote")
    func otherStancesAreNotQuestioned() throws {
        for stance in [ClaimStance.wish, .denied, .otherPerson, .notMentioned] {
            let entries = [ClaimVerdictEntry(item: 1, quote: "", stance: stance)]
            #expect(try judged(entries, of: [candidates[2]]).map(\.stance) == [stance])
        }
    }
}
