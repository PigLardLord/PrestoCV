import SwiftSyntax

// The type a contextual `.init(…)` makes (R5), read from the syntax alone: the declarations of the target that the
// pre-pass indexes, and the context of the call in its file.

/// A parameter of an initialiser, or a stored property of a struct as its memberwise initialiser takes it
struct Parameter: Hashable {
    /// The argument label; "_" when the argument has none
    let label: String
    /// The name of its type; nil for a type the check does not name, such as a tuple or a function
    let type: String?
    /// For a function type, the name of the type it returns
    let returns: String?
    /// Whether a call may leave it out: it has a default value, or it is a closure that a trailing closure may give
    let isOptional: Bool
    /// Whether it takes any number of values, `tags: String...`: none, or the first with its label and the next ones
    /// without one
    var isVariadic = false
}

/// What a type of the target declares, from every file of the target
struct TypeMembers {
    /// The declared type of each property, by name
    var properties: [String: String] = [:]
    /// Every initialiser, overloads included, as its parameters in order
    var initializers: [[Parameter]] = []
    /// The stored properties of a struct without an initialiser of its own, in order: its memberwise initialiser
    var memberwise: [Parameter]?

    /// The parameter lists a call to the type can take: its initialisers, its memberwise initialiser, or `init()`
    var signatures: [[Parameter]] {
        let all = initializers + (memberwise.map { [$0] } ?? [])
        return all.isEmpty ? [[]] : all
    }

    mutating func merge(_ other: TypeMembers) {
        properties.merge(other.properties) { first, _ in first }
        initializers += other.initializers
        memberwise = memberwise ?? other.memberwise
    }
}

enum MemberIndex {
    /// The parameter each of a call's arguments goes to, in order, when the call can take this parameter list; nil when
    /// it cannot. An argument goes to the next parameter with its label, past parameters the call may leave out; a
    /// variadic parameter takes no argument, or the one with its label and the unlabelled ones after it.
    static func match(_ labels: [String], _ parameters: [Parameter]) -> [Parameter]? {
        var matched: [Parameter] = []
        var next = labels.startIndex
        for parameter in parameters {
            guard next < labels.endIndex, labels[next] == parameter.label else {
                if parameter.isOptional || parameter.isVariadic { continue }
                return nil
            }
            repeat {
                matched.append(parameter)
                next += 1
            } while parameter.isVariadic && next < labels.endIndex && labels[next] == "_"
        }
        return next == labels.endIndex ? matched : nil
    }

    /// The labels of a call's arguments, "_" for an argument without one
    static func labels(of call: FunctionCallExprSyntax) -> [String] {
        call.arguments.map { $0.label.map(Scanner.name) ?? "_" }
    }

