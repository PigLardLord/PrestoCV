import SwiftSyntax

/// `functionLength`: the code lines of each body. A closure is measured on its own and not counted again in the body
/// that holds it. A nested function is measured on its own and also counts in the body that holds it.
final class BodyLengthVisitor: BodyVisitor {
    private(set) var hits: [Hit] = []
    private var regions = Regions()

    override func enter(_ body: Body) {
        let range = body.statements.position..<body.statements.endPosition
        regions.open(Regions.Region(name: body.name, line: body.line, range: range, isolated: body.isClosure))
    }

    override func leave(_ body: Body) {
        let region = regions.close()
        guard region.lines.count > Limits.functionLines else { return }
        hits.append(Hit(measured: "functionLength", "\(region.name) has \(region.lines.count) lines of code, at most \(Limits.functionLines)",
                        line: region.line))
    }

    override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        if let span = lines.span(of: token) { regions.add(span, at: token.positionAfterSkippingLeadingTrivia) }
        return .visitChildren
    }
}
