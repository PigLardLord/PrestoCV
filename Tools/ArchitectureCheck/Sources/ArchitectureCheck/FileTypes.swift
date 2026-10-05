import SwiftSyntax

/// The types a file declares, found by name and nothing else resolved: a type and its extensions in the file are one
/// type. A data initialiser has to find, here, the stored properties it assigns and the initialisers it delegates to
/// (ADR 0021 (c)); one that cannot is not exempt.
struct FileTypes {
    private let groups: [String: [any DeclGroupSyntax]]

    init(_ tree: SourceFileSyntax) {
        let collector = DeclarationCollector(viewMode: .sourceAccurate)
        collector.walk(tree)
        groups = Dictionary(grouping: collector.declarations) { Self.name(of: $0) ?? "" }
    }

    /// The instance properties that the type holding an initialiser stores; nil when the file does not declare the type.
    func storedProperties(ofTypeHolding initializer: InitializerDeclSyntax) -> Set<String>? {
        guard let declarations = declarations(ofTypeHolding: initializer) else { return nil }
        let properties = declarations.flatMap { Self.instanceProperties(of: $0) }
        let computed = Set(properties.filter { !$0.isStored }.map(\.name))
        return Set(properties.filter(\.isStored).map(\.name)).subtracting(computed)
    }

    /// The initialisers that the type holding an initialiser declares, in the type and in its extensions in the file;
    /// nil when the file does not declare the type.
    func initializers(ofTypeHolding initializer: InitializerDeclSyntax) -> [InitializerDeclSyntax]? {
        declarations(ofTypeHolding: initializer)?.flatMap { $0.memberBlock.members.declarations.compactMap { $0.as(InitializerDeclSyntax.self) } }
    }

    /// The declaration of the type that holds a member, and its extensions in the file.
    private func declarations(ofTypeHolding member: some SyntaxProtocol) -> [any DeclGroupSyntax]? {
        guard let holder = Self.holder(of: member), let name = Self.name(of: holder), let all = groups[name],
              all.contains(where: Self.isDeclaration) else { return nil }
        return all
    }

    private static func holder(of member: some SyntaxProtocol) -> (any DeclGroupSyntax)? {
        var current = Syntax(member).parent
        while let node = current {
            if let group = node.asProtocol((any DeclGroupSyntax).self) { return group }
            current = node.parent
        }
        return nil
    }

    /// A struct, class, enum or actor, as against an extension or a protocol.
    private static func isDeclaration(_ group: any DeclGroupSyntax) -> Bool {
        !(group is ExtensionDeclSyntax) && !(group is ProtocolDeclSyntax)
    }

    private static func instanceProperties(of group: any DeclGroupSyntax) -> [Property] {
        group.memberBlock.members.declarations.compactMap { $0.as(VariableDeclSyntax.self) }.filter { !$0.isTypeLevel }.flatMap(\.properties)
    }

    /// The simple name of a type, or of the type that an extension extends.
    private static func name(of group: any DeclGroupSyntax) -> String? {
        if let named = group as? any NamedDeclSyntax { return named.name.text }
        guard let type = (group as? ExtensionDeclSyntax)?.extendedType else { return nil }
        return type.as(IdentifierTypeSyntax.self)?.name.text ?? type.as(MemberTypeSyntax.self)?.name.text
    }
}

private final class DeclarationCollector: SyntaxAnyVisitor {
    private(set) var declarations: [any DeclGroupSyntax] = []

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        if let group = node.asProtocol((any DeclGroupSyntax).self) { declarations.append(group) }
        return .visitChildren
    }
}
