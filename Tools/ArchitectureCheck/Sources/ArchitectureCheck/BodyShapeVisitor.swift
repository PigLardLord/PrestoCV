import SwiftSyntax

/// `nestingDepth` and `cyclomaticComplexity`: the shape of each function, initialiser, deinitialiser and accessor. A
/// closure inside one is a level of its nesting and its decisions count in it. A closure that no such body holds
/// (a property initialiser) is measured as a body of its own, and so is a nested function.
final class BodyShapeVisitor: BodyVisitor {
    private struct Unit {
        let body: Body
        var complexity = 1
        var depth = 0
        var deepest = 0
        var firstTooDeepLine: Int?
    }

    private(set) var hits: [Hit] = []
    private var units: [Unit] = []

    // MARK: Bodies

    override func enter(_ body: Body) {
        if body.isClosure, !units.isEmpty { enterLevel(at: body.line) } else { units.append(Unit(body: body)) }
    }

    override func leave(_ body: Body) {
        if body.isClosure, units.last?.body.id != body.id { exitLevel() } else { report(units.removeLast()) }
    }

    private func report(_ unit: Unit) {
        let name = unit.body.name
        if unit.complexity > Limits.complexity {
            hits.append(Hit(measured: "cyclomaticComplexity", "\(name) has a cyclomatic complexity of \(unit.complexity), at most \(Limits.complexity)",
                            line: unit.body.line))
        }
        if let line = unit.firstTooDeepLine {
            hits.append(Hit(measured: "nestingDepth", "\(name) nests \(unit.deepest) levels deep, at most \(Limits.nesting)", line: line))
        }
    }

    // MARK: Levels and decisions

    // An `if`, a `guard` and a `while` decide once for the statement and once for each condition after the first: a
    // comma in a condition list is an `&&` written another way.

    private func enterLevel(at line: Int) {
        guard !units.isEmpty else { return }
        units[units.count - 1].depth += 1
        let unit = units[units.count - 1]
        units[units.count - 1].deepest = max(unit.deepest, unit.depth)
        if unit.depth > Limits.nesting, unit.firstTooDeepLine == nil { units[units.count - 1].firstTooDeepLine = line }
    }

    private func exitLevel() {
        guard !units.isEmpty else { return }
        units[units.count - 1].depth -= 1
    }

    private func decide(_ decisions: Int = 1) {
        guard !units.isEmpty else { return }
        units[units.count - 1].complexity += decisions
    }

    override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        decide(node.conditions.count)
        if !Self.isElseIf(node) { enterLevel(at: lines.line(of: node)) }
        return .visitChildren
    }

    override func visitPost(_ node: IfExprSyntax) {
        if !Self.isElseIf(node) { exitLevel() }
    }

    override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        decide(node.conditions.count)
        if !Self.onlyExits(node) { enterLevel(at: lines.line(of: node)) }
        return .visitChildren
    }

    override func visitPost(_ node: GuardStmtSyntax) {
        if !Self.onlyExits(node) { exitLevel() }
    }

    override func visit(_ node: SwitchExprSyntax) -> SyntaxVisitorContinueKind {
        decide()
        enterLevel(at: lines.line(of: node))
        return .visitChildren
    }

    override func visitPost(_ node: SwitchExprSyntax) { exitLevel() }

    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        decide()
        enterLevel(at: lines.line(of: node))
        return .visitChildren
    }

    override func visitPost(_ node: ForStmtSyntax) { exitLevel() }

    override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        decide(node.conditions.count)
        enterLevel(at: lines.line(of: node))
        return .visitChildren
    }

    override func visitPost(_ node: WhileStmtSyntax) { exitLevel() }

    override func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind {
        decide()
        enterLevel(at: lines.line(of: node))
        return .visitChildren
    }

    override func visitPost(_ node: RepeatStmtSyntax) { exitLevel() }

    override func visit(_ node: DoStmtSyntax) -> SyntaxVisitorContinueKind {
        enterLevel(at: lines.line(of: node))
        return .visitChildren
    }

    override func visitPost(_ node: DoStmtSyntax) { exitLevel() }

    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        decide()
        return .visitChildren
    }

    override func visit(_ node: UnresolvedTernaryExprSyntax) -> SyntaxVisitorContinueKind {
        decide()
        return .visitChildren
    }

    override func visit(_ node: BinaryOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        if ["&&", "||", "??"].contains(node.operator.text), !Self.isCompileTimeCondition(node) { decide() }
        return .visitChildren
    }

    // MARK: Shapes

    /// The condition of a `#if` clause is settled when the code is compiled, not when it runs, so its operators are no decisions.
    private static func isCompileTimeCondition(_ node: some SyntaxProtocol) -> Bool {
        var child = Syntax(node)
        while let parent = child.parent {
            if let clause = parent.as(IfConfigClauseSyntax.self) { return clause.condition?.id == child.id }
            child = parent
        }
        return false
    }

    /// `else if` continues the chain of its `if`: it is neither a level nor a second one.
    private static func isElseIf(_ node: IfExprSyntax) -> Bool { node.parent?.is(IfExprSyntax.self) == true }

    /// A guard whose `else` is one `return`, `throw`, `break` or `continue` states a precondition: it is no level.
    private static func onlyExits(_ node: GuardStmtSyntax) -> Bool {
        guard node.body.statements.count == 1, let item = node.body.statements.first?.item else { return false }
        return item.is(ReturnStmtSyntax.self) || item.is(ThrowStmtSyntax.self) || item.is(BreakStmtSyntax.self) || item.is(ContinueStmtSyntax.self)
    }
}
