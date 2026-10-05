import SwiftSyntax

/// `functionLength`: the code lines of each body. A closure and a nested function are measured on their own and not
/// counted again in the body that holds them.
final class BodyLengthVisitor: BodyVisitor {
    private(set) var hits: [Hit] = []
    private var regions = Regions()

    override func enter(_ body: Body) {
        let range = body.statements.position..<body.statements.endPosition
        regions.push(Regions.Region(name: body.name, line: body.line, range: range))
    }

    override func leave(_ body: Body) {
        let region = regions.pop()
        guard region.lines.count > Limits.functionLines else { return }
        hits.append(Hit(measured: "functionLength", "\(region.name) has \(region.lines.count) lines of code, at most \(Limits.functionLines)",
                        line: region.line))
    }

    override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        regions.add(token, counting: lines)
        return .visitChildren
    }
}
