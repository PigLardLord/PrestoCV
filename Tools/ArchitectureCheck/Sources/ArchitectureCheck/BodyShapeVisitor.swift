import SwiftSyntax

/// `nestingDepth` and `cyclomaticComplexity`: the shape of each function, initialiser, deinitialiser and accessor. A
/// closure inside one is a level of its nesting and its decisions count in it. A closure that no such body holds
/// (a property initialiser) is measured as a body of its own, and so is a nested function.
final class BodyShapeVisitor: BodyVisitor {
    private(set) var hits: [Hit] = []
    private var shapes: [FunctionShape] = []

    /// The function being walked, which a change goes to.
    private var top: FunctionShape? {
        get { shapes.last }
        set { if let newValue { shapes[shapes.count - 1] = newValue } }
    }

    // MARK: Bodies

    override func enter(_ body: Body) {
        if body.isClosure, !shapes.isEmpty { top?.enterLevel(at: body.line) } else { shapes.append(FunctionShape(of: body)) }
    }

    override func leave(_ body: Body) {
        if body.isClosure, top?.body.id != body.id { top?.exitLevel() } else { hits += shapes.removeLast().hits }
    }

    // MARK: Statements and expressions

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        let next = super.visitAny(node)
        let shape = StatementShape.of(node)
        top?.decide(shape.decisions)
        if shape.isLevel { top?.enterLevel(at: lines.line(of: node)) }
        return next
    }

    override func visitAnyPost(_ node: Syntax) {
        if StatementShape.of(node).isLevel { top?.exitLevel() }
        super.visitAnyPost(node)
    }
}
