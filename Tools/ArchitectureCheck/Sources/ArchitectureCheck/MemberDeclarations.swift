import SwiftSyntax

extension MemberBlockItemListSyntax {
    /// The declarations of a member list, with those of every `#if` branch in place of the `#if` itself.
    var declarations: [DeclSyntax] { flatMap(\.declarations) }
}

extension MemberBlockItemSyntax {
    var declarations: [DeclSyntax] {
        guard let conditional = decl.as(IfConfigDeclSyntax.self) else { return [decl] }
        return conditional.clauses.flatMap(\.memberDeclarations)
    }
}

extension IfConfigClauseSyntax {
    /// The member declarations of a branch of a `#if` that holds members.
    var memberDeclarations: [DeclSyntax] {
        guard case .decls(let members)? = elements else { return [] }
        return members.declarations
    }
}
