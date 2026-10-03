import Testing
import TailoringModel

@Suite("ADR 0013 · statements: the one rule that splits a description")
struct StatementSplitTests {
    private func texts(_ description: String) -> [String] { Statement.split(description).map(\.text) }

    @Test("a description of one paragraph is one statement")
    func oneParagraph() {
        #expect(texts("Led a team of five engineers and cut release time by 30% in 2021.")
                == ["Led a team of five engineers and cut release time by 30% in 2021."])
    }

    @Test("an empty description, or one of blanks, has no statements", arguments: ["", " ", "\n", " \n\t\n  ", "\r\n\r\n"])
    func empty(description: String) {
        #expect(Statement.split(description).isEmpty)
    }

    @Test("every line is one statement, in order")
    func lines() {
        #expect(texts("Built the API\nMigrated the database\nTrained two juniors") == ["Built the API", "Migrated the database", "Trained two juniors"])
    }

    @Test("blank lines are dropped")
    func blankLines() {
        #expect(texts("first\n\n   \n\t\nsecond\n\n") == ["first", "second"])
    }

    @Test("leading and trailing spaces and tabs are trimmed on every line")
    func trimming() {
        #expect(texts("   first  \n\tsecond\t\n  third word  ") == ["first", "second", "third word"])
    }

    @Test("a line break is any newline, and \\r\\n is one break", arguments: [
        "first\nsecond", "first\r\nsecond", "first\rsecond", "first\u{2028}second", "first\u{2029}second", "first\u{0085}second",
    ])
    func newlines(description: String) {
        #expect(texts(description) == ["first", "second"])
    }

    @Test("one leading bullet followed by a space is not part of the statement", arguments: [
        "\u{2022}", "\u{25E6}", "\u{25AA}", "\u{2023}", "\u{00B7}", "-", "*", "\u{2013}", "\u{2014}",
    ])
    func bullets(bullet: String) {
        #expect(texts("\(bullet) Reduced churn") == ["Reduced churn"])
        #expect(texts("  \(bullet)   Reduced churn  ") == ["Reduced churn"])
        #expect(texts("\(bullet)\tReduced churn") == ["Reduced churn"])
        #expect(texts("\(bullet) first\n\(bullet) second") == ["first", "second"])
    }

    @Test("a bullet with no space after it belongs to the statement", arguments: [
        "-5% churn", "*emphasis* matters", "\u{2022}text", "\u{2013}5 points", "\u{2014}dash", "--flag", "-- notes",
    ])
    func bulletWithoutSpace(line: String) {
        #expect(texts(line) == [line])
    }

    @Test("only one bullet is removed")
    func oneBullet() {
        #expect(texts("- - nested") == ["- nested"])
        #expect(texts("\u{2022} * starred") == ["* starred"])
    }

    @Test("a hyphen inside a line is kept")
    func innerHyphen() {
        #expect(texts("- Built a well-known - and loved - tool") == ["Built a well-known - and loved - tool"])
    }

    @Test("a line that is only a bullet is dropped", arguments: ["-", "\u{2022}", "*", " \u{2014} ", "\u{2022} "])
    func lineOfABullet(line: String) {
        #expect(texts("first\n\(line)\nsecond") == ["first", "second"])
        #expect(Statement.split(line).isEmpty)
    }

    @Test("a numbered item is not a bullet", arguments: ["1. Led the team", "2) Shipped it", "a. Wrote tests"])
    func numbered(line: String) {
        #expect(texts(line) == [line])
    }

    @Test("accents and symbols in the text are kept as written")
    func unicode() {
        #expect(texts("\u{2022} R\u{00E9}duit les co\u{00FB}ts de 30 % \u{2014} \u{00E0} Paris") == ["R\u{00E9}duit les co\u{00FB}ts de 30 % \u{2014} \u{00E0} Paris"])
    }

    @Test("a mixed description keeps the lines that say something")
    func mixed() {
        let description = "\u{2022} Led the platform team\r\n\r\n- Cut cost by -5%\n   \n* Hired 3 people  \n2. Ran the on-call rota"
        #expect(texts(description) == ["Led the platform team", "Cut cost by -5%", "Hired 3 people", "2. Ran the on-call rota"])
    }
}

@Suite("ADR 0013 / R8 · a statement built from text")
struct StatementInitTests {
    @Test("the text is trimmed and kept as written")
    func built() throws {
        #expect(try Statement(text: "  Cut costs  \n").text == "Cut costs")
        #expect(try Statement(text: "- Cut costs").text == "- Cut costs")
    }

    @Test("a statement of nothing is refused", arguments: ["", " ", "\n", " \t\r\n "])
    func empty(text: String) {
        #expect(throws: TailoringModelError.emptyField(.statement)) { try Statement(text: text) }
    }

    @Test("the limit is 10,000 UTF-8 bytes: accepted at the limit, refused one over")
    func bounded() throws {
        #expect(TailoringLimits.maxTextBytes == 10_000)
        #expect(try Statement(text: ascii(10_000)).text.utf8.count == 10_000)
        #expect(throws: TailoringModelError.tooLarge(.statement)) { try Statement(text: ascii(10_001)) }
    }

    @Test("the limit counts bytes, not characters")
    func bytes() throws {
        #expect(try Statement(text: twoByteCharacters(bytes: 10_000)).text.count == 5_000)
        #expect(throws: TailoringModelError.tooLarge(.statement)) { try Statement(text: twoByteCharacters(bytes: 10_002)) }
    }

    @Test("a statement made by the split equals one built from the same text")
    func sameValue() throws {
        #expect(Statement.split("- Cut costs") == [try Statement(text: "Cut costs")])
    }
}
