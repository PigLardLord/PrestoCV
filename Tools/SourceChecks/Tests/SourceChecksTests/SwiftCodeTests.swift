import Testing
import Foundation

/// The checks that look for a word in code read it through `SwiftCode`: it must show no comment, and lose no code to one.
/// A plain comment and a plain string are pinned by the fixtures of the checks (`PDFReadBackTests`, `ButtonPressTests`).
@Suite("Swift code - the comments out of a source, and no code lost with them")
struct SwiftCodeTests {

    // MARK: - Comments and strings

    /// A name, a small source, and the lines (from 0) of the code that hold the word `hidden`
    static let fixtures: [(String, String, [Int])] = [
        ("code before a line comment", "let hidden = 1 // a", [0]),
        ("code after a block comment of several lines", "/*\n a\n*/ hidden()", [2]),
        ("a block comment inside a block comment", "/* a /* b */ hidden */", []),
        ("code after a block comment inside a block comment", "/* a /* b */ c */ hidden()", [0]),
        ("a line comment mark in a block comment", "/* // */ hidden()", [0]),
        ("a block comment mark in a line comment", "// /*\nhidden()", [1]),
        ("a line comment ended by a carriage return", "// hidden\rhidden()", [1]),
        ("a block comment mark in a string", #"let s = "/*"; hidden()"#, [0]),
        ("a line comment mark after an escaped quote", #"let s = "a \" // b"; hidden()"#, [0]),
        ("a word in an interpolation", #"let s = "\(hidden)""#, [0]),
        ("a string in an interpolation", #"let s = "\(a == "//" ? hidden : b)""#, [0]),
        ("a line comment after a quote in a multi-line string", "let s = \"\"\"\n a \" b\n // hidden\n \"\"\"", [2]),
        ("a line comment mark in a raw string of two hashes", ###"let s = ##"a "# // b"##; hidden()"###, [0]),
        ("a backslash in a raw string", ##"let s = #"a \"# // hidden"##, []),
    ]

    @Test("A word in a comment is not in the code, and a word after a comment or in a string is", arguments: fixtures)
    func hiddenWords(name: String, source: String, lines: [Int]) throws {
        let hidden = try NSRegularExpression(pattern: #"\bhidden\b"#)

        #expect(SwiftCode(source).lines(matching: hidden) == lines, "\(name)")
    }

    // MARK: - The two views and the members

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

    @Test("The skeleton blanks the text of a string and the marks of its interpolation, and keeps the code and the columns")
    func skeletonKeepsTheCode() {
        #expect(SwiftCode(#"let s = "a(\(f(b)))""#).skeleton == [#"let s = "    f(b)  ""#])
    }

    @Test("A member runs from its header to the line that closes its braces, whatever a string or a comment holds", arguments: [
        ("let braced", 2..<3), ("func block", 4..<8), ("init(a: ", 9..<12),
    ] as [(String, Range<Int>)])
    func memberRange(header: String, lines: Range<Int>) {
        #expect(SwiftCode(Self.declarations).member(startingWith: header) == lines)
    }

    @Test("A member can be looked for within the lines of another, where a name of the same kind is not the first")
    func memberWithin() throws {
        let code = SwiftCode("struct A {\n    var value = 1\n    struct B {\n        var value: Int {\n            1\n        }\n    }\n}")
        let inner = try #require(code.member(startingWith: "struct B"))

        #expect(code.member(startingWith: "var value") == 1..<2)
        #expect(code.member(startingWith: "var value", within: inner) == 3..<6)
        #expect(code.member(startingWith: "var value", within: 4..<5) == nil)
    }

    @Test("A pattern that runs over a line break is found on the line where it starts, a comment inside it blanked", arguments: [
        ("a\nb\ncall(\n    of: 1)", [2]),
        ("call(of: 1)\ncall(\n of: 2)\ncall(1)", [0, 1]),
        ("call( // of\n of: 1)", [0]),
    ] as [(String, [Int])])
    func patternOverLines(source: String, lines: [Int]) throws {
        let call = try NSRegularExpression(pattern: #"\bcall\s*\(\s*of\b"#)

        #expect(SwiftCode(source).lines(matching: call) == lines)
    }

    @Test("A pattern looked for in the skeleton is not found in the text of a string, and is in an interpolation")
    func patternInTheSkeleton() throws {
        let call = try NSRegularExpression(pattern: #"\bcall\s*\(\s*of\b"#)
        let code = SwiftCode(#"""
        let s = "call(of: 1)"
        call(of: 2)
        let t = "\(call(of: 3))"
        """#)

        #expect(code.lines(matching: call) == [0, 1, 2])
        #expect(code.skeletonLines(matching: call) == [1, 2])
    }
}
