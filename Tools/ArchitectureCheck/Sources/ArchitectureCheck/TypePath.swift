import SwiftSyntax

/// The full name of a type in its file, such as `Outer.Inner`: the types around its declaration, or the path an extension
/// names. A type declared where nothing else can name it, such as inside a function, has none.
enum TypePath {
    static func of(_ group: any DeclGroupSyntax) -> String? {
        components(of: group)?.joined(separator: ".")
    }

    private static func components(of group: any DeclGroupSyntax) -> [String]? {
        guard let own = ownComponents(of: group) else { return nil }
        switch enclosing(Syntax(group)) {
        case .file: return own
        case .local: return nil
        case .type(let outer): return outer + own
        }
    }

    /// What a declaration sits in: the file, a body that only it can see, or another type.
    private enum Scope {
        case file, local
        case type([String])
    }

    private static func enclosing(_ node: Syntax) -> Scope {
        var current = node.parent
        while let ancestor = current {
            if let group = ancestor.asProtocol((any DeclGroupSyntax).self) { return components(of: group).map(Scope.type) ?? .local }
            if isBody(ancestor) { return .local }
            current = ancestor.parent
        }
        return .file
    }

    private static func isBody(_ node: Syntax) -> Bool {
        [.codeBlock, .closureExpr, .accessorBlock, .accessorDecl].contains(node.kind)
    }

    /// The name of a type, or the path that an extension extends.
    private static func ownComponents(of group: any DeclGroupSyntax) -> [String]? {
        if let named = group as? any NamedDeclSyntax { return [named.name.text] }
        return (group as? ExtensionDeclSyntax).flatMap { path(of: $0.extendedType) }
    }

    private static func path(of type: TypeSyntax) -> [String]? {
        if let identifier = type.as(IdentifierTypeSyntax.self) { return [identifier.name.text] }
        guard let member = type.as(MemberTypeSyntax.self) else { return nil }
        return path(of: member.baseType).map { $0 + [member.name.text] }
    }
}
