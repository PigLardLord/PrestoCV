import Testing
import TailoringModel

/// The classes of character that hide what a text says, and the ones that look similar but stay allowed.
enum HiddenSamples {
    /// Hidden in every text: control characters that are not line breaks, bidirectional embeddings, overrides and
    /// isolates, the bidirectional marks, and tag characters.
    static let always: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["\u{0000}", "\u{0007}", "\u{001B}", "\u{007F}", "\u{0080}", "\u{009F}"])
        values.append(contentsOf: ["\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}"])
        values.append(contentsOf: ["\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}"])
        values.append(contentsOf: ["\u{200E}", "\u{200F}", "\u{061C}"])
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

    /// Every character that breaks a line: in a one-line text each is `notOneLine`. In a multi-line one the separators
    /// U+2028 and U+2029 are breaks the text keeps, and NEL, VT and FF are hidden.
    static let breaks: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["\n", "\r", "\r\n", "\u{000B}", "\u{000C}", "\u{0085}", "\u{2028}", "\u{2029}"])
        return values
    }()

    /// The separators: breaks that a multi-line text keeps, and that are not hidden.
    static let separators: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["\u{2028}", "\u{2029}"])
        return values
    }()

    /// Other controls that break a line: hidden in every multi-line text.
    static let otherBreaks: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["\u{0085}", "\u{000B}", "\u{000C}"])
        return values
    }()

    /// Invisible characters that stay allowed: joiners, the zero-width space, the byte order mark and the word joiner.
    static let allowed: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["\u{200D}", "\u{200C}", "\u{200B}", "\u{FEFF}", "\u{2060}"])
        values.append(contentsOf: ["\u{00A0}", "\u{202F}", "\u{2065}", "\u{206A}", "\u{E0080}", "\u{0301}", "\u{200D}\u{1F4BB}"])
        return values
    }()

    /// The fields whose text may hold line breaks and tabs: a description, the summary, the advert and the letter note.
    /// A statement is a line of a multi-line text: its line breaks are refused by `notOneLine`, and a tab is allowed.
    static let multiLine: Set<TailoringModelError.Field> = [.description, .summary, .advert, .statement, .note]

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

    static let figuresWithMarks: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["Revenue: 1040 \u{200F}\u{2192} 5308", "Revenue: \u{200F}1040 \u{2192} 5308", "Revenue: 1040 \u{200E}\u{2192} \u{200F}5308"])
        values.append(contentsOf: ["Churn \u{061C}-5%", "Churn -\u{061C}5%", "Churn -5\u{200F}%", "Growth +\u{200F}12 %"])
        return values
    }()

    @Test("a right-to-left or an Arabic letter mark before figures is refused: it reverses how they display", arguments: figuresWithMarks, [false, true])
    func marksBeforeFigures(text: String, multiLine: Bool) {
        #expect(TextRules.hiddenCharacter(in: text, multiLine: multiLine))
    }

    @Test("the same figures without a mark are not hidden", arguments: [false, true])
    func figuresWithoutMarks(multiLine: Bool) {
        #expect(!TextRules.hiddenCharacter(in: "Revenue: 1040 \u{2192} 5308, churn -5%, growth +12 %", multiLine: multiLine))
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

@Suite("ADR 0013 / R8 · characters that hide what a text says: removing them at intake")
struct RemovingHiddenTests {
    static let mixedTexts: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["", "plain", "Revenue: \u{200F}1040 \u{2192} 5308\u{202E}x\u{E0041}", "a\u{0007}b\u{FEFF}c\u{200D}d\u{061C}-5%"])
        values.append(contentsOf: ["\u{0000}\u{001B}\u{007F}\u{0080}\u{009F}", HiddenSamples.always.joined(), HiddenSamples.always.joined(separator: "x")])
        values.append(contentsOf: [HiddenSamples.always.joined(separator: "\u{200D}") + HiddenSamples.allowed.joined()])
        values.append(contentsOf: ["a\tb\r\nc\u{2028}d\u{0085}e\u{000B}f\u{000C}g\nh\ri", "\u{202E}12\u{202C}\n\u{2066}34\u{2069}\t"])
        return values
    }()

    private func filtered(_ text: String, multiLine: Bool) -> String {
        var kept = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            let isBreak = Character(scalar).isNewline
            if !TextRules.hiddenCharacter(in: String(scalar), multiLine: multiLine) {
                kept.append(scalar)
            } else if multiLine && isBreak {
                kept.append("\n")
            } else if !multiLine && scalar == "\t" {
                kept.append(" ")
            } else if !multiLine && isBreak {
                kept.append(scalar)
            }
        }
        return String(kept)
    }

    @Test("removing takes out what the rule refuses, but a break-like control becomes a line feed, a one-line tab a space, and a one-line break stays", arguments: mixedTexts, [false, true])
    func removesExactlyWhatIsRefused(text: String, multiLine: Bool) {
        #expect(TextRules.removingHidden(from: text, multiLine: multiLine) == filtered(text, multiLine: multiLine))
    }

    @Test("a text with its hidden characters removed is clean", arguments: mixedTexts)
    func removedThenChecked(text: String) {
        let multiLine = TextRules.removingHidden(from: text, multiLine: true)
        #expect(!TextRules.hiddenCharacter(in: multiLine, multiLine: true))
        let oneLine = TextRules.removingHidden(from: text, multiLine: false)
        let withoutBreaks = String(String.UnicodeScalarView(oneLine.unicodeScalars.filter { !Character($0).isNewline }))
        #expect(!TextRules.hiddenCharacter(in: withoutBreaks, multiLine: false))
    }

    @Test("a text with no break in it is clean once its hidden characters are removed, in either mode", arguments: HiddenSamples.always, [false, true])
    func removedThenCheckedWithoutBreaks(character: String, multiLine: Bool) {
        let removed = TextRules.removingHidden(from: "a\(character)b\(character)", multiLine: multiLine)
        #expect(removed == "ab")
        #expect(!TextRules.hiddenCharacter(in: removed, multiLine: multiLine))
    }

    @Test("removing twice is removing once", arguments: mixedTexts, [false, true])
    func idempotent(text: String, multiLine: Bool) {
        let once = TextRules.removingHidden(from: text, multiLine: multiLine)
        #expect(TextRules.removingHidden(from: once, multiLine: multiLine) == once)
    }

    @Test("it removes each class", arguments: HiddenSamples.always, [false, true])
    func eachClass(character: String, multiLine: Bool) {
        #expect(TextRules.removingHidden(from: "a" + character + "b", multiLine: multiLine) == "ab")
        #expect(TextRules.removingHidden(from: character, multiLine: multiLine).isEmpty)
    }

    @Test("it keeps the joiners and the other invisible characters that are allowed", arguments: HiddenSamples.allowed, [false, true])
    func keepsAllowed(character: String, multiLine: Bool) {
        #expect(TextRules.removingHidden(from: "a" + character + "b", multiLine: multiLine) == "a" + character + "b")
    }

    @Test("it keeps the emoji sequence that a joiner makes")
    func keepsJoinedEmoji() {
        let text = "\u{1F469}\u{200D}\u{1F4BB} and a\u{200C}b"
        #expect(TextRules.removingHidden(from: text, multiLine: false) == text)
        #expect(TextRules.removingHidden(from: text, multiLine: true) == text)
    }

    @Test("in a multi-line text it keeps line feed, carriage return, tab and the separators", arguments: HiddenSamples.allowedInMultiLine, HiddenSamples.separators)
    func keepsMultiLineBreaks(allowed: String, separator: String) {
        let text = "a" + allowed + "b" + separator + "c"
        #expect(TextRules.removingHidden(from: text, multiLine: true) == text)
    }

    @Test("in a multi-line text it turns NEL, vertical tab and form feed into a line feed, which never joins two words", arguments: HiddenSamples.otherBreaks)
    func turnsOtherBreaksIntoLineFeeds(character: String) {
        #expect(TextRules.removingHidden(from: "a" + character + "b", multiLine: true) == "a\nb")
        #expect(TextRules.removingHidden(from: "one." + character + "Two " + character + character + "three", multiLine: true) == "one.\nTwo \n\nthree")
    }

    @Test("in a one-line text it leaves every break for the caller to decide", arguments: HiddenSamples.breaks)
    func leavesBreaksInOneLine(character: String) {
        let text = "a" + character + "b"
        #expect(TextRules.removingHidden(from: text, multiLine: false) == text)
    }

    @Test("in a one-line text it turns a tab into a space, which never joins two words")
    func turnsTabIntoSpaceInOneLine() {
        #expect(TextRules.removingHidden(from: "a\tb", multiLine: false) == "a b")
        #expect(TextRules.removingHidden(from: "a\t\tb\tc\u{202E}", multiLine: false) == "a  b c")
        #expect(TextRules.removingHidden(from: "a\tb\nc\u{202E}", multiLine: false) == "a b\nc")
    }

    @Test("a tab in a multi-line text stays a tab")
    func keepsTabInMultiLine() {
        #expect(TextRules.removingHidden(from: "a\tb", multiLine: true) == "a\tb")
    }

    @Test("a salary written with a tab is cleaned to a space, and the model accepts it")
    func salaryWithATab() throws {
        let salary = TextRules.removingHidden(from: "55k\tEUR", field: .salaryExpectation)
        #expect(salary == "55k EUR")
        #expect(try LetterDefaults(salaryExpectation: salary).salaryExpectation == "55k EUR")
    }

    @Test("an advert with a vertical tab, NEL or a form feed is cleaned to line feeds, and the model accepts it")
    func advertWithBreakControls() throws {
        let requirements = TextRules.removingHidden(from: "Requirements:\u{000B}Swift\u{0085}5 years", field: .advert)
        #expect(requirements == "Requirements:\nSwift\n5 years")
        #expect(try Advert(text: requirements, language: .english).text == requirements)
        let recruiter = TextRules.removingHidden(from: "Recruiter.\u{000C}Apply.", field: .advert)
        #expect(recruiter == "Recruiter.\nApply.")
        #expect(try Advert(text: recruiter, language: .english).text == recruiter)
        #expect(throws: TailoringModelError.hiddenCharacter(.advert)) { try Advert(text: "Recruiter.\u{000C}Apply.", language: .english) }
    }

    @Test("a description written with break controls keeps its lines once cleaned")
    func descriptionWithBreakControls() throws {
        let description = TextRules.removingHidden(from: "- Built the API\u{000B}- Cut costs\u{0085}- Trained juniors\u{000C}", field: .description)
        #expect(try SourceExperience(role: "r", company: "c", description: description).statements.map(\.text) == ["Built the API", "Cut costs", "Trained juniors"])
    }

    @Test("what is left after removing is accepted by the model, or refused only for its breaks")
    func acceptedAfterRemoving() throws {
        let skill = TextRules.removingHidden(from: "Swift\u{202E}\u{200F}\u{0007}", field: .skillName)
        #expect(try SourceSkill(name: skill).name == "Swift")
        let summary = TextRules.removingHidden(from: "Line one\u{0085}\nLine\u{061C} two", field: .summary)
        #expect(try SourceCV(language: .english, personal: Sample.personal(), summary: summary).summary == "Line one\n\nLine two")
        let role = TextRules.removingHidden(from: "Engineer\u{2028}Manager\u{202E}", field: .role)
        #expect(role == "Engineer\u{2028}Manager")
        #expect(throws: TailoringModelError.notOneLine(.role)) { try SourceExperience(role: role, company: "Acme") }
    }
}

