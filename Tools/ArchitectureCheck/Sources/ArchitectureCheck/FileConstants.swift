import SwiftSyntax

/// What a file declares that a data initialiser may use as a constant, found without resolving any name.
struct FileConstants {
    /// The `let` declared at file level, in every `#if` branch. A `let` inside a type or a function is not one.
    let lets: Set<String>
    /// The `static var` and `class var` declared anywhere in the file: a reference by those names is not a constant.
    let mutableStatics: Set<String>

    init(_ tree: SourceFileSyntax) {
        lets = Self.lets(in: tree.statements)
        let finder = MutableStaticFinder(viewMode: .sourceAccurate)
        finder.walk(tree)
        mutableStatics = finder.names
    }

    private static func lets(in statements: CodeBlockItemListSyntax) -> Set<String> {
        statements.reduce(into: []) { names, statement in names.formUnion(lets(in: statement.item)) }
    }

    private static func lets(in item: CodeBlockItemSyntax.Item) -> Set<String> {
        if let variable = item.as(VariableDeclSyntax.self) {
            return variable.bindingSpecifier.tokenKind == .keyword(.let) ? variable.boundNames : []
        }
        guard let conditional = item.as(IfConfigDeclSyntax.self) else { return [] }
        return conditional.clauses.reduce(into: []) { names, clause in names.formUnion(lets(in: clause)) }
    }

    private static func lets(in clause: IfConfigClauseSyntax) -> Set<String> {
        guard case .statements(let statements)? = clause.elements else { return [] }
        return lets(in: statements)
    }
}

extension VariableDeclSyntax {
    /// The names that the bindings of a declaration introduce.
    var boundNames: Set<String> { Set(bindings.compactMap { $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text }) }
}
