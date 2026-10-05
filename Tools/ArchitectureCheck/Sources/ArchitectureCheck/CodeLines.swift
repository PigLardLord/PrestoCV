import SwiftSyntax

/// Where the code lines of one file are, as ADR 0021 (c) counts them: a line holds code when a token other than a
/// brace touches it. Blank lines, comment-only lines and brace-only lines never count. A token that spans lines,
/// such as a segment of a multi-line string, makes every line it spans code.
struct CodeLines {
    let converter: SourceLocationConverter

    func line(of node: some SyntaxProtocol) -> Int { node.startLocation(converter: converter).line }

    func line(at position: AbsolutePosition) -> Int { converter.location(for: position).line }

    /// The lines the token touches, or nil for a brace and for a token without text.
    func span(of token: TokenSyntax) -> ClosedRange<Int>? {
        guard token.presence == .present, !token.text.isEmpty, !Self.isBrace(token) else { return nil }
        let first = line(at: token.positionAfterSkippingLeadingTrivia)
        let last = line(at: token.endPositionBeforeTrailingTrivia.advanced(by: -1))
        return first...max(first, last)
    }

    static func isBrace(_ token: TokenSyntax) -> Bool { token.tokenKind == .leftBrace || token.tokenKind == .rightBrace }

    /// The number of code lines among the tokens of a node.
    func count(in node: some SyntaxProtocol) -> Int {
        var counted: Set<Int> = []
        for token in node.tokens(viewMode: .sourceAccurate) { if let span = span(of: token) { counted.formUnion(span) } }
        return counted.count
    }
}
