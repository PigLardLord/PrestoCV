import SwiftSyntax

/// An initialiser that describes a data structure, not a behaviour (ADR 0021 (c)), so it may take as many parameters
/// as the structure has. Its body is one of two shapes, and nothing else:
/// - **assignments**: each statement is `self.x = x`, naming the property after its parameter, each parameter once,
///   or gives another property a literal or a constant (`self.revision = 0`). A property is assigned once, and each is
///   a stored instance property that the file declares for the type or one of its extensions: a computed property
///   runs code, a `static` one is no instance's, and one that cannot be found is not known to be stored;
/// - **delegation**: the only statement is `self.init(...)`, and each argument is a parameter passed unchanged, each
///   parameter once, or a literal or a constant. The call must reach an initialiser of the same type that the file
///   declares, with those argument labels and no variadic parameter, and that initialiser must be a data initialiser
///   in its turn; a call that reaches itself again, or one that cannot be resolved in the file, is not exempt.
struct DataInitializer {
    let constants: FileConstants
    let types: FileTypes

    func matches(_ node: InitializerDeclSyntax) -> Bool { matches(node, visiting: []) }

    /// `visiting` holds the initialisers whose delegation is being followed, so that a cycle ends and is not exempt.
    private func matches(_ node: InitializerDeclSyntax, visiting: Set<SyntaxIdentifier>) -> Bool {
        guard !visiting.contains(node.id), let subject = Subject(node, constants: constants) else { return false }
        return assigns(subject) || delegates(subject, visiting: visiting.union([node.id]))
    }

    private func assigns(_ subject: Subject) -> Bool {
        let assignments = subject.statements.compactMap { Assignment($0.item) }
        guard assignments.count == subject.statements.count, Set(assignments.map(\.target)).count == assignments.count,
              targetsAreStored(assignments, in: subject.node) else { return false }
        let stored = assignments.filter { $0.storesParameter(of: subject.values) }
        let given = assignments.filter { $0.givesConstant(of: subject.values) }
        return stored.count + given.count == assignments.count && stored.map(\.target).sorted() == subject.names.sorted()
    }

    /// Each assignment names a stored property of the type that the initialiser belongs to.
    private func targetsAreStored(_ assignments: [Assignment], in node: InitializerDeclSyntax) -> Bool {
        guard let stored = types.storedProperties(ofTypeHolding: node) else { return false }
        return assignments.allSatisfy { stored.contains($0.target) }
    }

    private func delegates(_ subject: Subject, visiting: Set<SyntaxIdentifier>) -> Bool {
        guard let call = Self.delegation(subject) else { return false }
        return reachesDataInitializer(call, from: subject.node, visiting: visiting)
    }

    /// The call of a body that is one `self.init(...)` passing each parameter once and nothing but constants besides.
    private static func delegation(_ subject: Subject) -> FunctionCallExprSyntax? {
        guard subject.statements.count == 1, let call = subject.statements.first?.item.as(FunctionCallExprSyntax.self), isSelfInit(call),
              passedParameters(of: call, subject.values)?.sorted() == subject.names.sorted() else { return nil }
        return call
    }

    /// Every initialiser of the type that the call can mean is a data initialiser, and there is at least one.
    private func reachesDataInitializer(_ call: FunctionCallExprSyntax, from node: InitializerDeclSyntax,
                                        visiting: Set<SyntaxIdentifier>) -> Bool {
        guard let declared = types.initializers(ofTypeHolding: node) else { return false }
        let callees = declared.filter { $0.canBeCalled(by: call) }
        return !callees.isEmpty && callees.allSatisfy { matches($0, visiting: visiting) }
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

/// An initialiser under examination: its body, its parameters, and what a value it stores or passes may be.
private struct Subject {
    let node: InitializerDeclSyntax
    let statements: CodeBlockItemListSyntax
    let names: [String]
    let values: ConstantValue

    init?(_ node: InitializerDeclSyntax, constants: FileConstants) {
        guard let statements = node.body?.statements, !statements.isEmpty else { return nil }
        self.node = node
        self.statements = statements
        names = node.signature.parameterClause.parameters.map { ($0.secondName ?? $0.firstName).text }
        values = ConstantValue(constants: constants, parameters: Set(names))
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