    /// What each type a file declares or extends declares: its properties and its initialisers
    static func members(in tree: SourceFileSyntax) -> [String: TypeMembers] {
        final class Collector: SyntaxVisitor {
            var types: [String: TypeMembers] = [:]
            override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
                let members = node.memberBlock.members.map(\.decl)
                guard !members.contains(where: { $0.is(InitializerDeclSyntax.self) }) else { return .visitChildren }
                let stored = members.compactMap { $0.as(VariableDeclSyntax.self) }.filter { variable in
                    !variable.modifiers.contains { $0.name.tokenKind == .keyword(.static) }
                }
                var memberwise: [Parameter] = []
                for variable in stored {
                    let isLet = variable.bindingSpecifier.tokenKind == .keyword(.let)
                    for binding in variable.bindings where binding.accessorBlock == nil || Collector.onlyObserves(binding.accessorBlock) {
                        guard let name = binding.pattern.as(IdentifierPatternSyntax.self).map({ Scanner.name($0.identifier) }) else { continue }
                        if isLet, binding.initializer != nil { continue }
                        let type = binding.typeAnnotation?.type
                        let isOptional = binding.initializer != nil || (!isLet && type?.is(OptionalTypeSyntax.self) == true)
                        memberwise.append(Collector.parameter(label: name, type: type, isOptional: isOptional))
                    }
                }
                types[Scanner.name(node.name), default: TypeMembers()].memberwise = memberwise
                return .visitChildren
            }
            override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
                guard let owner = Collector.owner(of: Syntax(node)) else { return .visitChildren }
                for binding in node.bindings {
                    guard let name = binding.pattern.as(IdentifierPatternSyntax.self).map({ Scanner.name($0.identifier) }),
                          let type = binding.typeAnnotation.flatMap({ Scanner.typeName($0.type) }) else { continue }
                    types[owner, default: TypeMembers()].properties[name] = type
                }
                return .visitChildren
            }
            override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
                guard let owner = Collector.owner(of: Syntax(node)) else { return .visitChildren }
                let parameters = node.signature.parameterClause.parameters.map { parameter in
                    var declared = Collector.parameter(label: Scanner.name(parameter.firstName), type: parameter.type,
                                                       isOptional: parameter.defaultValue != nil)
                    declared.isVariadic = parameter.ellipsis != nil
                    return declared
                }
                types[owner, default: TypeMembers()].initializers.append(parameters)
                return .visitChildren
            }
            static func parameter(label: String, type: TypeSyntax?, isOptional: Bool) -> Parameter {
                let function = type.flatMap(Collector.functionType)
                return Parameter(label: label, type: type.flatMap(Scanner.typeName),
                                 returns: function.flatMap { Scanner.typeName($0.returnClause.type) },
                                 isOptional: isOptional || function != nil)
            }
            static func functionType(_ type: TypeSyntax) -> FunctionTypeSyntax? {
                if let attributed = type.as(AttributedTypeSyntax.self) { return functionType(attributed.baseType) }
                return type.as(FunctionTypeSyntax.self)
            }
            /// Whether the accessors of a property only observe it (`willSet`, `didSet`): it is still stored
            static func onlyObserves(_ block: AccessorBlockSyntax?) -> Bool {
                guard case .accessors(let accessors)? = block?.accessors else { return false }
                return accessors.allSatisfy { [.keyword(.willSet), .keyword(.didSet)].contains($0.accessorSpecifier.tokenKind) }
            }
            /// The type a member is declared in, when it is a member of one and not a local of a function
            static func owner(of node: Syntax) -> String? {
                var current = node.parent
                while let n = current {
                    if n.is(CodeBlockSyntax.self) || n.is(ClosureExprSyntax.self) || n.is(AccessorBlockSyntax.self) { return nil }
                    if let d = n.as(StructDeclSyntax.self) { return Scanner.name(d.name) }
                    if let d = n.as(ClassDeclSyntax.self) { return Scanner.name(d.name) }
                    if let d = n.as(EnumDeclSyntax.self) { return Scanner.name(d.name) }
                    if let d = n.as(ActorDeclSyntax.self) { return Scanner.name(d.name) }
                    if let e = n.as(ExtensionDeclSyntax.self) { return Scanner.typeName(e.extendedType) }
                    current = n.parent
                }
                return nil
            }
        }
        let collector = Collector(viewMode: .sourceAccurate)
        collector.walk(tree)
        return collector.types
    }
}

/// A local or a parameter, with its declared type when it has one
struct Local {
    let type: String?
}

extension Scanner {
    /// The property wrappers whose `wrappedValue:` is the value of the property they wrap
    static let propertyWrappers: Set<String> = ["StateObject", "ObservedObject", "State", "Bindable"]

    /// The type the context of an expression expects, as far as the syntax tells it: the type of the argument it is
    /// passed as, of the property or local it is assigned to (through a property wrapper's `wrappedValue:`), of the value
    /// it returns, or of the binding it initialises. Nil when the syntax does not tell.
    func expectedType(of expr: ExprSyntax) -> String? {
        guard let parent = expr.parent else { return nil }
        if let argument = parent.as(LabeledExprSyntax.self), let call = argument.parent?.parent?.as(FunctionCallExprSyntax.self) {
            return expectedType(ofArgument: argument, in: call)
        }
        if let list = parent.as(ExprListSyntax.self), let sequence = list.parent?.as(SequenceExprSyntax.self) {
            return assignedType(in: sequence, value: expr)
        }
        if parent.is(ReturnStmtSyntax.self) { return returnType(around: parent) }
        if let item = parent.as(CodeBlockItemSyntax.self), let items = item.parent?.as(CodeBlockItemListSyntax.self), items.count == 1 {
            if let type = returnType(around: items) { return type }
        }
        // The value of a binding, however deep in it: `let model: ListViewModel = .init()`
        var current: Syntax? = parent
        while let n = current {
            if let binding = n.as(PatternBindingSyntax.self) { return binding.typeAnnotation.flatMap { Self.typeName($0.type) } }
            current = n.parent
        }
        return nil
    }

