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

    @Test("A string that holds an escape, an interpolation or several lines has no plain value")
    func stringsWithoutAPlainValue() {
        for source in ["\"a\\nb\"", "\"a\\(b)c\"", "\"\"\"\nabc\n\"\"\"", "#\"a\\#(b)\"#"] {
            let tokens = Self.read(source)
            #expect(tokens.count == 1 && tokens[0].kind == .string && tokens[0].value == nil, "\(source): \(tokens)")
        }
        #expect(Self.read("#\"a\\(b)\"\"#").first?.value == "a\\(b)\"")
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
