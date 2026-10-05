import SwiftSyntax

/// A struct, class, enum, actor, protocol or extension, with the region of its member list.
struct TypeDeclaration {
    let region: Regions.Region

    init?(_ node: Syntax, _ lines: CodeLines) {
        guard let declaration = node.asProtocol((any DeclGroupSyntax).self), let subject = Self.subject(of: declaration) else { return nil }
        let members = declaration.memberBlock.members
        region = Regions.Region(name: "\(declaration.introducer.text) \(subject)", line: lines.line(of: declaration.introducer),
                                range: members.position..<members.endPosition)
    }

    /// The name of a type, or the type that an extension extends.
    private static func subject(of declaration: any DeclGroupSyntax) -> String? {
        if let named = declaration as? any NamedDeclSyntax { return named.name.text }
        return (declaration as? ExtensionDeclSyntax)?.extendedType.trimmedDescription
    }
}