    /// The type of the parameter an argument is passed as: the `wrappedValue:` of a property wrapper takes the type of
    /// the property; a parameter of a type of the target is the type its initialisers declare, told apart by the labels
    /// of the call and of the argument's own `.init(…)` when they are overloaded; and a label that names a view model
    /// (`viewModel:`) is one.
    private func expectedType(ofArgument argument: LabeledExprSyntax, in call: FunctionCallExprSyntax) -> String? {
        let label = argument.label.map(Self.name) ?? "_"
        if let callee = calledType(call), Self.propertyWrappers.contains(callee), label == "wrappedValue" {
            return expectedType(of: ExprSyntax(call))
        }
        let parameters = parameters(of: argument, in: call)
        if !parameters.isEmpty { return resolve(parameters.compactMap(\.type), madeBy: argument.expression) }
        return label.lowercased().hasSuffix("viewmodel") ? "ViewModel" : nil
    }

    /// The name of the type a call constructs: `Child(…)`, `Child.init(…)`
    private func calledType(_ call: FunctionCallExprSyntax) -> String? {
        let path = Self.unqualifiedPath(call.calledExpression) ?? []
        return path.last == "init" ? path.dropLast().last : path.last
    }

    /// The parameters an argument may go to, one per initialiser of the called type that can take the call's labels
    private func parameters(of argument: LabeledExprSyntax, in call: FunctionCallExprSyntax) -> [Parameter] {
        guard let callee = calledType(call), let members = memberTypes[callee],
              let position = call.arguments.firstIndex(where: { $0.id == argument.id }) else { return [] }
        let index = call.arguments.distance(from: call.arguments.startIndex, to: position)
        let labels = MemberIndex.labels(of: call)
        return members.signatures.compactMap { MemberIndex.match(labels, $0)?[index] }
    }

    /// One type out of those that overloads allow. The `.init(…)` that makes the value tells them apart when the target
    /// declares their initialisers: a type whose initialisers cannot take its labels is not the one. A type the target
    /// does not declare stays a candidate only when no declared one fits. When the syntax cannot tell, a view model among
    /// them is assumed, so that the check errs towards R5.
    private func resolve(_ types: [String], madeBy value: ExprSyntax) -> String? {
        var candidates = Set(types)
        if candidates.count > 1, let made = value.as(FunctionCallExprSyntax.self) {
            let labels = MemberIndex.labels(of: made)
            let declared = candidates.filter { memberTypes[$0] != nil }
            let fitting = declared.filter { type in memberTypes[type]?.signatures.contains { MemberIndex.match(labels, $0) != nil } == true }
            let remaining = fitting.isEmpty ? candidates.subtracting(declared) : fitting
            if !remaining.isEmpty { candidates = remaining }
        }
        if candidates.count == 1 { return candidates.first }
        return candidates.first(where: Self.isViewModelName)
    }

    /// The declared type of what `lhs = value` assigns. A bare name is a local or a parameter when one is in scope;
    /// otherwise, and always with `self.`, it is a property of the type the assignment is in: `model`, or `_model`, the
    /// storage of a wrapped property.
    private func assignedType(in sequence: SequenceExprSyntax, value: ExprSyntax) -> String? {
        let elements = Array(sequence.elements)
        guard elements.count == 3, elements[1].is(AssignmentExprSyntax.self), elements[2].id == value.id,
              let path = Self.unqualifiedPath(elements[0]) else { return nil }
        let isQualified = path.first == "self"
        let names = isQualified ? Array(path.dropFirst()) : path
        guard names.count == 1, var property = names.first else { return nil }
        if !isQualified, let local = localDeclaration(named: property, around: Syntax(sequence)) { return local.type }
        if property.hasPrefix("_") { property.removeFirst() }
        return enclosingTypeName(of: Syntax(sequence)).flatMap { memberTypes[$0]?.properties[property] }
    }