@Suite("ADR 0013 / R8 · characters that hide what a text says: by field")
struct TextRulesByFieldTests {
    static let multiLineFieldSet: Set<TailoringModelError.Field> = [.description, .summary, .advert, .note, .statement]

    @Test("the multi-line fields are the ones the model documents, and no other")
    func classification() {
        #expect(Set(TailoringModelError.Field.allCases.filter(\.isMultiLine)) == Self.multiLineFieldSet)
        #expect(TailoringModelError.Field.allCases.filter { !$0.isMultiLine }.count == TailoringModelError.Field.allCases.count - 5)
    }

    @Test("the model reports every break in a one-line field as not one line, while the rule counts only the controls as hidden", arguments: HiddenSamples.breaks)
    func breaksInOneLineField(character: String) {
        let controls: Set<String> = ["\n", "\r", "\r\n", "\u{000B}", "\u{000C}", "\u{0085}"]
        let text = "a" + character + "b"
        #expect(TextRules.hiddenCharacter(in: text, field: .role) == controls.contains(character))
        let hasBreak = text.contains(where: \.isNewline)
        #expect(hasBreak)
        #expect(throws: TailoringModelError.notOneLine(.role)) { try SourceExperience(role: text, company: "Acme") }
    }

    @Test("the field overloads agree with the flags", arguments: TailoringModelError.Field.allCases)
    func overloads(field: TailoringModelError.Field) {
        let text = "a\tb\u{202E}c\nd"
        #expect(TextRules.hiddenCharacter(in: text, field: field) == TextRules.hiddenCharacter(in: text, multiLine: field.isMultiLine))
        #expect(TextRules.removingHidden(from: text, field: field) == TextRules.removingHidden(from: text, multiLine: field.isMultiLine))
        #expect(TextRules.hiddenCharacter(in: "a\tb", field: field) == !field.isMultiLine)
        #expect(TextRules.removingHidden(from: "a\tb\u{202E}c", field: field) == (field.isMultiLine ? "a\tbc" : "a bc"))
    }

