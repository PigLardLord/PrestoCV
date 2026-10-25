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
    /// What a string says, when it is on one line and holds nothing to evaluate: no escape, no interpolation.
    let value: String?
    /// The line the token starts on, counted from 1.
    let line: Int

    func isPunctuation(_ mark: String) -> Bool { kind == .punctuation && text == mark }
    func isIdentifier(_ name: String) -> Bool { kind == .identifier && text == name }
    var isOpening: Bool { kind == .punctuation && ["(", "[", "{"].contains(text) }
}

/// Reads Swift source into tokens: it takes the comments away (block comments nest) and reads every string literal
/// whole, raw (`#"…"#`), multiline (`"""`) and with interpolation (`\(…)`), so that a `//`, a bracket or `.iOS(` written
/// in a comment or a string is never read as code.
///
/// A source it cannot read to its end is a failure, not a partial result: a string or a comment that is not closed, an
/// interpolation that is not closed, and a regular expression literal in the `#/…/#` form. A regular expression
/// literal in the bare `/…/` form is not told from a division and is not read as one; no manifest of the repository
/// writes one, and a quote in one would turn the rest of its line into a string that is not closed, which is a failure.
enum SwiftLexer {

    struct Failure: Error, Equatable {
        let line: Int
        let what: String
    }

    static func tokens(of source: String) -> Result<[SwiftToken], Failure> {
        var cursor = Cursor(scalars: Array(source.unicodeScalars))
        do {
            return .success(try cursor.scan(insideInterpolation: false))
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

        mutating func advance() {
            if scalars[index] == "\n" { line += 1 }
            index += 1
        }

        /// Whether the scalars from `offset` on are exactly `text`.
        func has(_ text: String, at offset: Int = 0) -> Bool {
            let wanted = Array(text.unicodeScalars)
            return (0..<wanted.count).allSatisfy { peek(offset + $0) == wanted[$0] }
        }

        // MARK: Scanning

        /// The tokens up to the end of the source; or, inside an interpolation, up to the bracket that closes it.
        mutating func scan(insideInterpolation: Bool) throws -> [SwiftToken] {
            var tokens: [SwiftToken] = []
            var depth = 0
            let interpolationLine = line
            while let scalar = peek() {
                if scalar.properties.isWhitespace {
                    advance()
                } else if has("//") {
                    while let next = peek(), next != "\n" { advance() }
                } else if has("/*") {
                    try skipBlockComment()
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
                    if insideInterpolation {
                        if scalar == ")" && depth == 0 { advance(); return tokens }
                        if scalar == "(" { depth += 1 }
                        if scalar == ")" { depth -= 1 }
                    }
                    tokens.append(SwiftToken(kind: .punctuation, text: String(scalar), value: nil, line: line))
                    advance()
                }
            }
            if insideInterpolation { throw Failure(line: interpolationLine, what: "an interpolation is not closed") }
            return tokens
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
                    advance()
                    for _ in 0..<hashes { advance() }
                    if peek() == "(" {
                        advance()
                        _ = try scan(insideInterpolation: true)
                    } else if peek() != nil {
                        advance()
                    }
                } else if scalar == "\n" && !multiline {
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
            while let scalar = peek(), scalar != "`", scalar != "\n" {
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
