import Foundation

/// One kind of token. A reader recognises where its token begins and reads it; it never looks at other kinds.
protocol CSSTokenReader: Sendable {
    /// Whether a token of this kind begins at the input's position.
    func begins(in input: CSSInput) -> Bool
    /// Reads the token that begins at the input's position, or nil for text that carries none, such as a comment.
    func read(from input: inout CSSInput) throws(CSSRejection) -> CSSToken?
}

/// A subset of CSS Syntax 3: text outside it is rejected, never skipped.
enum CSSTokenizer {
    /// Tried in order, so a reader that refuses a character comes before the readers that would take it. The
    /// delimiter reader is last: it begins at every scalar, so every scalar is read by some reader.
    private static let readers: [any CSSTokenReader] = [
        CSSWhitespaceReader(), CSSCommentReader(), CSSStringReader(), CSSUnsupportedCharacterReader(),
        CSSNumericReader(), CSSNameReader(), CSSAtKeywordReader(), CSSHashReader(), CSSDelimiterReader(),
    ]

    static func tokenize(_ css: String) throws(CSSRejection) -> [CSSToken] {
        try rejectMarkupBreakout(in: css)
        var input = CSSInput(css)
        var tokens: [CSSToken] = []
        while !input.isAtEnd {
            guard let token = try readToken(from: &input) else { continue }
            // A comment between two runs of white space leaves them one token.
            if token == .whitespace, tokens.last == .whitespace { continue }
            tokens.append(token)
        }
        return tokens
    }

    /// Checked on the raw text before anything else, comments and strings included, so neither can hide what these
    /// characters would do: close the `<style>` element, or write an escape.
    private static func rejectMarkupBreakout(in css: String) throws(CSSRejection) {
        if css.unicodeScalars.contains("<") { throw CSSRejection(reason: "'<' is not allowed (closes <style>)") }
        if css.unicodeScalars.contains("\\") { throw CSSRejection(reason: "CSS escapes are not allowed") }
    }

    private static func readToken(from input: inout CSSInput) throws(CSSRejection) -> CSSToken? {
        try readers.first { $0.begins(in: input) }?.read(from: &input)
    }
}
