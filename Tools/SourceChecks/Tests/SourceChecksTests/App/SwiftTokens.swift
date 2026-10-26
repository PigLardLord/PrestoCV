import Foundation

// MARK: - Swift tokens

/// One token of Swift source: what a check needs to read a manifest without being fooled by what is written around it.
struct SwiftToken: Equatable {
    enum Kind: Equatable {
        case identifier
        case number
        case string
        case punctuation
    }

    let kind: Kind
    /// An identifier, a number, or the one character of a punctuation mark; empty for a string.
    let text: String
    /// What a string says, when it is on one line and holds nothing to evaluate: no escape. (A string with an
    /// interpolation is never a token: the lexer fails on it.)
    let value: String?
    /// The line the token starts on, counted from 1.
    let line: Int

    func isPunctuation(_ mark: String) -> Bool { kind == .punctuation && text == mark }
    func isIdentifier(_ name: String) -> Bool { kind == .identifier && text == name }
    var isOpening: Bool { kind == .punctuation && ["(", "[", "{"].contains(text) }
}

/// Reads Swift source into tokens: it takes the comments away (block comments nest) and reads every string literal
/// whole, plain, raw (`#"…"#`) and multiline (`"""`), so that a `//`, a bracket or `.iOS(` written in a comment or a
/// string is never read as code.
///
/// It fails closed. A source it cannot read to its end, or in which it cannot tell code from text, is a failure and not
/// a partial result, because the code it did not read could be anything:
/// - a string, a quoted name or a comment that is not closed;
/// - a string with an interpolation (`\(…)`, `\#(…)`, in a plain, raw or multiline string): the interpolation is code
///   that runs, and it can change a package;
/// - a slash outside a string and a comment: it can start a regular expression literal (`/…/`, `#/…/#`), which is
///   told from a division only by the compiler, and which can hold a quote or a comment marker that hides the code that
///   follows;
/// - a line comment that holds a Unicode line separator (U+0085, U+2028, U+2029): a compiler is free to end the comment
///   there, and the lexer does not guess.
///
/// A line ends at a line feed, a carriage return, or a carriage return and a line feed, as for the compiler; a line
/// comment ends there. The lines it reports are counted the same way.
enum SwiftLexer {

    struct Failure: Error, Equatable {
        let line: Int
        let what: String
    }

    static func tokens(of source: String) -> Result<[SwiftToken], Failure> {
        var cursor = Cursor(scalars: Array(source.unicodeScalars))
        do {
            return .success(try cursor.scan())
        } catch let failure as Failure {
            return .failure(failure)
        } catch {
            return .failure(Failure(line: cursor.line, what: "unexpected error"))
        }
    }

    // MARK: Cursor

    private struct Cursor {
        let scalars: [Unicode.Scalar]
        var index = 0
        var line = 1

        init(scalars: [Unicode.Scalar]) { self.scalars = scalars }

        func peek(_ offset: Int = 0) -> Unicode.Scalar? {
            index + offset < scalars.count ? scalars[index + offset] : nil
        }

        /// Moves on one scalar. A line feed is a line, and so is a carriage return that no line feed follows.
        mutating func advance() {
            if scalars[index] == "\n" || (scalars[index] == "\r" && peek(1) != "\n") { line += 1 }
            index += 1
        }

        /// Whether the scalars from `offset` on are exactly `text`.
        func has(_ text: String, at offset: Int = 0) -> Bool {
            let wanted = Array(text.unicodeScalars)
            return (0..<wanted.count).allSatisfy { peek(offset + $0) == wanted[$0] }
        }

        // MARK: Scanning

        /// The tokens up to the end of the source.
        mutating func scan() throws -> [SwiftToken] {
            var tokens: [SwiftToken] = []
            while let scalar = peek() {
                if scalar.properties.isWhitespace {
                    advance()
                } else if has("//") {
                    try skipLineComment()
                } else if has("/*") {
                    try skipBlockComment()
                } else if scalar == "/" {
                    throw Failure(
                        line: line,
                        what: "a slash outside a string and a comment, which could start a regular expression literal that is not read"
                    )
                } else if scalar == "\"" || scalar == "#" {
                    if let token = try scanStringOrDirective() { tokens.append(token) } else {
                        tokens.append(SwiftToken(kind: .punctuation, text: "#", value: nil, line: line))
                        advance()
                    }
                } else if scalar == "`" {
                    tokens.append(try scanQuotedIdentifier())
                } else if SwiftLexer.isIdentifierStart(scalar) {
                    tokens.append(scanWhile(.identifier, SwiftLexer.isIdentifierPart))
                } else if SwiftLexer.isDigit(scalar) {
                    tokens.append(scanNumber())
                } else {
                    tokens.append(SwiftToken(kind: .punctuation, text: String(scalar), value: nil, line: line))
                    advance()
                }
            }
            return tokens
        }

