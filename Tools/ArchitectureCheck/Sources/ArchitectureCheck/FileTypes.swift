import SwiftSyntax

/// The types a file declares, found by their full path (`Outer.Inner`), and nothing else resolved: a type and the extensions
/// in the file that name its path are one type. A data initialiser has to find, here, the stored properties it assigns and
/// the initialisers it delegates to (ADR 0021 (c)); one that cannot is not exempt. A path that no single declaration
/// answers, because there is none in the file or because the branches of a `#if` declare it twice, finds nothing.
struct FileTypes {
    private let groups: [String: [any DeclGroupSyntax]]

    init(_ tree: SourceFileSyntax) {
        let collector = DeclarationCollector(viewMode: .sourceAccurate)
        collector.walk(tree)
        groups = collector.declarations.reduce(into: [:]) { result, group in
            if let path = TypePath.of(group) { result[path, default: []].append(group) }
        }
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

    /// The one declaration of the type that holds a member, and the extensions of its path in the file.
    private func declarations(ofTypeHolding member: some SyntaxProtocol) -> [any DeclGroupSyntax]? {
        guard let holder = Self.holder(of: member) else { return nil }
        guard let path = TypePath.of(holder) else { return Self.isDeclaration(holder) ? [holder] : nil }
        return declarations(at: path)
    }

    private func declarations(at path: String) -> [any DeclGroupSyntax]? {
        guard let all = groups[path], all.filter(Self.isDeclaration).count == 1 else { return nil }
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
}

private final class DeclarationCollector: SyntaxAnyVisitor {
    private(set) var declarations: [any DeclGroupSyntax] = []

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        if let group = node.asProtocol((any DeclGroupSyntax).self) { declarations.append(group) }
        return .visitChildren
    }
}
