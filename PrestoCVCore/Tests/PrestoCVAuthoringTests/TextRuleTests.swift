import Testing
@testable import PrestoCVDomain

/// An input and what a rule makes of it, named for the test report.
struct TextCase: CustomTestStringConvertible, Sendable {
    let name: String, input: String, expected: String
    var testDescription: String { name }
}

private func code(_ scalar: Unicode.Scalar) -> String {
    let hex = String(scalar.value, radix: 16, uppercase: true)
    return "U+" + String(repeating: "0", count: max(0, 4 - hex.count)) + hex
}

/// The classes both kinds remove, with scalars at and near the edges of each.
private let removedClasses: [(name: String, scalars: [Unicode.Scalar])] = [
    ("C0 control", ["\u{0000}", "\u{0001}", "\u{0008}", "\u{000E}", "\u{001B}", "\u{001C}", "\u{001F}"]),
    ("DEL", ["\u{007F}"]),
    ("C1 control", ["\u{0080}", "\u{0084}", "\u{0086}", "\u{008D}", "\u{009F}"]),
    ("bidirectional embedding or override", ["\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}"]),
    ("bidirectional isolate", ["\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}"]),
    ("tag character", ["\u{E0000}", "\u{E0001}", "\u{E0020}", "\u{E0041}", "\u{E007F}"]),
]

/// Characters that end a line, and the tab, written as they arrive.
private let lineBreaks: [(name: String, text: String)] = [
    ("CR LF", "\r\n"), ("CR", "\r"), ("LF", "\n"), ("VERTICAL TAB", "\u{000B}"), ("FORM FEED", "\u{000C}"), ("NEL", "\u{0085}"),
    ("LINE SEPARATOR", "\u{2028}"), ("PARAGRAPH SEPARATOR", "\u{2029}"),
]

private func removalCases() -> [TextCase] {
    var cases = removedClasses.flatMap { kind in
        kind.scalars.map { TextCase(name: "\(kind.name) \(code($0))", input: "a\($0)b", expected: "ab") }
    }
    let england = "\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}"
    cases.append(TextCase(name: "a subdivision flag loses its tag characters and stays a black flag", input: england, expected: "\u{1F3F4}"))
    return cases
}

/// Single line: every line break and the tab become one space each.
private let singleLineCases: [TextCase] = {
    var cases = removalCases()
    for lineBreak in lineBreaks { cases.append(TextCase(name: "\(lineBreak.name) is a space", input: "a\(lineBreak.text)b", expected: "a b")) }
    cases.append(TextCase(name: "tab is a space", input: "a\tb", expected: "a b"))
    cases.append(TextCase(name: "a vertical tab does not glue words", input: "foo\u{0B}bar", expected: "foo bar"))
    cases.append(TextCase(name: "a form feed does not glue words", input: "foo\u{0C}bar", expected: "foo bar"))
    cases.append(TextCase(name: "two breaks are two spaces", input: "a\r\n\r\nb", expected: "a  b"))
    cases.append(TextCase(name: "LF CR is two breaks", input: "a\n\rb", expected: "a  b"))
    cases.append(TextCase(name: "CR CR LF is two breaks", input: "a\r\r\nb", expected: "a  b"))
    cases.append(TextCase(name: "a removed scalar between CR and LF separates two breaks", input: "a\r\u{0001}\nb", expected: "a  b"))
    cases.append(TextCase(name: "breaks at the ends are spaces", input: "\ra\n", expected: " a "))
    return cases
}()

/// Multi line: every line break becomes `\n`, and the tab becomes a space.
private let multiLineCases: [TextCase] = {
    var cases = removalCases()
    for lineBreak in lineBreaks { cases.append(TextCase(name: "\(lineBreak.name) is a line feed", input: "a\(lineBreak.text)b", expected: "a\nb")) }
    cases.append(TextCase(name: "tab is a space", input: "a\tb", expected: "a b"))
    cases.append(TextCase(name: "a vertical tab is a line feed", input: "foo\u{0B}bar", expected: "foo\nbar"))
    cases.append(TextCase(name: "a form feed is a line feed", input: "foo\u{0C}bar", expected: "foo\nbar"))
    cases.append(TextCase(name: "two breaks are two line feeds", input: "a\r\n\r\nb", expected: "a\n\nb"))
    cases.append(TextCase(name: "LF CR is two breaks", input: "a\n\rb", expected: "a\n\nb"))
    cases.append(TextCase(name: "CR CR LF is two breaks", input: "a\r\r\nb", expected: "a\n\nb"))
    cases.append(TextCase(name: "a removed scalar between CR and LF separates two breaks", input: "a\r\u{0001}\nb", expected: "a\n\nb"))
    cases.append(TextCase(name: "breaks at the ends are kept", input: "\ra\r\n", expected: "\na\n"))
    return cases
}()

