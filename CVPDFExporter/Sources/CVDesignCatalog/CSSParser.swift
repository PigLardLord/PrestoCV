import Foundation

/// The structure of a stylesheet: `(rule | @media medium { rule* })*`. It reads the blocks and leaves what is inside
/// them to the selector and declaration parsers, then writes the canonical text of what they accepted.
struct CSSParser {
    private static let media: Set<String> = ["print", "screen", "all"]

    private var tokens: CSSTokenStream

    /// The canonical text of the stylesheet, or the first reason to refuse it.
    static func canonical(_ tokens: [CSSToken]) throws(CSSRejection) -> String {
        var parser = CSSParser(tokens: CSSTokenStream(tokens))
        return try parser.readStylesheet()
    }

    private mutating func readStylesheet() throws(CSSRejection) -> String {
        var items: [String] = []
        tokens.skipWhitespace()
        while !tokens.isAtEnd {
            items.append(try readItem())
            tokens.skipWhitespace()
        }
        return items.joined()
    }

    private mutating func readItem() throws(CSSRejection) -> String {
        guard case .atKeyword(let keyword)? = tokens.current else { return try readRule() }
        guard keyword == "media" else { throw CSSRejection(reason: "@\(keyword) is not allowed") }
        return try readMediaBlock()
    }

    private mutating func readMediaBlock() throws(CSSRejection) -> String {
        tokens.advance()
        tokens.skipWhitespace()
        let medium = try readMedium()
        try skipOpeningBrace()
        tokens.skipWhitespace()
        var rules: [String] = []
        while let token = tokens.current, token != .rbrace {
            rules.append(try readRule())
            tokens.skipWhitespace()
        }
        guard !tokens.isAtEnd else { throw CSSRejection(reason: "unterminated @media") }
        tokens.advance()
        return "@media \(medium){\(rules.joined())}"
    }

    private mutating func readMedium() throws(CSSRejection) -> String {
        guard case .ident(let name)? = tokens.current, Self.media.contains(name.lowercased()) else {
            throw CSSRejection(reason: "only @media print, screen or all")
        }
        tokens.advance()
        tokens.skipWhitespace()
        return name.lowercased()
    }

    private mutating func readRule() throws(CSSRejection) -> String {
        let prelude = try readPrelude()
        let body = try readBody()
        let selectors = try CSSSelectorParser.canonicalList(prelude)
        let declarations = try CSSDeclarationParser.canonical(body)
        return "\(selectors){\(declarations)}"
    }

    /// The tokens before the rule's `{`, which is read too.
    private mutating func readPrelude() throws(CSSRejection) -> [CSSToken] {
        var prelude: [CSSToken] = []
        while let token = tokens.current, token != .lbrace {
            guard token != .rbrace, token != .semicolon else { throw CSSRejection(reason: "unexpected token in selector") }
            prelude.append(token)
            tokens.advance()
        }
        try skipOpeningBrace()
        return prelude
    }

    /// The tokens between the rule's braces; the closing `}` is read too.
    private mutating func readBody() throws(CSSRejection) -> [CSSToken] {
        var body: [CSSToken] = []
        while let token = tokens.current, token != .rbrace {
            guard token != .lbrace else { throw CSSRejection(reason: "nested rules are not allowed") }
            body.append(token)
            tokens.advance()
        }
        guard !tokens.isAtEnd else { throw CSSRejection(reason: "unterminated rule") }
        tokens.advance()
        return body
    }

    private mutating func skipOpeningBrace() throws(CSSRejection) {
        guard tokens.current == .lbrace else { throw CSSRejection(reason: "expected {") }
        tokens.advance()
    }
}
