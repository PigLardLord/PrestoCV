import Testing
import TailoringModel

/// The classes of character that hide what a text says, and the ones that look similar but stay allowed.
enum HiddenSamples {
    /// Hidden in every text: control characters that are not line breaks, bidirectional embeddings, overrides and
    /// isolates, and tag characters.
    static let always: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["\u{0000}", "\u{0007}", "\u{001B}", "\u{007F}", "\u{0080}", "\u{009F}"])
        values.append(contentsOf: ["\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}"])
        values.append(contentsOf: ["\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}"])
        values.append(contentsOf: ["\u{E0000}", "\u{E0020}", "\u{E0041}", "\u{E007F}"])
        return values
    }()

    /// Control characters that break a line: hidden in a single-line text, and allowed in a multi-line one only when
    /// they are `\n`, `\r` and tab.
    static let allowedInMultiLine: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["\n", "\r", "\r\n", "\t"])
        return values
    }()

    /// Other controls that break a line: hidden in every text.
    static let otherBreaks: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["\u{0085}", "\u{000B}", "\u{000C}"])
        return values
    }()

    /// Invisible or directional characters that stay allowed: joiners, the zero-width space, the byte order mark, the
    /// word joiner and the left-to-right and right-to-left marks.
    static let allowed: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["\u{200D}", "\u{200C}", "\u{200B}", "\u{FEFF}", "\u{2060}", "\u{200E}", "\u{200F}"])
        values.append(contentsOf: ["\u{2028}", "\u{2029}", "\u{00A0}", "\u{202F}", "\u{2065}", "\u{206A}", "\u{E0080}", "\u{0301}"])
        return values
    }()

    /// The fields whose text may hold line breaks and tabs. A statement is a line of a multi-line text: its line
    /// breaks are refused by `notOneLine`, and a tab is allowed.
    static let multiLine: Set<TailoringModelError.Field> = [.description, .summary, .advert, .statement]

    /// Every field, with the way to build the value that holds it, but for the statements of an experience.
    static let fields: [TextFieldCase] = {
        var cases: [TextFieldCase] = []
        cases.append(contentsOf: SourceEntryTests.personalFields)
        cases.append(contentsOf: SourceEntryTests.entryFields)
        cases.append(contentsOf: SourceEntryTests.educationFields)
        cases.append(contentsOf: SourceExperienceTests.fields)
        cases.append(contentsOf: SourceCVTests.textFields)
        cases.append(contentsOf: TailoredCVTests.experienceFields)
        cases.append(contentsOf: CoverLetterTests.textFields)
        cases.append(contentsOf: ReportAndQuestionTests.reportFields)
        cases.append(contentsOf: OptionalTextTests.optionalFields)
        cases.append(TextFieldCase(.advert) { _ = try Advert(text: $0, language: .english) })
        cases.append(TextFieldCase(.term) { _ = try Question(kind: .unevidencedTerm($0), scope: .skills) })
        cases.append(TextFieldCase(.request) { _ = try Question(kind: .modelRequest($0), scope: .summary) })
        cases.append(TextFieldCase(.statement) { _ = try Statement(text: $0) })
        cases.append(TextFieldCase(.statement) { _ = try Statement(writtenLine: $0) })
        return cases
    }()

    static let singleLineFields: [TextFieldCase] = fields.filter { !multiLine.contains($0.field) }
    static let multiLineFields: [TextFieldCase] = fields.filter { multiLine.contains($0.field) && $0.field != .statement }
    static let allFields: [TextFieldCase] = fields
}

@Suite("ADR 0013 / R8 · characters that hide what a text says: TextRules")
struct TextRulesTests {
    static let hiddenInBothModes: [String] = {
        var values: [String] = HiddenSamples.always
        values.append(contentsOf: HiddenSamples.otherBreaks)
        return values
    }()

    @Test("a control, a bidirectional override or a tag character is hidden, in a single-line and in a multi-line text", arguments: hiddenInBothModes, [false, true])
    func hidden(character: String, multiLine: Bool) {
        #expect(TextRules.hiddenCharacter(in: "a" + character + "b", multiLine: multiLine))
        #expect(TextRules.hiddenCharacter(in: character, multiLine: multiLine))
    }

    @Test("a line break and a tab are hidden in a single-line text, and allowed in a multi-line one", arguments: HiddenSamples.allowedInMultiLine)
    func lineBreaks(character: String) {
        #expect(TextRules.hiddenCharacter(in: "a" + character + "b", multiLine: false))
        #expect(!TextRules.hiddenCharacter(in: "a" + character + "b", multiLine: true))
    }

    @Test("joiners, marks and other invisible characters that are not listed stay allowed", arguments: HiddenSamples.allowed, [false, true])
    func allowed(character: String, multiLine: Bool) {
        #expect(!TextRules.hiddenCharacter(in: "a" + character + "b", multiLine: multiLine))
    }

