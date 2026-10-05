import SwiftSyntax

/// Calls `enter` and `leave` around every body of a file, in every `#if` branch.
class BodyVisitor: SyntaxAnyVisitor {
    let lines: CodeLines

    init(lines: CodeLines) {
        self.lines = lines
        super.init(viewMode: .sourceAccurate)
    }

    func enter(_ body: Body) {}
    func leave(_ body: Body) {}

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        if let body = Body.of(node, lines) { enter(body) }
        return .visitChildren
    }

    override func visitAnyPost(_ node: Syntax) {
        if let body = Body.of(node, lines) { leave(body) }
    }
}