    @Test("every field the model checks is classified as the model checks it", arguments: HiddenSamples.allFields)
    func agreesWithTheModel(field: TextFieldCase) {
        // A tab is hidden in a one-line field and allowed in a multi-line one: the overload says what the model does.
        let classified = TextRules.hiddenCharacter(in: "a\tb", field: field.field)
        let refused: Bool = {
            do { try field.build("a\tb"); return false } catch { return true }
        }()
        #expect(classified == refused)
    }
}

@Suite("ADR 0013 / R8 · characters that hide what a text says: in every field of the model")
struct HiddenCharacterFieldTests {
    @Test("a hidden character is refused in every text a field accepts, wherever the field is", arguments: HiddenSamples.allFields, HiddenSamples.always)
    func refused(field: TextFieldCase, character: String) {
        #expect(throws: TailoringModelError.hiddenCharacter(field.field)) { try field.build("a" + character + "b") }
    }

    @Test("a line break of any kind in a one-line field is not one line", arguments: HiddenSamples.singleLineFields, HiddenSamples.breaks)
    func singleLineRefusesBreaks(field: TextFieldCase, character: String) {
        #expect(throws: TailoringModelError.notOneLine(field.field)) { try field.build("a" + character + "b") }
    }

    @Test("a tab is hidden in a one-line field", arguments: HiddenSamples.singleLineFields)
    func singleLineRefusesTab(field: TextFieldCase) {
        #expect(throws: TailoringModelError.hiddenCharacter(field.field)) { try field.build("a\tb") }
    }

