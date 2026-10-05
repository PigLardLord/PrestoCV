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

/// The code lines of each open region, a body or a type. A token counts in the innermost region that holds it and in
/// every region around that one, up to and including the first isolated one: a closure is isolated, so its lines are
/// not counted again in the body that holds it, while a nested function or type still counts in its enclosing one.
struct Regions {
    struct Region {
        let name: String
        let line: Int
        let range: Range<AbsolutePosition>
        var isolated = false
        var lines: Set<Int> = []
    }

    private var open: [Region] = []

    mutating func open(_ region: Region) { open.append(region) }

    mutating func close() -> Region { open.removeLast() }

    mutating func add(_ span: ClosedRange<Int>, at position: AbsolutePosition) {
        var index = open.endIndex
        while index > open.startIndex {
            index -= 1
            guard open[index].range.contains(position) else { continue }
            open[index].lines.formUnion(span)
            if open[index].isolated { return }
        }
    }
}
