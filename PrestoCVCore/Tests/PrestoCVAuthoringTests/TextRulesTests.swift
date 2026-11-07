import Testing
import Foundation
import PrestoCVDomain

private func scalar(_ value: UInt32) -> String { String(Unicode.Scalar(value)!) }

/// One representative of each class of character the rule removes, by name.
private let removedClasses: [(name: String, text: String)] = [
    ("embedding LRE", scalar(0x202A)), ("embedding RLE", scalar(0x202B)), ("pop directional", scalar(0x202C)),
    ("override LRO", scalar(0x202D)), ("override RLO", scalar(0x202E)),
    ("isolate LRI", scalar(0x2066)), ("isolate RLI", scalar(0x2067)), ("isolate FSI", scalar(0x2068)), ("pop isolate", scalar(0x2069)),
    ("left-to-right mark", scalar(0x200E)), ("right-to-left mark", scalar(0x200F)), ("Arabic letter mark", scalar(0x061C)),
    ("tag letter", scalar(0xE0041)), ("tag begin", scalar(0xE0001)), ("tag cancel", scalar(0xE007F)),
]

@Suite("R6 · the one text rule")
struct TextRulesTests {
    // MARK: Single-line

    @Test("single-line removes controls, NUL and DEL", arguments: [0x0000, 0x0007, 0x000B, 0x000C, 0x001B, 0x007F, 0x0094].map(UInt32.init))
    func singleLineRemovesControls(code: UInt32) {
        #expect(TextRules.singleLine("a\(scalar(code))b") == "ab")
    }

    @Test("single-line turns CR, LF, CRLF, NEL, tab, U+2028 and U+2029 into one space each",
          arguments: ["\r", "\n", "\r\n", "\u{85}", "\t", "\u{2028}", "\u{2029}"])
    func singleLineBreaks(separator: String) {
        #expect(TextRules.singleLine("a\(separator)b") == "a b")
        #expect(TextRules.singleLine("a\(separator)\(separator)b") == "a  b")
    }

    // MARK: Multi-line

    @Test("multi-line keeps LF, turns CRLF and CR into LF, turns a tab into a space")
    func multiLine() {
        #expect(TextRules.multiLine("a\nb") == "a\nb")
        #expect(TextRules.multiLine("a\r\nb") == "a\nb")
        #expect(TextRules.multiLine("a\rb") == "a\nb")
        #expect(TextRules.multiLine("a\r\n\r\nb\r") == "a\n\nb\n")
        #expect(TextRules.multiLine("a\u{85}b\u{2028}c\u{2029}d") == "a\nb\nc\nd")
        #expect(TextRules.multiLine("a\tb") == "a b")
    }

    @Test("multi-line removes the other controls, NUL and DEL too", arguments: [0x0000, 0x0007, 0x000B, 0x000C, 0x007F].map(UInt32.init))
    func multiLineRemovesControls(code: UInt32) {
        #expect(TextRules.multiLine("a\(scalar(code))b") == "ab")
    }

    // MARK: Hidden characters

    @Test("bidirectional embeddings, overrides, isolates, the three marks and tag characters are removed in both kinds of field",
          arguments: removedClasses.map(\.name))
    func hiddenRemoved(name: String) throws {
        let text = try #require(removedClasses.first { $0.name == name }).text
        #expect(TextRules.singleLine("Ada\(text)Lovelace") == "AdaLovelace")
        #expect(TextRules.multiLine("Ada\(text)\nLovelace") == "Ada\nLovelace")
    }

    @Test("a reversing mark cannot swap the figures of a line")
    func marksDoNotReverse() {
        #expect(TextRules.singleLine("1040 \u{200F}→ 5308") == "1040 → 5308")
    }

    @Test("the joiners that legitimate text needs survive: ZWJ in emoji, ZWNJ in Persian and Devanagari, variation selectors")
    func joinersSurvive() {
        let family = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}"
        let persian = "می\u{200C}خواهم"
        let devanagari = "क्\u{200C}ष"
        let heart = "\u{2764}\u{FE0F}"
        for text in [family, persian, devanagari, heart, "e\u{301}", "日本語"] {
            #expect(TextRules.singleLine(text) == text)
            #expect(TextRules.multiLine(text) == text)
        }
    }

    @Test("the invisible characters the decision does not name are left alone: ZWSP, word joiner, BOM, soft hyphen")
    func otherInvisibleKept() {
        for text in ["a\u{200B}b", "a\u{2060}b", "a\u{FEFF}b", "co\u{00AD}operate"] {
            #expect(TextRules.singleLine(text) == text)
            #expect(TextRules.multiLine(text) == text)
        }
    }

    @Test("a tag-sequence flag emoji loses its tags: the accepted loss, England, Scotland and Wales")
    func tagFlagLosesTags() {
        let scotland = "\u{1F3F4}" + "gbsct".unicodeScalars.map { scalar($0.value + 0xE0000) }.joined() + scalar(0xE007F)
        #expect(TextRules.singleLine(scotland) == "\u{1F3F4}")
        #expect(TextRules.multiLine(scotland) == "\u{1F3F4}")
    }

    // MARK: Idempotence

    @Test("normalising twice equals normalising once, over generated strings that mix every class")
    func idempotent() {
        let alphabet: [String] = ["a", "Z", " ", "é", "\u{1F468}", "\u{200D}", "\u{200C}", "\u{FE0F}", "\n", "\r", "\r\n", "\t", "\u{0}", "\u{7F}",
                                  "\u{85}", "\u{2028}", "\u{2029}", "\u{0B}"] + removedClasses.map(\.text)
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> Int {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int(truncatingIfNeeded: seed >> 33)
        }
        for _ in 0..<500 {
            let text = (0..<(next() % 40)).map { _ in alphabet[next() % alphabet.count] }.joined()
            let single = TextRules.singleLine(text), multi = TextRules.multiLine(text)
            #expect(TextRules.singleLine(single) == single)
            #expect(TextRules.multiLine(multi) == multi)
            #expect(!single.unicodeScalars.contains { $0 == "\n" || $0 == "\r" || $0 == "\t" })
            #expect(!multi.unicodeScalars.contains { $0 == "\r" || $0 == "\t" })
        }
    }
}
