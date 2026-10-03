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

    static let blankDescriptions: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["", " ", "\n", " \n\t\n  ", "\r\n\r\n"])
        values.append(contentsOf: blankStrings)
        values.append(contentsOf: ["\n\u{200B}\n\u{FEFF}\n\u{00A0}\n"])
        return values
    }()

    @Test("an empty description, or one of blanks, has no statements", arguments: blankDescriptions)
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

    static let twoLineDescriptions: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["first\nsecond", "first\r\nsecond", "first\rsecond"])
        values.append(contentsOf: ["first\u{2028}second", "first\u{2029}second", "first\u{0085}second"])
        return values
    }()

    @Test("a line ends at any newline", arguments: twoLineDescriptions)
    func newlines(description: String) {
        #expect(texts(description) == ["first", "second"])
    }

    @Test("a carriage return and a line feed leave no carriage return behind, and two pairs in a row are one blank line")
    func carriageReturnLineFeed() {
        #expect(texts("a\r\nb") == ["a", "b"])
        #expect(texts("a\r\n\r\nb") == ["a", "b"])
        #expect(texts("a\r\n") == ["a"])
        #expect(Statement.split("a\r\nb").map { $0.text.utf8.count } == [1, 1])
    }

    static let bulletCharacters: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["\u{2022}", "\u{25E6}", "\u{25AA}", "\u{2023}", "\u{00B7}"])
        values.append(contentsOf: ["-", "*", "\u{2013}", "\u{2014}"])
        values.append(contentsOf: ["\u{25CF}", "\u{25CB}", "\u{25A0}", "\u{27A2}", "\u{27A4}", "\u{2713}", "\u{F0B7}"])
        return values
    }()

    @Test("one leading bullet followed by a space is not part of the statement", arguments: bulletCharacters)
    func bullets(bullet: String) {
        #expect(texts("\(bullet) Reduced churn") == ["Reduced churn"])
        #expect(texts("  \(bullet)   Reduced churn  ") == ["Reduced churn"])
        #expect(texts("\(bullet)\tReduced churn") == ["Reduced churn"])
        #expect(texts("\(bullet) first\n\(bullet) second") == ["first", "second"])
    }

    static let unspacedBullets: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["-5% churn", "*emphasis* matters", "\u{2022}text", "\u{2013}5 points"])
        values.append(contentsOf: ["\u{2014}dash", "--flag", "-- notes"])
        return values
    }()

    @Test("a bullet with no space after it belongs to the statement", arguments: unspacedBullets)
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

    static let bulletOnlyLines: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["-", "\u{2022}", "*", " \u{2014} ", "\u{2022} "])
        values.append(contentsOf: ["-\u{200B}", "\u{FEFF}\u{2022}", "\u{FEFF}- \u{200B}", "-\u{00A0}", "\u{3000}*\u{2003}"])
        return values
    }()

    @Test("a line that is only a bullet is dropped", arguments: bulletOnlyLines)
    func lineOfABullet(line: String) {
        #expect(texts("first\n\(line)\nsecond") == ["first", "second"])
        #expect(Statement.split(line).isEmpty)
    }

    static let numberedItems: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["1. Led the team", "2) Shipped it", "a. Wrote tests"])
        return values
    }()

    @Test("a numbered item is not a bullet", arguments: numberedItems)
    func numbered(line: String) {
        #expect(texts(line) == [line])
    }

    @Test("accents and symbols in the text are kept as written")
    func unicode() {
        #expect(texts("\u{2022} R\u{00E9}duit les co\u{00FB}ts de 30 % \u{2014} \u{00E0} Paris") == ["R\u{00E9}duit les co\u{00FB}ts de 30 % \u{2014} \u{00E0} Paris"])
    }

    static let multiLineDescriptions: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["a\nb\r\nc\rd\u{2028}e\u{2029}f\u{0085}g\u{000B}h\u{000C}i"])
        values.append(contentsOf: ["- a\n\n* b\r\n\r\n\u{2022} c", "one paragraph", "\n\n a \n\n b \n"])
        return values
    }()

    @Test("every statement of a description is one line", arguments: multiLineDescriptions)
    func oneLineEach(description: String) {
        let statements = Statement.split(description)
        #expect(!statements.isEmpty)
        for statement in statements {
            let hasLineBreak = statement.text.contains(where: \.isNewline)
            #expect(!hasLineBreak)
            #expect(!statement.text.isEmpty)
        }
    }

    @Test("whitespace of any width and invisible format characters around a line are trimmed", arguments: invisibleCharacters)
    func aroundText(padding: String) {
        #expect(texts("\(padding)text\(padding)") == ["text"])
        #expect(texts("\(padding)\(padding)two words\(padding)\nnext\(padding)") == ["two words", "next"])
    }

    @Test("an invisible character between words stays where it was written")
    func insideText() {
        #expect(texts("a\u{200B}b") == ["a\u{200B}b"])
        #expect(texts("a \u{00A0} b") == ["a \u{00A0} b"])
    }

    @Test("a bullet is removed when whitespace follows it, and what follows that is trimmed", arguments: invisibleCharacters)
    func afterABullet(invisible: String) {
        #expect(texts("- \(invisible)text") == ["text"])
        #expect(texts("\u{2022}\u{00A0}\(invisible)text\(invisible)") == ["text"])
    }

    @Test("an invisible character before the bullet is trimmed first", arguments: invisibleCharacters)
    func beforeABullet(invisible: String) {
        #expect(texts("\(invisible)- text") == ["text"])
        #expect(texts("\(invisible)\u{2022} text") == ["text"])
    }

    @Test("a bullet that no whitespace follows keeps what is written, an invisible character included")
    func bulletThenInvisible() {
        #expect(texts("-\u{200B}text") == ["-\u{200B}text"])
        #expect(texts("*\u{FEFF} text") == ["*\u{FEFF} text"])
    }

    @Test("a combining mark on a bullet or on the space after it keeps the bullet, with nothing left orphaned")
    func markedBullet() {
        #expect(texts("-\u{0301}x") == ["-\u{0301}x"])
        #expect(texts("- \u{0301}x") == ["- \u{0301}x"])
        #expect(texts("\u{2022}\u{0301} x") == ["\u{2022}\u{0301} x"])
    }

    @Test("a space that carries a combining mark is content, for the split and for a statement alike")
    func markedSpaceIsContent() throws {
        #expect(texts(markedSpace) == [markedSpace])
        #expect(texts("a\n\(markedSpace)\nb") == ["a", markedSpace, "b"])
        #expect(try Statement(text: markedSpace).text == markedSpace)
        #expect(try Statement(text: "\u{200B}\(markedSpace)\u{FEFF}").text == markedSpace)
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

    static let blankTexts: [String] = {
        var values: [String] = []
        values.append(contentsOf: blankStrings)
        return values
    }()

    @Test("a statement of nothing is refused", arguments: blankTexts)
    func empty(text: String) {
        #expect(throws: TailoringModelError.emptyField(.statement)) { try Statement(text: text) }
    }

    static let multiLineTexts: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["a\nb", "a\r\nb", "a\rb", "a\u{2028}b", "a\u{2029}b", "a\u{0085}b", "a\u{000B}b", "a\u{000C}b"])
        values.append(contentsOf: ["- a\n- b", "a\n\nb", "a \n b"])
        return values
    }()

    @Test("text that spans lines is refused, whatever breaks the line", arguments: multiLineTexts)
    func manyLines(text: String) {
        #expect(throws: TailoringModelError.notOneLine(.statement)) { try Statement(text: text) }
    }

    static let paddedTexts: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["\nCut costs", "Cut costs\r\n", "\r\n Cut costs \u{2028}"])
        return values
    }()

    @Test("the same invisible characters are trimmed from a statement built from text", arguments: invisibleCharacters)
    func paddedWithInvisible(padding: String) throws {
        #expect(try Statement(text: "\(padding)Cut costs\(padding)").text == "Cut costs")
        #expect(try Statement(text: "\(padding)- Cut costs").text == "- Cut costs")
    }

    @Test("a line break at either end is trimmed, and does not make a second line", arguments: paddedTexts)
    func breaksAtTheEnds(text: String) throws {
        #expect(try Statement(text: text).text == "Cut costs")
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
