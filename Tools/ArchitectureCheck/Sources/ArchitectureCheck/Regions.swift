import SwiftSyntax

/// The code lines of each open region, a body or a type. A token counts in the innermost open region that holds it
/// and in no region around that one, so a closure, a nested function or a nested type is not counted again in what
/// holds it. Its header, the line that holds its name or its call, still belongs to the holder.
struct Regions {
    struct Region {
        let name: String
        let line: Int
        let range: Range<AbsolutePosition>
        var lines: Set<Int> = []
    }

    private var stack: [Region] = []

    mutating func push(_ region: Region) { stack.append(region) }

    mutating func pop() -> Region { stack.removeLast() }

    /// Counts the lines of a token in the innermost region that holds it, if any holds it.
    mutating func add(_ token: TokenSyntax, counting lines: CodeLines) {
        guard let span = lines.span(of: token) else { return }
        let position = token.positionAfterSkippingLeadingTrivia
        guard let index = stack.lastIndex(where: { $0.range.contains(position) }) else { return }
        stack[index].lines.formUnion(span)
    }
}