        /// A line comment, up to the end of its line. One that holds a Unicode line separator is a failure: where the
        /// comment ends is then a question of the compiler, and a guess could read as code what the compiler skips, or
        /// skip as a comment what the compiler runs.
        private mutating func skipLineComment() throws {
            while let next = peek(), next != "\n", next != "\r" {
                if next == "\u{0085}" || next == "\u{2028}" || next == "\u{2029}" {
                    throw Failure(line: line, what: "a comment holds a line separator, where a compiler may end it")
                }
                advance()
            }
        }

        private mutating func skipBlockComment() throws {
            let start = line
            var depth = 0
            while peek() != nil {
                if has("/*") {
                    depth += 1
                    advance(); advance()
                } else if has("*/") {
                    depth -= 1
                    advance(); advance()
                    if depth == 0 { return }
                } else {
                    advance()
                }
            }
            throw Failure(line: start, what: "a comment is not closed")
        }

        /// A string literal, if one starts here; `nil` for a `#` that starts none (`#if`, `#endif`).
        private mutating func scanStringOrDirective() throws -> SwiftToken? {
            var hashes = 0
            while peek(hashes) == "#" { hashes += 1 }
            if peek(hashes) == "\"" { return try scanString(hashes: hashes) }
            if hashes >= 1 && peek(hashes) == "/" { throw Failure(line: line, what: "a regular expression literal is not read") }
            return nil
        }

        private mutating func scanString(hashes: Int) throws -> SwiftToken {
            let start = line
            for _ in 0..<hashes { advance() }
            advance()
            let multiline = has("\"\"")
            if multiline { advance(); advance() }
            var content = String.UnicodeScalarView()
            var plain = !multiline
            while let scalar = peek() {
                if scalar == "\"" && closesString(multiline: multiline, hashes: hashes) {
                    advance()
                    if multiline { advance(); advance() }
                    for _ in 0..<hashes { advance() }
                    return SwiftToken(kind: .string, text: "", value: plain ? String(content) : nil, line: start)
                }
                if scalar == "\\" && (0..<hashes).allSatisfy({ peek(1 + $0) == "#" }) {
                    plain = false
                    let backslash = line
                    advance()
                    for _ in 0..<hashes { advance() }
                    if peek() == "(" {
                        throw Failure(line: backslash, what: "a string holds an interpolation, which is code that is not read")
                    } else if peek() != nil {
                        advance()
                    }
                } else if (scalar == "\n" || scalar == "\r") && !multiline {
                    throw Failure(line: start, what: "a string is not closed")
                } else {
                    content.append(scalar)
                    advance()
                }
            }
            throw Failure(line: start, what: "a string is not closed")
        }

        /// Whether the quote under the cursor ends the string: three quotes for a multiline one, then the hashes.
        private func closesString(multiline: Bool, hashes: Int) -> Bool {
            let quotes = multiline ? 3 : 1
            return (0..<quotes).allSatisfy { peek($0) == "\"" } && (0..<hashes).allSatisfy { peek(quotes + $0) == "#" }
        }

        private mutating func scanQuotedIdentifier() throws -> SwiftToken {
            let start = line
            advance()
            var name = ""
            while let scalar = peek(), scalar != "`", scalar != "\n", scalar != "\r" {
                name.unicodeScalars.append(scalar)
                advance()
            }
            guard peek() == "`" else { throw Failure(line: start, what: "a quoted name is not closed") }
            advance()
            return SwiftToken(kind: .identifier, text: name, value: nil, line: start)
        }

        private mutating func scanNumber() -> SwiftToken {
            let start = line
            var text = ""
            while let scalar = peek() {
                let continues = SwiftLexer.isIdentifierPart(scalar) || (scalar == "." && peek(1).map(SwiftLexer.isDigit) == true)
                guard continues else { break }
                text.unicodeScalars.append(scalar)
                advance()
            }
            return SwiftToken(kind: .number, text: text, value: nil, line: start)
        }

        private mutating func scanWhile(_ kind: SwiftToken.Kind, _ accepts: (Unicode.Scalar) -> Bool) -> SwiftToken {
            let start = line
            var text = ""
            while let scalar = peek(), accepts(scalar) {
                text.unicodeScalars.append(scalar)
                advance()
            }
            return SwiftToken(kind: kind, text: text, value: nil, line: start)
        }
    }

    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool { ("0"..."9").contains(scalar) }

    private static func isIdentifierStart(_ scalar: Unicode.Scalar) -> Bool {
        scalar == "_" || scalar.properties.isAlphabetic
    }

    private static func isIdentifierPart(_ scalar: Unicode.Scalar) -> Bool {
        isIdentifierStart(scalar) || isDigit(scalar)
    }
}
