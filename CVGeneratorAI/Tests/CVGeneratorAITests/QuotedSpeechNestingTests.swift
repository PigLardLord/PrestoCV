import Testing
import Foundation
@testable import CVGeneratorAI

/// A quote may hold a quote of another pair (#249, ADR 0023 rule (c)): a closing mark closes the latest open quote it pairs with,
/// whichever pair that is, and only a mark that closes none of the quotes opened inside ends the quote that holds them.
///
/// The descriptions here are cut into sentences the way the sanitiser cuts them (`SentenceSplitter`), so a full stop that stands
/// right before a closing mark is no sentence end, and the inner quotes end before the full stop of their sentence.
@Suite("Quoted speech: a quote holds the quotes of other pairs")
struct QuotedSpeechNestingTests {
    /// A pair of marks as a description writes it.
    struct Marks: CustomTestStringConvertible, Sendable {
        let open: Character
        let close: Character

        var testDescription: String { "\(open)…\(close)" }
    }

    /// An outer pair and the pair it holds.
    struct Nesting: CustomTestStringConvertible, Sendable {
        let outer: Marks
        let inner: Marks

        var testDescription: String { "\(inner.testDescription) inside \(outer.testDescription)" }
    }

    /// Every pair of the six languages, as the description writes it: „ closes with “ or ”, and ‚ with ‘ or ’.
    static let supported: [Marks] = [
        Marks(open: "«", close: "»"), Marks(open: "»", close: "«"), Marks(open: "‹", close: "›"), Marks(open: "›", close: "‹"),
        Marks(open: "“", close: "”"), Marks(open: "„", close: "“"), Marks(open: "„", close: "”"), Marks(open: "‚", close: "‘"),
        Marks(open: "‚", close: "’"), Marks(open: "‘", close: "’"), Marks(open: "\"", close: "\""), Marks(open: "'", close: "'"),
    ]

    /// Each outer pair with each inner pair that opens with another mark, both ways round: a quote of one mark inside a quote of
    /// the same mark has no telling apart, and the quote ends at the first closing mark.
    static let nestings: [Nesting] = supported.flatMap { outer in
        supported.filter { $0.open != outer.open }.map { Nesting(outer: outer, inner: $0) }
    }

    /// The words of the inner quote. It starts with a letter, so that its opening mark is no closing mark of the outer pair (« after
    /// a colon), and ends with a closing bracket, so that a single mark after it is no apostrophe and the quote can end before the
    /// full stop of its sentence.
    private static let words = "Swift (ok)"

    /// The characters of each sentence that stand inside a quote, the description cut into sentences as the sanitiser cuts it.
    private func quoted(_ description: String) -> [String] {
        let split = SentenceSplitter.sentencesByLine(in: description)
        let sentences = split.map(\.text)
        let lineStarts = Set(split.indices.filter { split[$0].startsALine })
        return zip(sentences, QuotedSpeech.offsets(in: sentences, lineStarts: lineStarts)).map { sentence, inside in
            let characters = Array(sentence)
            return String(inside.map { characters[$0] })
        }
    }

    @Test("The table holds every pair both ways round: 128 nestings")
    func tableSize() {
        #expect(Self.nestings.count == 128)
        #expect(Set(Self.nestings.map(\.testDescription)).count == 128)
    }