/// Text both kinds return unchanged.
private let keptTexts: [TextCase] = {
    var kept: [TextCase] = []
    func add(_ name: String, _ text: String) { kept.append(TextCase(name: name, input: text, expected: text)) }
    add("zero width joiner in an emoji sequence", "👩\u{200D}👩\u{200D}👧")
    add("zero width joiner in a rainbow flag", "🏳️\u{200D}🌈")
    add("zero width non-joiner in Persian", "می\u{200C}خواهم")
    add("zero width non-joiner after a virama", "ക\u{0D4D}\u{200C}ക")
    add("emoji with a skin tone and a variation selector", "👍🏽 ❤\u{FE0F}")
    add("regional indicators", "🇮🇹")
    add("combining marks", "e\u{0301} a\u{0323}\u{0308} ñ")
    add("right-to-left text", "مرحبا بالعالم שלום")
    add("left-to-right and right-to-left marks", "a\u{200E}b\u{200F}c")
    add("leading and trailing spaces", "  a  ")
    add("repeated spaces", "a    b")
    add("only spaces", "   ")
    add("no-break space", "a\u{00A0}b")
    add("CJK and accented letters", "日本語 Zoë Łukasz")
    add("empty text", "")
    for neighbour in ["\u{0020}", "\u{00A0}", "\u{2027}", "\u{202F}", "\u{2065}", "\u{206A}", "\u{E0080}", "\u{DFFFF}"] as [Unicode.Scalar] {
        add("\(code(neighbour)) next to a removed range", "a\(neighbour)b")
    }
    return kept
}()

private func isChanged(_ scalar: Unicode.Scalar) -> Bool {
    let category = scalar.properties.generalCategory
    return category == .control || category == .lineSeparator || category == .paragraphSeparator
        || (0x202A...0x202E).contains(scalar.value) || (0x2066...0x2069).contains(scalar.value) || (0xE0000...0xE007F).contains(scalar.value)
}

@Suite("CV text rule")
struct TextRuleTests {
    @Test("single-line text loses control, bidirectional and tag characters, and its line breaks and tabs become spaces",
          arguments: singleLineCases)
    func singleLine(_ test: TextCase) { #expect(TextRule.singleLine(test.input) == test.expected) }

    @Test("multi-line text loses control, bidirectional and tag characters, keeps line feeds, and its tabs become spaces",
          arguments: multiLineCases)
    func multiLine(_ test: TextCase) { #expect(TextRule.multiLine(test.input) == test.expected) }

    @Test("joiners, marks, right-to-left text and spaces are kept, in both kinds", arguments: keptTexts)
    func kept(_ test: TextCase) {
        #expect(TextRule.singleLine(test.input) == test.expected)
        #expect(TextRule.multiLine(test.input) == test.expected)
    }

    @Test("normalising twice gives the same text, in both kinds", arguments: singleLineCases + multiLineCases + keptTexts)
    func idempotent(_ test: TextCase) {
        let single = TextRule.singleLine(test.input), multi = TextRule.multiLine(test.input)
        #expect(TextRule.singleLine(single) == single)
        #expect(TextRule.multiLine(multi) == multi)
    }

    @Test("a hostile mix is cleaned the same way, and a second pass changes nothing")
    func hostileMix() {
        let hostile = "\u{202E}Ada\u{0000}\r\nLove\u{E0041}lace\u{2028}\t\u{200D}x\u{0085}\u{2069}"
        #expect(TextRule.singleLine(hostile) == "Ada Lovelace  \u{200D}x ")
        #expect(TextRule.multiLine(hostile) == "Ada\nLovelace\n \u{200D}x\n")
    }

    @Test("over every Unicode scalar: only controls, line and paragraph separators, bidirectional and tag characters change; no line break or control is left")
    func everyScalar() {
        var failures: [String] = []
        for value in UInt32(0)...0x10FFFF {
            guard let scalar = Unicode.Scalar(value) else { continue }
            let text = "a\(scalar)b"
            let single = TextRule.singleLine(text), multi = TextRule.multiLine(text)
            let keptWhenUnaffected = isChanged(scalar) || (single == text && multi == text)
            let singleIsClean = !single.unicodeScalars.contains { isChanged($0) }
            let multiIsClean = !multi.unicodeScalars.contains { isChanged($0) && $0 != "\n" }
            let stable = TextRule.singleLine(single) == single && TextRule.multiLine(multi) == multi
            if !(keptWhenUnaffected && singleIsClean && multiIsClean && stable) { failures.append(code(scalar)) }
        }
        #expect(failures.isEmpty, "wrongly handled: \(failures.prefix(20))")
    }
}