    @Test("a role of two lines separated by U+2028 is refused")
    func roleWithSeparator() {
        #expect(throws: TailoringModelError.notOneLine(.role)) { try SourceExperience(role: "Engineer\u{2028}Manager", company: "Acme") }
        #expect(throws: TailoringModelError.notOneLine(.role)) { try SourceExperience(role: "Engineer\u{2029}Manager", company: "Acme") }
        #expect(throws: TailoringModelError.notOneLine(.fullName)) { try SourcePersonalDetails(fullName: "Ada\u{2028}Lovelace") }
    }

    @Test("a tab and a line break are allowed in a multi-line field", arguments: HiddenSamples.multiLineFields, HiddenSamples.allowedInMultiLine)
    func multiLineAllowsBreaks(field: TextFieldCase, character: String) throws {
        try field.build("a" + character + "b")
    }

    @Test("a tab, a line feed and the separators are allowed in a multi-line field, apart from a statement", arguments: HiddenSamples.multiLineFields, HiddenSamples.separators)
    func multiLineAllowsSeparators(field: TextFieldCase, character: String) throws {
        try field.build("a" + character + "b")
    }

    @Test("NEL, vertical tab and form feed are hidden in a multi-line field, and a statement refuses them as breaks", arguments: HiddenSamples.otherBreaks)
    func otherBreaksRefused(character: String) {
        for field in HiddenSamples.multiLineFields {
            #expect(throws: TailoringModelError.hiddenCharacter(field.field)) { try field.build("a" + character + "b") }
        }
        #expect(throws: TailoringModelError.notOneLine(.statement)) { try Statement(text: "a" + character + "b") }
        #expect(throws: TailoringModelError.notOneLine(.statement)) { try Statement(writtenLine: "a" + character + "b") }
    }

    @Test("joiners and the other unlisted invisible characters are allowed in every field", arguments: HiddenSamples.allFields, HiddenSamples.allowed)
    func allowed(field: TextFieldCase, character: String) throws {
        try field.build("a" + character + "b")
    }

    @Test("the override that makes 12 read as 21 is refused wherever a text is written, and trimmed away at the edge of a statement")
    func override() throws {
        for field in HiddenSamples.allFields {
            #expect(throws: TailoringModelError.hiddenCharacter(field.field)) { try field.build("Total: \u{202E}12\u{202C}") }
        }
        #expect(try Statement(text: "\u{202E}12\u{202C}").text == "12")
    }

    @Test("a right-to-left mark before figures is refused wherever a text is written", arguments: HiddenSamples.allFields)
    func marksBeforeFigures(field: TextFieldCase) {
        #expect(throws: TailoringModelError.hiddenCharacter(field.field)) { try field.build("Revenue: 1040 \u{200F}\u{2192} 5308") }
        #expect(throws: TailoringModelError.hiddenCharacter(field.field)) { try field.build("Churn \u{061C}-5%") }
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
