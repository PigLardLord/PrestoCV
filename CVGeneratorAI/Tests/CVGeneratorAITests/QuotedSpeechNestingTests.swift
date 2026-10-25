import Testing
import Foundation
@testable import CVGeneratorAI

/// A quote may hold a quote of another pair (#249, ADR 0023 rule (c)): a closing mark closes the latest open quote it pairs with,
/// whichever pair that is, and only a mark that closes none of the quotes opened inside ends the quote that holds them. A mark that
/// an inner quote took is never the end of the outer one, closed or not: when nothing else closes the outer quote, it runs to the
/// end of the line of the last mark that may close it.
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

        /// Whether the closing mark of the inner quote is one that the outer pair closes with as well: “…” holding „…”, „…“ holding
        /// “…”, ‘…’ holding ‚…’ and the like. Without the outer closing mark, that mark may be the end of the outer quote.
        var innerMarkClosesTheOuter: Bool { QuotedSpeechNestingTests.closers(of: outer.open).contains(inner.close) }

        /// Whether the closing mark of the outer quote is one that the inner pair closes with as well. Without the inner closing
        /// mark, that mark may be the end of the inner quote.
        var outerMarkClosesTheInner: Bool { QuotedSpeechNestingTests.closers(of: inner.open).contains(outer.close) }
    }

    /// Which of the two quotes of a description a closing mark ends.
    enum Closing: CaseIterable, CustomTestStringConvertible, Sendable {
        case both, outerOnly, innerOnly, neither

        var closesTheOuter: Bool { self == .both || self == .outerOnly }
        var closesTheInner: Bool { self == .both || self == .innerOnly }

        var testDescription: String {
            switch self {
            case .both: "outer and inner closed"
            case .outerOnly: "outer closed, inner open"
            case .innerOnly: "outer open, inner closed"
            case .neither: "outer and inner open"
            }
        }
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

    /// The closing marks of the pair that opens with `open`: „ closes with “ or ”, ‚ with ‘ or ’, and any other mark with its own.
    static func closers(of open: Character) -> Set<Character> {
        Set(supported.filter { $0.open == open }.map(\.close))
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

    /// The words of a description whose claims the quotes decide, one in each sentence or line of the description below.
    private static let claims = ["Swift", "Python", "German", "French"]

    /// For each of `claims`, whether it stands inside a quote of `description`, cut into sentences as the sanitiser cuts it.
    private func quotedClaims(in description: String) -> [String: Bool] {
        let split = SentenceSplitter.sentencesByLine(in: description)
        let sentences = split.map(\.text)
        let lineStarts = Set(split.indices.filter { split[$0].startsALine })
        var result: [String: Bool] = [:]
        for (sentence, inside) in zip(sentences, QuotedSpeech.offsets(in: sentences, lineStarts: lineStarts)) {
            for claim in Self.claims {
                guard let range = sentence.range(of: claim) else { continue }
                let start = sentence.distance(from: sentence.startIndex, to: range.lowerBound)
                result[claim] = (start..<(start + claim.count)).allSatisfy(inside.contains)
            }
        }
        return result
    }

    /// A description with an outer quote that holds an inner quote, each closed or not as `closing` says. Swift stands inside the
    /// inner quote, Python after it in the same sentence, German after the outer closing mark, in the same line, and French in the
    /// line after.
    private func description(_ nesting: Nesting, _ closing: Closing) -> String {
        let (outer, inner) = (nesting.outer, nesting.inner)
        let innerEnd = closing.closesTheInner ? String(inner.close) : ""
        let outerEnd = closing.closesTheOuter ? String(outer.close) : ""
        return "\(outer.open)My colleague wrote:\(inner.open)Swift (ok)\(innerEnd). I use Python.\(outerEnd) I speak German.\nI speak French."
    }

    /// The claims that stand inside a quote, by the rules of the quotes (ADR 0023 rule (c)):
    /// - **Both closed:** each mark closes the quote it pairs with. The quote that holds the other runs to its own closing mark, so
    ///   German, after it, claims as usual.
    /// - **Only the outer closed:** the outer closing mark ends the outer quote, but when the inner pair closes with that mark too,
    ///   it may end the inner one instead, and nothing closes the outer one for sure: it runs to the end of the line, German too.
    /// - **Only the inner closed:** when the inner closing mark is one the outer pair closes with too, it may end the outer quote,
    ///   and nothing else does: the outer quote runs to the end of the line of that mark, German too, and not to the mark. Otherwise
    ///   nothing may close the outer opening mark, a stray mark that quotes nothing: only the inner quote is quoted.
    /// - **Neither closed:** no mark closes anything, and nothing is quoted.
    /// French, in the line after, claims as usual in every case: only a line break tells where another person's words end.
    private func expectedQuotedClaims(_ nesting: Nesting, _ closing: Closing) -> [String: Bool] {
        let quoted: Set<String>
        switch closing {
        case .both: quoted = ["Swift", "Python"]
        case .outerOnly: quoted = nesting.outerMarkClosesTheInner ? ["Swift", "Python", "German"] : ["Swift", "Python"]
        case .innerOnly: quoted = nesting.innerMarkClosesTheOuter ? ["Swift", "Python", "German"] : ["Swift"]
        case .neither: quoted = []
        }
        return Dictionary(uniqueKeysWithValues: Self.claims.map { ($0, quoted.contains($0)) })
    }

    @Test("The table holds every pair both ways round: 128 nestings")
    func tableSize() {
        #expect(Self.nestings.count == 128)
        #expect(Set(Self.nestings.map(\.testDescription)).count == 128)
    }

    @Test("A mark that an inner quote took is no end of the outer quote, whether either quote is closed or not",
          arguments: QuotedSpeechNestingTests.nestings, QuotedSpeechNestingTests.Closing.allCases)
    func quotesAroundAnInnerQuote(nesting: Nesting, closing: Closing) {
        #expect(quotedClaims(in: description(nesting, closing)) == expectedQuotedClaims(nesting, closing))
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

    @Test("Quotes nested two deep close one by one")
    func quotesTwoDeep() {
        #expect(quoted("“A „B ‚C.‘ D.“ E.”\nF.") == ["A „B ‚C.‘ D.“ E.", ""])
        #expect(quoted("„A “B ‘C.’ D.” E.“\nF.") == ["A “B ‘C.’ D.” E.", ""])
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
}
