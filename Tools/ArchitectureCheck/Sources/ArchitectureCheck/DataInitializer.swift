import SwiftSyntax

/// An initialiser that describes a data structure, not a behaviour (ADR 0021 (c)), so it may take as many parameters
/// as the structure has. Its body is one of two shapes, and nothing else:
/// - **assignments**: each statement is `self.x = x`, naming the property after its parameter, each parameter once,
///   or gives another property a literal or a constant (`self.revision = 0`). A property is assigned once;
/// - **delegation**: the only statement is `self.init(...)`, and each argument is a parameter passed unchanged, each
///   parameter once, or a literal or a constant.
struct DataInitializer {
    let constants: FileConstants

    func matches(_ node: InitializerDeclSyntax) -> Bool {
        guard let statements = node.body?.statements, !statements.isEmpty else { return false }
        let names = node.signature.parameterClause.parameters.map { ($0.secondName ?? $0.firstName).text }
        let values = ConstantValue(constants: constants, parameters: Set(names))
        return Self.assigns(statements, names, values) || Self.delegates(statements, names, values)
    }

    private static func assigns(_ statements: CodeBlockItemListSyntax, _ names: [String], _ values: ConstantValue) -> Bool {
        let assignments = statements.compactMap { Assignment($0.item) }
        guard assignments.count == statements.count, Set(assignments.map(\.target)).count == assignments.count else { return false }
        let stored = assignments.filter { $0.storesParameter(of: values) }
        let given = assignments.filter { $0.givesConstant(of: values) }
        return stored.count + given.count == assignments.count && stored.map(\.target).sorted() == names.sorted()
    }

    private static func delegates(_ statements: CodeBlockItemListSyntax, _ names: [String], _ values: ConstantValue) -> Bool {
        guard statements.count == 1, let call = statements.first?.item.as(FunctionCallExprSyntax.self), isSelfInit(call),
              let passed = passedParameters(of: call, values) else { return false }
        return passed.sorted() == names.sorted()
    }

    /// `self.init(...)`, without a trailing closure.
    private static func isSelfInit(_ call: FunctionCallExprSyntax) -> Bool {
        guard call.trailingClosure == nil, call.additionalTrailingClosures.isEmpty,
              let callee = call.calledExpression.as(MemberAccessExprSyntax.self) else { return false }
        return callee.declName.baseName.text == "init" && isSelf(callee.base)
    }

    /// The parameters that the arguments pass unchanged; nil when an argument is neither a parameter nor a constant.
    private static func passedParameters(of call: FunctionCallExprSyntax, _ values: ConstantValue) -> [String]? {
        var passed: [String] = []
        for argument in call.arguments {
            if let name = values.parameter(argument.expression) {
                passed.append(name)
            } else if !values.accepts(argument.expression) {
                return nil
            }
        }
        return passed
    }
}

private func isSelf(_ expr: ExprSyntax?) -> Bool { expr?.as(DeclReferenceExprSyntax.self)?.baseName.text == "self" }

/// `self.name = value`, or `name = value`, as a statement.
private struct Assignment {
    let target: String
    let value: ExprSyntax

    init?(_ item: CodeBlockItemSyntax.Item) {
        guard let sequence = item.as(SequenceExprSyntax.self), sequence.elements.count == 3 else { return nil }
        let parts = Array(sequence.elements)
        guard parts[1].is(AssignmentExprSyntax.self), let target = Self.targetName(of: parts[0]) else { return nil }
        self.target = target
        value = parts[2]
    }

    /// `self.x = x`, where `x` is a parameter.
    func storesParameter(of values: ConstantValue) -> Bool { values.parameter(value) == target }

    func givesConstant(of values: ConstantValue) -> Bool { values.accepts(value) }

    /// The property that `self.name` or `name` names.
    private static func targetName(of expr: ExprSyntax) -> String? {
        if let member = expr.as(MemberAccessExprSyntax.self) { return isSelf(member.base) ? member.declName.baseName.text : nil }
        return expr.as(DeclReferenceExprSyntax.self)?.baseName.text
    }
}
