import SwiftSyntax

/// `typeLength`: the code lines of each type declaration and of each extension, measured separately. A nested type is
/// measured on its own and not counted again in the type that holds it.
final class TypeLengthVisitor: SyntaxVisitor {
    private(set) var hits: [Hit] = []
    private var regions = Regions()
    private let lines: CodeLines

    init(lines: CodeLines) {
        self.lines = lines
        super.init(viewMode: .sourceAccurate)
    }

    private func enter(_ node: some DeclGroupSyntax, _ name: String) -> SyntaxVisitorContinueKind {
        let members = node.memberBlock.members
        regions.open(Regions.Region(name: name, line: lines.line(of: node.introducer), range: members.position..<members.endPosition))
        return .visitChildren
    }

    private func leave() {
        let region = regions.close()
        guard region.lines.count > Limits.typeLines else { return }
        hits.append(Hit(measured: "typeLength", "\(region.name) has \(region.lines.count) lines of code, at most \(Limits.typeLines)",
                        line: region.line))
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { enter(node, "struct \(node.name.text)") }
    override func visitPost(_ node: StructDeclSyntax) { leave() }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { enter(node, "class \(node.name.text)") }
    override func visitPost(_ node: ClassDeclSyntax) { leave() }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { enter(node, "enum \(node.name.text)") }
    override func visitPost(_ node: EnumDeclSyntax) { leave() }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind { enter(node, "actor \(node.name.text)") }
    override func visitPost(_ node: ActorDeclSyntax) { leave() }
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind { enter(node, "protocol \(node.name.text)") }
    override func visitPost(_ node: ProtocolDeclSyntax) { leave() }
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind { enter(node, "extension \(node.extendedType.trimmedDescription)") }
    override func visitPost(_ node: ExtensionDeclSyntax) { leave() }

    override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        if let span = lines.span(of: token) { regions.add(span, at: token.positionAfterSkippingLeadingTrivia) }
        return .visitChildren
    }
}

/// `fileLength`: the code lines of the whole file, all types and extensions together.
enum FileLength {
    static func hits(of tree: SourceFileSyntax, lines: CodeLines) -> [Hit] {
        let count = lines.count(in: tree)
        guard count > Limits.fileLines else { return [] }
        return [Hit(measured: "fileLength", "the file has \(count) lines of code, at most \(Limits.fileLines)", line: 1)]
    }
}

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