    @Test("A closing mark closes the quote it pairs with: the sentence after an inner quote is quoted to the outer mark",
          arguments: QuotedSpeechNestingTests.nestings)
    func quoteAfterAnInnerQuote(nesting: Nesting) {
        let (outer, inner) = (nesting.outer, nesting.inner)
        let description = "\(outer.open)My colleague wrote:\(inner.open)\(Self.words)\(inner.close). I use Python.\(outer.close)\nI speak French."

        #expect(quoted(description) == [
            "My colleague wrote:\(inner.open)\(Self.words)\(inner.close).", "I use Python.", "",
        ])
    }

    @Test("A mark alone on its line is a symbol the quote holds when a later mark ends it: the inner quote and the sentence after it stay quoted",
          arguments: QuotedSpeechNestingTests.nestings)
    func loneMarkBeforeAnInnerQuote(nesting: Nesting) {
        let (outer, inner) = (nesting.outer, nesting.inner)
        let description = """
            My colleague wrote \(outer.open)
            In my table, the ditto symbol is:
            \(outer.close)
            I say:\(inner.open)\(Self.words)\(inner.close). I use Python.
            End of my message.\(outer.close)
            I speak French.
            """

        #expect(quoted(description) == [
            "", "In my table, the ditto symbol is:", "\(outer.close)", "I say:\(inner.open)\(Self.words)\(inner.close).",
            "I use Python.", "End of my message.", "",
        ])
    }

    @Test("The mark alone on its line closes the quote when nothing later ends it, whatever pairs close in between",
          arguments: QuotedSpeechNestingTests.nestings)
    func loneMarkThatEndsTheQuote(nesting: Nesting) {
        let (outer, inner) = (nesting.outer, nesting.inner)
        let description = "My colleague wrote \(outer.open)\nI say:\(inner.open)\(Self.words)\(inner.close).\n\(outer.close)\nI use Python."

        #expect(quoted(description) == ["", "I say:\(inner.open)\(Self.words)\(inner.close).", "", ""])
    }

    @Test("The German quote of the gate: the “ that closes „…“ is no end of the quote that holds it")
    func germanQuoteInsideTheQuote() {
        let description = """
            Mein Kollege schrieb “
            In meiner Tabelle ist das Wiederholungszeichen:
            ”
            Mein Motto ist „Sauberer Code“. Ich benutze Swift.
            Ende meiner Nachricht.”
            Ich spreche Deutsch.
            """

        #expect(quoted(description) == [
            "", "In meiner Tabelle ist das Wiederholungszeichen:", "”", "Mein Motto ist „Sauberer Code“.", "Ich benutze Swift.",
            "Ende meiner Nachricht.", "",
        ])
    }

    @Test("An inner quote that closes with the closing mark of the outer pair does not end the quote that holds it")
    func innerQuoteWithTheClosingMarkOfTheOuterPair() {
        #expect(quoted("„Er sagte “Hallo” zu mir. Ich benutze Swift.“\nIch spreche Deutsch.") == [
            "Er sagte “Hallo” zu mir.", "Ich benutze Swift.", "",
        ])
        #expect(quoted("“Er sagte „Hallo” zu mir. Ich benutze Swift.”\nIch spreche Deutsch.") == [
            "Er sagte „Hallo” zu mir.", "Ich benutze Swift.", "",
        ])
    }

    @Test("Quotes nested two deep close one by one")
    func quotesTwoDeep() {
        #expect(quoted("“A „B ‚C.‘ D.“ E.”\nF.") == ["A „B ‚C.‘ D.“ E.", ""])
        #expect(quoted("„A “B ‘C.’ D.” E.“\nF.") == ["A “B ‘C.’ D.” E.", ""])
    }

    @Test("The mark that closes none of the quotes inside ends the quote that holds them")
    func closingMarkOfNoInnerQuote() {
        #expect(quoted("“Er sagte „Hallo“ zu mir.” Ich benutze Swift.") == ["Er sagte „Hallo“ zu mir."])
        #expect(quoted("„Er sagte “Hallo” zu mir.“ Ich benutze Swift.") == ["Er sagte “Hallo” zu mir."])
    }

    @Test("A possessive inside the inner quote is no mark")
    func possessiveInsideTheInnerQuote() {
        #expect(quoted("“My colleague wrote ‘I lead Hans’ team.’ I use Python.”\nI speak French.") == [
            "My colleague wrote ‘I lead Hans’ team.’ I use Python.", "",
        ])
        #expect(quoted("„Mein Kollege schrieb ‚Ich leite Hans’ Team.‘ Ich benutze Python.“\nIch spreche Deutsch.") == [
            "Mein Kollege schrieb ‚Ich leite Hans’ Team.‘ Ich benutze Python.", "",
        ])
    }

    @Test("An inner opening mark that nothing closes leaves the quote to end at its first closing mark")
    func innerQuoteThatNothingCloses() {
        #expect(quoted("„Er sagte „Hallo“ Ich benutze Swift.") == ["Er sagte „Hallo"])
        #expect(quoted("“Er sagte „Hallo.” Ich benutze Swift.") == ["Er sagte „Hallo."])
    }
}
