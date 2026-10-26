import Testing

@Suite("Swift Tokens Tests")
struct SwiftTokensTests {

    private static func read(_ source: String) -> [SwiftToken] {
        guard case .success(let tokens) = SwiftLexer.tokens(of: source) else { return [] }
        return tokens
    }

    private static func failure(_ source: String) -> SwiftLexer.Failure? {
        if case .failure(let failure) = SwiftLexer.tokens(of: source) { return failure }
        return nil
    }

    @Test("The tokens of a call are its words, numbers, strings and marks, with their lines")
    func tokensOfACall() {
        let tokens = Self.read("let p = Package(\n    name: \"P\", v: 26.5\n)")

        #expect(tokens.map(\.text) == ["let", "p", "=", "Package", "(", "name", ":", "", ",", "v", ":", "26.5", ")"])
        #expect(tokens.map(\.line) == [1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 3])
        #expect(tokens[7].kind == .string && tokens[7].value == "P")
    }

    @Test("A string that holds an escape or several lines has no plain value")
    func stringsWithoutAPlainValue() {
        for source in ["\"a\\nb\"", "\"a\\u{2E}b\"", "\"a\\\\b\"", "\"\"\"\nabc\n\"\"\"", "#\"a\\#nb\"#"] {
            let tokens = Self.read(source)
            #expect(tokens.count == 1 && tokens[0].kind == .string && tokens[0].value == nil, "\(source): \(tokens)")
        }
        #expect(Self.read("#\"a\\(b)\"\"#").first?.value == "a\\(b)\"")
    }

    @Test("A string with an interpolation is a failure, with the line of the interpolation: it is code, and it is not read", arguments: [
        ("\"a\\(b)c\"", 1), ("\"a\\(\"b)\")c\"", 1), ("\"a\\(b\\(c))\"", 1), ("a\n\"x \\(b)\"", 2),
        ("#\"a\\#(b)\"#", 1), ("##\"a\\##(b)\"##", 1), ("\"\"\"\nabc\n\\(b)\n\"\"\"", 3), ("#\"\"\"\nabc\n\\#(b)\n\"\"\"#", 3),
        ("\"\"\"\n\\(\n b\n)\n\"\"\"", 2),
    ])
    func interpolationIsAFailure(source: String, line: Int) {
        let failure = Self.failure(source)

        #expect(failure?.line == line, "\(source): \(String(describing: failure))")
        #expect(failure?.what.contains("interpolation") == true, "\(source): \(String(describing: failure))")
    }

    @Test("A backslash that starts no interpolation is an escape, and the string is read", arguments: [
        "#\"a\\(b)\"#", "##\"a\\#(b)\"##", "\"a\\\\(b)\"", "#\"a\\\\(b)\"#", "\"a\\\\\"",
    ])
    func backslashWithoutInterpolationIsNoFailure(source: String) {
        let tokens = Self.read(source)

        #expect(Self.failure(source) == nil, "\(source)")
        #expect(tokens.count == 1 && tokens[0].kind == .string, "\(source): \(tokens)")
    }

    @Test("A slash outside a string and a comment is a failure, with its line: it could start a regular expression", arguments: [
        ("a / b", 1), ("a/b", 1), ("let r = /\\//", 1), ("let r = /a\\/*b/", 1), ("a\nb /= 2", 2), ("x = /\"/", 1), ("a +/ b", 1),
    ])
    func slashIsAFailure(source: String, line: Int) {
        let failure = Self.failure(source)

        #expect(failure?.line == line, "\(source): \(String(describing: failure))")
        #expect(failure?.what.contains("regular expression") == true, "\(source): \(String(describing: failure))")
    }

    @Test("A slash in a string, in a comment, or as the start of one is no failure")
    func slashInAStringOrAComment() {
        let source = "a \"b/c\" // d / e\n/* f / g */ #\"h/i\"# j"

        #expect(Self.read(source).map(\.text) == ["a", "", "", "j"])
    }

    @Test("A line comment ends at a carriage return as it does at a line feed, and each counts as a line")
    func lineCommentEndsAtACarriageReturn() {
        #expect(Self.read("a // b\rc").map(\.text) == ["a", "c"])
        #expect(Self.read("a // b\r\nc").map(\.text) == ["a", "c"])
        #expect(Self.read("a // b\nc").map(\.text) == ["a", "c"])
        #expect(Self.read("a\rb\rc").map(\.line) == [1, 2, 3])
        #expect(Self.read("a\r\nb\r\n\r\nc").map(\.line) == [1, 2, 4])
        #expect(Self.read("a\nb\rc\r\nd").map(\.line) == [1, 2, 3, 4])
        #expect(Self.read("a /* b\rc */ d").map(\.line) == [1, 2])
    }

    @Test("A line comment that holds a line separator other than the ones above is a failure: a compiler may end the comment there", arguments: [
        "a // b\u{2028}c", "a // b\u{2029}c", "a // b\u{0085}c", "a\nb // c\u{2028}\nd",
    ])
    func commentWithALineSeparatorIsAFailure(source: String) {
        let failure = Self.failure(source)

        #expect(failure != nil && failure?.what.contains("comment") == true, "\(source.debugDescription): \(String(describing: failure))")
    }

    @Test("The same separators in a block comment or in a string are no failure: nothing ends there")
    func lineSeparatorsInABlockCommentOrAString() {
        #expect(Self.read("a /* b\u{2028}c */ d \"e\u{2028}f\"").map(\.text) == ["a", "d", ""])
    }

    @Test("A carriage return ends a string on one line, and a quoted name: neither is closed", arguments: [
        ("\"abc\rdef\"", 1), ("a\r\"abc\rdef\"", 2), ("`abc\rdef`", 1),
    ])
    func carriageReturnEndsAStringOnOneLine(source: String, line: Int) {
        #expect(Self.failure(source)?.line == line, "\(source.debugDescription)")
    }

    @Test("A comment, nested or over several lines, is dropped and its lines are counted")
    func commentsAreDropped() {
        let tokens = Self.read("a /* one /* two */\n still */ b // c\n d")

        #expect(tokens.map(\.text) == ["a", "b", "d"])
        #expect(tokens.map(\.line) == [1, 2, 3])
    }

    @Test("A directive and a quoted name are read as words")
    func directivesAndQuotedNames() {
        #expect(Self.read("#if os(Linux)").map(\.text) == ["#", "if", "os", "(", "Linux", ")"])
        #expect(Self.read("`Package`").map(\.text) == ["Package"])
    }

    @Test("A source that is not closed is a failure with the line it started on", arguments: [
        ("a\n\"never", 2), ("a /* never", 1), ("\"\"\"\nnever", 1), ("a\n\"x\\(never", 2), ("`never", 1), ("a\nb #/never/#", 2),
    ])
    func unclosedSourceIsAFailure(source: String, line: Int) {
        #expect(Self.failure(source)?.line == line, "\(source)")
    }
}
