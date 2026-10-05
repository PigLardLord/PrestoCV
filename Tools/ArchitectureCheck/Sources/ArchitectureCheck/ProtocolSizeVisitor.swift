import SwiftSyntax

/// `protocolSize`: the requirements a protocol declares: functions, variables, subscripts, initialisers and
/// associated types, in every `#if` branch. What it inherits is not counted.
final class ProtocolSizeVisitor: SyntaxVisitor {
    private(set) var hits: [Hit] = []
    private let lines: CodeLines

    init(lines: CodeLines) {
        self.lines = lines
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        let count = Self.requirements(in: node.memberBlock.members)
        if count > Limits.protocolRequirements {
            hits.append(Hit(measured: "protocolSize", "protocol \(node.name.text) declares \(count) requirements, at most \(Limits.protocolRequirements)",
                            line: lines.line(of: node.name)))
        }
        return .visitChildren
    }

    private static func requirements(in members: MemberBlockItemListSyntax) -> Int {
        members.reduce(0) { $0 + requirements(of: $1.decl) }
    }

    private static func requirements(of decl: DeclSyntax) -> Int {
        if let variable = decl.as(VariableDeclSyntax.self) { return variable.bindings.count }
        if let conditional = decl.as(IfConfigDeclSyntax.self) { return conditional.clauses.reduce(0) { $0 + requirements(in: $1) } }
        return isRequirement(decl) ? 1 : 0
    }

    private static func isRequirement(_ decl: DeclSyntax) -> Bool {
        decl.is(FunctionDeclSyntax.self) || decl.is(InitializerDeclSyntax.self)
            || decl.is(SubscriptDeclSyntax.self) || decl.is(AssociatedTypeDeclSyntax.self)
    }

    private static func requirements(in clause: IfConfigClauseSyntax) -> Int {
        guard case .decls(let members)? = clause.elements else { return 0 }
        return requirements(in: members)
    }
}
