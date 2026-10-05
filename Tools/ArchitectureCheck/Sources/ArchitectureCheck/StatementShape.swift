import SwiftSyntax

/// What a statement or an expression adds to the shape of the function that holds it: decisions, and a level of nesting.
///
/// An `if`, a `guard` and a `while` decide once for the statement and once for each condition after the first, because
/// a comma in a condition list is an `&&` written another way.
struct StatementShape {
    var decisions = 0
    var isLevel = false

    static let none = StatementShape()

    static func of(_ node: Syntax) -> StatementShape {
        switch node.kind {
        case .ifExpr: ifStatement(node.cast(IfExprSyntax.self))
        case .guardStmt: guardStatement(node.cast(GuardStmtSyntax.self))
        case .whileStmt: StatementShape(decisions: node.cast(WhileStmtSyntax.self).conditions.count, isLevel: true)
        case .switchExpr, .forStmt, .repeatStmt: StatementShape(decisions: 1, isLevel: true)
        case .doStmt: StatementShape(decisions: 0, isLevel: true)
        case .catchClause, .unresolvedTernaryExpr: StatementShape(decisions: 1)
        case .binaryOperatorExpr: StatementShape(decisions: isDecision(node.cast(BinaryOperatorExprSyntax.self)) ? 1 : 0)
        default: none
        }
    }

    /// `else if` continues the chain of its `if`: it is neither a level nor a second one.
    private static func ifStatement(_ node: IfExprSyntax) -> StatementShape {
        StatementShape(decisions: node.conditions.count, isLevel: node.parent?.is(IfExprSyntax.self) != true)
    }

    /// A guard that only exits states a precondition: it is no level.
    private static func guardStatement(_ node: GuardStmtSyntax) -> StatementShape {
        StatementShape(decisions: node.conditions.count, isLevel: !onlyExits(node))
    }

    /// Whether the `else` of a guard is one `return`, `throw`, `break` or `continue`.
    private static func onlyExits(_ node: GuardStmtSyntax) -> Bool {
        let statements = node.body.statements
        return statements.count == 1 && statements.first.map { isExit($0.item) } == true
    }

    private static func isExit(_ item: CodeBlockItemSyntax.Item) -> Bool {
        [.returnStmt, .throwStmt, .breakStmt, .continueStmt].contains(Syntax(item).kind)
    }

    /// An `&&`, `||` or `??` decides, unless it is part of the condition of a `#if`, which is settled when the code is
    /// compiled and not when it runs.
    private static func isDecision(_ node: BinaryOperatorExprSyntax) -> Bool {
        ["&&", "||", "??"].contains(node.operator.text) && !isCompileTimeCondition(node)
    }

    private static func isCompileTimeCondition(_ node: some SyntaxProtocol) -> Bool {
        var child = Syntax(node)
        while let parent = child.parent {
            if let clause = parent.as(IfConfigClauseSyntax.self) { return clause.condition?.id == child.id }
            child = parent
        }
        return false
    }
}
