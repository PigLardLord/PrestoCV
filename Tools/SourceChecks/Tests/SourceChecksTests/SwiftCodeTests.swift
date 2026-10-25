import Testing
import Foundation

/// A check that looks for a word in code ignores the comments, and finds the word wherever the code puts it.
@Suite("Swift code - the comments out of a source, and no code lost with them")
struct SwiftCodeTests {

    // MARK: - Comments

    /// A small source, and the lines (from 0) of the code that hold the word `hidden`
    struct Fixture: CustomTestStringConvertible, Sendable {
        let name: String
        let source: String
        let lines: [Int]
        var testDescription: String { name }
    }

    static let fixtures = [
        Fixture(name: "a line comment", source: "// hidden", lines: []),
        Fixture(name: "a doc comment", source: "/// hidden", lines: []),
        Fixture(name: "a comment after code", source: "let a = 1 // hidden", lines: []),
        Fixture(name: "code before a comment", source: "let hidden = 1 // a", lines: [0]),
        Fixture(name: "a block comment", source: "/* hidden */ let a = 1", lines: []),
        Fixture(name: "code after a block comment on its line", source: "/* a */ hidden()", lines: [0]),
        Fixture(name: "code between two block comments", source: "/* a */ hidden() /* b */", lines: [0]),
        Fixture(name: "a block comment of several lines", source: "/*\n hidden\n*/\nlet a = 1", lines: []),
        Fixture(name: "code after a block comment of several lines", source: "/*\n a\n*/ hidden()", lines: [2]),
        Fixture(name: "a block comment inside a block comment", source: "/* a /* b */ hidden */", lines: []),
        Fixture(name: "code after a block comment inside a block comment", source: "/* a /* b */ c */ hidden()", lines: [0]),
        Fixture(name: "a line comment mark in a block comment", source: "/* // */ hidden()", lines: [0]),
        Fixture(name: "a block comment mark in a line comment", source: "// /*\nhidden()", lines: [1]),
        Fixture(name: "a word in a comment after a string", source: #"let s = "a" // hidden"#, lines: []),
        Fixture(name: "a line break of Windows", source: "// hidden\r\nhidden()", lines: [1]),
    ]

    @Test("A word in a comment is not in the code, and a word after a comment is", arguments: fixtures)
    func commentsAreIgnored(fixture: Fixture) {
        let hidden = try! NSRegularExpression(pattern: #"\bhidden\b"#)

        #expect(SwiftCode(fixture.source).lines(matching: hidden) == fixture.lines)
    }

    // MARK: - Strings

    static let strings = [
        Fixture(name: "a line comment mark in a string", source: #"let url = "http://example.com"; hidden()"#, lines: [0]),
        Fixture(name: "a block comment mark in a string", source: #"let s = "/*"; hidden()"#, lines: [0]),
        Fixture(name: "a line comment mark after an escaped quote", source: #"let s = "a \" // b"; hidden()"#, lines: [0]),
        Fixture(name: "a word in a string", source: #"let key = "hidden""#, lines: [0]),
        Fixture(name: "a word in an interpolation", source: #"let s = "\(hidden)""#, lines: [0]),
        Fixture(name: "a word in a comment in an interpolation", source: #"let s = "\(a /* hidden */)""#, lines: []),
        Fixture(name: "a string in an interpolation", source: #"let s = "\(a == "//" ? hidden : b)""#, lines: [0]),
        Fixture(name: "a line comment mark in a multi-line string", source: "let s = \"\"\"\n a // b\n \"\"\"\nhidden()", lines: [3]),
        Fixture(name: "a line comment mark in a raw string", source: ##"let s = #"a "quote" // b"#; hidden()"##, lines: [0]),
        Fixture(name: "a line comment mark in a raw string of two hashes", source: ###"let s = ##"a "# // b"##; hidden()"###, lines: [0]),
        Fixture(name: "a backslash in a raw string", source: ##"let s = #"a \"#; hidden()"##, lines: [0]),
    ]

    @Test("A string is not a comment, and what is in it is not lost", arguments: strings)
    func stringsAreNotComments(fixture: Fixture) {
        let hidden = try! NSRegularExpression(pattern: #"\bhidden\b"#)

        #expect(SwiftCode(fixture.source).lines(matching: hidden) == fixture.lines)
    }

    @Test("A line keeps its number and every character its column", arguments: fixtures + strings)
    func positionsAreKept(fixture: Fixture) {
        let source = SwiftCode.lines(of: fixture.source).map { $0.unicodeScalars.count }
        let code = SwiftCode(fixture.source)

        #expect(code.code.map { $0.unicodeScalars.count } == source)
        #expect(code.skeleton.map { $0.unicodeScalars.count } == source)
    }

    // MARK: - The skeleton and the members

    private static let declarations = """
        struct S {
            let stored = 1
            private let braced = "}"
            var one: Int { stored }
            private func block(a: Int) -> Int {
                let text = "{ \\(a) }"
                return a // }
            }
            /* } */
            init(a: Int) {
                if a > 0 { stored = a }
            }
        }
        """

    @Test("A member runs from its header to the line that closes its braces", arguments: [
        ("let stored", 1..<2), ("let braced", 2..<3), ("var one", 3..<4), ("func block", 4..<8), ("init(a: ", 9..<12),
    ] as [(String, Range<Int>)])
    func memberRange(header: String, lines: Range<Int>) {
        #expect(SwiftCode(Self.declarations).member(startingWith: header) == lines)
    }

    @Test("A member that is not there is not found")
    func missingMember() {
        #expect(SwiftCode(Self.declarations).member(startingWith: "func missing") == nil)
    }

    private static let nested = """
        struct A {
            var value = 1
            struct B {
                var value: Int {
                    1
                }
            }
        }
        """

    @Test("A member can be looked for within the lines of another, where a name of the same kind is not the first")
    func memberWithin() throws {
        let code = SwiftCode(Self.nested)
        let inner = try #require(code.member(startingWith: "struct B"))

        #expect(code.member(startingWith: "var value") == 1..<2)
        #expect(code.member(startingWith: "var value", within: inner) == 3..<6)
        #expect(code.member(startingWith: "var value", within: 4..<5) == nil)
    }

    // MARK: - A pattern over several lines

    @Test("A pattern that runs over a line break is found on the line where it starts", arguments: [
        ("call(\n    of: 1)\nother()", [0]),
        ("a\nb\ncall(\n    of: 1)", [2]),
        ("a\r\ncall(\r\n    of: 1)", [1]),
        ("call(of: 1)\ncall(\n of: 2)\ncall(1)", [0, 1]),
        ("// call(\n of: 1)", []),
        ("call( // of\n of: 1)", [0]),
    ] as [(String, [Int])])
    func patternOverLines(source: String, lines: [Int]) throws {
        let call = try NSRegularExpression(pattern: #"\bcall\s*\(\s*of\b"#)

        #expect(SwiftCode(source).lines(matching: call) == lines)
    }

    @Test("The skeleton holds the braces of the code, and none of a string or a comment")
    func skeletonBraces() {
        let skeleton = SwiftCode(Self.declarations).skeleton.joined(separator: "\n")

        #expect(skeleton.filter { $0 == "{" }.count == skeleton.filter { $0 == "}" }.count)
        #expect(skeleton.filter { $0 == "{" }.count == 5)
        #expect(skeleton.contains("return a"), "The code stays")
        #expect(!skeleton.contains("text = \"{"), "The text of a string is blanked")
    }
}
