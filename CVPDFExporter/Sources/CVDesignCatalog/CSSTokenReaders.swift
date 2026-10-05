import Foundation

/// A run of white space is one token.
struct CSSWhitespaceReader: CSSTokenReader {
    func begins(in input: CSSInput) -> Bool { input.satisfies(\.isCSSWhitespace) }

    func read(from input: inout CSSInput) -> CSSToken? {
        _ = input.take(while: \.isCSSWhitespace)
        return .whitespace
    }
}

/// A comment is dropped. One that never ends is refused, since it could swallow the rest of the stylesheet.
struct CSSCommentReader: CSSTokenReader {
    func begins(in input: CSSInput) -> Bool { input.matches("/*") }

    func read(from input: inout CSSInput) throws(CSSRejection) -> CSSToken? {
        input.skip(2)
        while !input.isAtEnd, !input.matches("*/") { input.skip() }
        guard !input.isAtEnd else { throw CSSRejection(reason: "unterminated comment") }
        input.skip(2)
        return nil
    }
}

/// A string on one line, in single or double quotes, with no escapes (those are refused before reading).
struct CSSStringReader: CSSTokenReader {
    func begins(in input: CSSInput) -> Bool { input.matches("\"") || input.matches("'") }

    func read(from input: inout CSSInput) throws(CSSRejection) -> CSSToken? {
        let quote = input.take(1).unicodeScalars.first
        let value = input.take { $0 != quote && !$0.isCSSNewline }
        guard let next = input.peek() else { throw CSSRejection(reason: "unterminated string") }
        guard next == quote else { throw CSSRejection(reason: "newline in string") }
        input.skip()
        return .string(value)
    }
}

/// Outside comments and strings only printable ASCII is allowed; anything else is refused, not skipped.
struct CSSUnsupportedCharacterReader: CSSTokenReader {
    func begins(in input: CSSInput) -> Bool { input.satisfies { $0.value > 0x7E || $0.value < 0x20 } }

    func read(from input: inout CSSInput) throws(CSSRejection) -> CSSToken? {
        throw CSSRejection(reason: "non-ASCII or control character outside comments")
    }
}

/// An identifier, or a function name when an opening parenthesis follows it. A function name is lower-cased.
struct CSSNameReader: CSSTokenReader {
    func begins(in input: CSSInput) -> Bool {
        input.satisfies(\.isCSSNameStart) || (input.matches("-") && (input.satisfies(\.isCSSNameStart, at: 1) || input.matches("-", at: 1)))
    }

    func read(from input: inout CSSInput) -> CSSToken? {
        let name = input.takeName()
        guard input.matches("(") else { return .ident(name) }
        input.skip()
        return .function(name.lowercased())
    }
}

/// `@` and the name after it, lower-cased.
struct CSSAtKeywordReader: CSSTokenReader {
    func begins(in input: CSSInput) -> Bool { input.matches("@") }

    func read(from input: inout CSSInput) -> CSSToken? {
        input.skip()
        return .atKeyword(input.takeName().lowercased())
    }
}

/// `#` and the name after it.
struct CSSHashReader: CSSTokenReader {
    func begins(in input: CSSInput) -> Bool { input.matches("#") }

    func read(from input: inout CSSInput) -> CSSToken? {
        input.skip()
        return .hash(input.takeName())
    }
}

/// Any other scalar: a punctuation token the grammar names, or a delimiter. The reader to fall back on.
struct CSSDelimiterReader: CSSTokenReader {
    func begins(in input: CSSInput) -> Bool { !input.isAtEnd }

    func read(from input: inout CSSInput) -> CSSToken? {
        guard let scalar = input.peek() else { return nil }
        input.skip()
        return Self.token(for: scalar)
    }

    private static func token(for scalar: Unicode.Scalar) -> CSSToken {
        switch scalar {
        case ":": .colon
        case ";": .semicolon
        case ",": .comma
        case "{": .lbrace
        case "}": .rbrace
        case "(": .lparen
        case ")": .rparen
        case "[": .lbracket
        case "]": .rbracket
        default: .delim(scalar)
        }
    }
}