    static let plainTexts: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["", "plain", "r\u{00E9}sum\u{00E9} \u{2014} 30 %", "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627}"])
        values.append(contentsOf: ["\u{1F469}\u{200D}\u{1F4BB}", "\u{65E5}\u{672C}\u{8A9E}", "e\u{0301}"])
        return values
    }()

    @Test("ordinary text is not hidden", arguments: plainTexts, [false, true])
    func plain(text: String, multiLine: Bool) {
        #expect(!TextRules.hiddenCharacter(in: text, multiLine: multiLine))
    }

    @Test("the right-to-left override that makes 12 read as 21 is hidden")
    func override() {
        #expect(TextRules.hiddenCharacter(in: "Total: \u{202E}12\u{202C}", multiLine: false))
        #expect(TextRules.hiddenCharacter(in: "Total: \u{202E}12\u{202C}", multiLine: true))
    }

    @Test("the edges of each class")
    func edges() {
        #expect(TextRules.hiddenCharacter(in: "\u{2066}", multiLine: true) && TextRules.hiddenCharacter(in: "\u{2069}", multiLine: true))
        #expect(!TextRules.hiddenCharacter(in: "\u{2065}", multiLine: true) && !TextRules.hiddenCharacter(in: "\u{206A}", multiLine: true))
        #expect(TextRules.hiddenCharacter(in: "\u{E0000}", multiLine: true) && TextRules.hiddenCharacter(in: "\u{E007F}", multiLine: true))
        #expect(!TextRules.hiddenCharacter(in: "\u{E0080}", multiLine: true) && !TextRules.hiddenCharacter(in: "\u{DFFFF}", multiLine: true))
    }
}

@Suite("ADR 0013 / R8 · characters that hide what a text says: in every field of the model")
struct HiddenCharacterFieldTests {
    @Test("a hidden character is refused in every text a field accepts, wherever the field is", arguments: HiddenSamples.allFields, HiddenSamples.always)
    func refused(field: TextFieldCase, character: String) {
        #expect(throws: TailoringModelError.hiddenCharacter(field.field)) { try field.build("a" + character + "b") }
    }

    @Test("a tab or a line break is hidden in a single-line field", arguments: HiddenSamples.singleLineFields, HiddenSamples.allowedInMultiLine)
    func singleLineRefusesBreaks(field: TextFieldCase, character: String) {
        #expect(throws: TailoringModelError.hiddenCharacter(field.field)) { try field.build("a" + character + "b") }
    }

    @Test("a tab and a line break are allowed in a multi-line field", arguments: HiddenSamples.multiLineFields, HiddenSamples.allowedInMultiLine)
    func multiLineAllowsBreaks(field: TextFieldCase, character: String) throws {
        try field.build("a" + character + "b")
    }

    @Test("a control that breaks a line otherwise is hidden in every field but a statement, which refuses it as a break", arguments: HiddenSamples.otherBreaks)
    func otherBreaksRefused(character: String) {
        for field in HiddenSamples.singleLineFields + HiddenSamples.multiLineFields {
            #expect(throws: TailoringModelError.hiddenCharacter(field.field)) { try field.build("a" + character + "b") }
        }
        #expect(throws: TailoringModelError.notOneLine(.statement)) { try Statement(text: "a" + character + "b") }
        #expect(throws: TailoringModelError.notOneLine(.statement)) { try Statement(writtenLine: "a" + character + "b") }
    }

    @Test("joiners and the other unlisted invisible characters are allowed in every field", arguments: HiddenSamples.allFields, HiddenSamples.allowed)
    func allowed(field: TextFieldCase, character: String) throws {
        guard !(field.field == .statement && (character == "\u{2028}" || character == "\u{2029}")) else { return }
        try field.build("a" + character + "b")
    }

    @Test("the override that makes 12 read as 21 is refused wherever a text is written, and trimmed away at the edge of a statement")
    func override() throws {
        for field in HiddenSamples.allFields {
            #expect(throws: TailoringModelError.hiddenCharacter(field.field)) { try field.build("Total: \u{202E}12\u{202C}") }
        }
        #expect(try Statement(text: "\u{202E}12\u{202C}").text == "12")
    }

    @Test("a statement of a split that holds a hidden character cannot join an experience")
    func statementsOfAnExperience() throws {
        let statements = Statement.split("fine\na\u{202E}b")
        #expect(statements.count == 2)
        #expect(throws: TailoringModelError.hiddenCharacter(.statement)) { try SourceExperience(role: "r", company: "c", statements: statements) }
        let line = Statement.split("a\u{0007}b")[0]
        #expect(throws: TailoringModelError.hiddenCharacter(.statement)) { try TailoredLine(statement: line, sources: []) }
    }

    @Test("a description is checked for hidden characters before it is split")
    func descriptionBeforeSplit() {
        let manyLines = (0..<300).map { _ in "line" }.joined(separator: "\n")
        #expect(throws: TailoringModelError.tooMany(.statements)) { try SourceExperience(role: "r", company: "c", description: manyLines) }
        #expect(throws: TailoringModelError.hiddenCharacter(.description)) { try SourceExperience(role: "r", company: "c", description: manyLines + "\u{202E}") }
    }

    @Test("a text that is blank is empty, whatever its controls, and the size is checked first")
    func blankBeforeHidden() {
        #expect(throws: TailoringModelError.emptyField(.fullName)) { try SourcePersonalDetails(fullName: " \t\n ") }
        #expect(throws: TailoringModelError.tooLarge(.fullName)) { try SourcePersonalDetails(fullName: String(repeating: "\u{0007}", count: 10_001)) }
    }
}