    /// The local or parameter called `name` that is in scope at `node`, with its declared type when it has one; nil when
    /// none is, inside the function, initialiser, accessor or closure around it.
    private func localDeclaration(named name: String, around node: Syntax) -> Local? {
        var current: Syntax = node
        while let parent = current.parent {
            if let items = parent.as(CodeBlockItemListSyntax.self) {
                for item in items.prefix(while: { $0.id != current.id }).reversed() {
                    if let variable = item.item.as(VariableDeclSyntax.self),
                       let binding = variable.bindings.first(where: { $0.pattern.as(IdentifierPatternSyntax.self).map { Self.name($0.identifier) } == name }) {
                        return Local(type: binding.typeAnnotation.flatMap { Self.typeName($0.type) })
                    }
                    if let guardStmt = item.item.as(GuardStmtSyntax.self), Self.binds(name, guardStmt.conditions) { return Local(type: nil) }
                }
            }
            if let ifExpr = parent.as(IfExprSyntax.self), current.id == ifExpr.body.id, Self.binds(name, ifExpr.conditions) { return Local(type: nil) }
            if let whileStmt = parent.as(WhileStmtSyntax.self), current.id == whileStmt.body.id, Self.binds(name, whileStmt.conditions) {
                return Local(type: nil)
            }
            if let forStmt = parent.as(ForStmtSyntax.self), current.id == forStmt.body.id,
               forStmt.pattern.tokens(viewMode: .sourceAccurate).contains(where: { Self.name($0) == name }) {
                return Local(type: nil)
            }
            if let closure = parent.as(ClosureExprSyntax.self) {
                return closure.signature.flatMap { Self.closureParameter(named: name, in: $0) }
            }
            if let function = parent.as(FunctionDeclSyntax.self) { return Self.parameter(named: name, in: function.signature.parameterClause) }
            if let initializer = parent.as(InitializerDeclSyntax.self) {
                return Self.parameter(named: name, in: initializer.signature.parameterClause)
            }
            if let accessor = parent.as(AccessorDeclSyntax.self) {
                let implicit = [.keyword(.set): "newValue", .keyword(.willSet): "newValue", .keyword(.didSet): "oldValue"][accessor.accessorSpecifier.tokenKind]
                return (accessor.parameters.map { Self.name($0.name) } ?? implicit) == name ? Local(type: nil) : nil
            }
            current = parent
        }
        return nil
    }

    private static func binds(_ name: String, _ conditions: ConditionElementListSyntax) -> Bool {
        conditions.contains { element in
            element.condition.as(OptionalBindingConditionSyntax.self)?.pattern.as(IdentifierPatternSyntax.self).map { Scanner.name($0.identifier) } == name
        }
    }

    private static func parameter(named name: String, in clause: FunctionParameterClauseSyntax) -> Local? {
        clause.parameters.first { Scanner.name($0.secondName ?? $0.firstName) == name }.map { Local(type: typeName($0.type)) }
    }

    private static func closureParameter(named name: String, in signature: ClosureSignatureSyntax) -> Local? {
        switch signature.parameterClause {
        case .simpleInput(let shorthand)?:
            return shorthand.contains { Scanner.name($0.name) == name } ? Local(type: nil) : nil
        case .parameterClause(let clause)?:
            return clause.parameters.first { Scanner.name($0.secondName ?? $0.firstName) == name }.map { Local(type: $0.type.flatMap(typeName)) }
        case nil:
            return nil
        }
    }

    /// The return type of the function, getter or closure whose body is `node`, or holds the `return` that `node` is. A
    /// closure without a return clause returns what the parameter it is passed as returns.
    private func returnType(around node: some SyntaxProtocol) -> String? {
        var current = node.parent
        while let n = current {
            if let function = n.as(FunctionDeclSyntax.self) { return function.signature.returnClause.flatMap { Self.typeName($0.type) } }
            if let binding = n.as(PatternBindingSyntax.self) { return binding.typeAnnotation.flatMap { Self.typeName($0.type) } }
            if let closure = n.as(ClosureExprSyntax.self) {
                if let returnClause = closure.signature?.returnClause { return Self.typeName(returnClause.type) }
                guard let argument = closure.parent?.as(LabeledExprSyntax.self),
                      let call = argument.parent?.parent?.as(FunctionCallExprSyntax.self) else { return nil }
                return resolve(parameters(of: argument, in: call).compactMap(\.returns), madeBy: ExprSyntax(closure))
            }
            if n.is(InitializerDeclSyntax.self) { return nil }
            current = n.parent
        }
        return nil
    }

    /// The name of the type, or of the extended type, that a node is declared in
    func enclosingTypeName(of node: Syntax) -> String? {
        var current = node.parent
        while let n = current {
            if let d = n.as(StructDeclSyntax.self) { return Self.name(d.name) }
            if let d = n.as(ClassDeclSyntax.self) { return Self.name(d.name) }
            if let d = n.as(EnumDeclSyntax.self) { return Self.name(d.name) }
            if let d = n.as(ActorDeclSyntax.self) { return Self.name(d.name) }
            if let e = n.as(ExtensionDeclSyntax.self) { return Self.typeName(e.extendedType) }
            current = n.parent
        }
        return nil
    }
}
