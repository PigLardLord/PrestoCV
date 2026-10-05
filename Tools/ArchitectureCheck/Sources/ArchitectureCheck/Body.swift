import SwiftSyntax

/// A function-like body: the statements of a function, initialiser, deinitialiser, accessor, shorthand getter or
/// closure. `name` is how a finding calls it; `line` is where the finding points.
struct Body {
    let isClosure: Bool
    let id: SyntaxIdentifier
    let name: String
    let line: Int
    let statements: CodeBlockItemListSyntax

    init?(_ node: FunctionDeclSyntax, _ lines: CodeLines) {
        guard let body = node.body else { return nil }
        self.init(isClosure: false, id: node.id, name: "func \(node.name.text)", line: lines.line(of: node.name), statements: body.statements)
    }

    init?(_ node: InitializerDeclSyntax, _ lines: CodeLines) {
        guard let body = node.body else { return nil }
        self.init(isClosure: false, id: node.id, name: "init", line: lines.line(of: node.initKeyword), statements: body.statements)
    }

    init?(_ node: DeinitializerDeclSyntax, _ lines: CodeLines) {
        guard let body = node.body else { return nil }
        self.init(isClosure: false, id: node.id, name: "deinit", line: lines.line(of: node.deinitKeyword), statements: body.statements)
    }

    init?(_ node: AccessorDeclSyntax, _ lines: CodeLines) {
        guard let body = node.body else { return nil }
        let owner = node.parent?.parent?.as(AccessorBlockSyntax.self).map(Self.ownerName) ?? "a property"
        self.init(isClosure: false, id: node.id, name: "\(node.accessorSpecifier.text) of \(owner)",
                  line: lines.line(of: node.accessorSpecifier), statements: body.statements)
    }

    /// The shorthand getter of a computed property or subscript; nil when the block lists accessors.
    init?(_ node: AccessorBlockSyntax, _ lines: CodeLines) {
        guard case .getter(let statements) = node.accessors else { return nil }
        self.init(isClosure: false, id: node.id, name: "getter of \(Self.ownerName(node))", line: lines.line(of: node.leftBrace), statements: statements)
    }

    init(_ node: ClosureExprSyntax, _ lines: CodeLines) {
        self.init(isClosure: true, id: node.id, name: "closure", line: lines.line(of: node.leftBrace), statements: node.statements)
    }

    /// The body that a node holds, if it is one of the nodes that hold one.
    static func of(_ node: Syntax, _ lines: CodeLines) -> Body? {
        switch node.kind {
        case .functionDecl: Body(node.cast(FunctionDeclSyntax.self), lines)
        case .initializerDecl: Body(node.cast(InitializerDeclSyntax.self), lines)
        case .deinitializerDecl: Body(node.cast(DeinitializerDeclSyntax.self), lines)
        case .accessorDecl: Body(node.cast(AccessorDeclSyntax.self), lines)
        case .accessorBlock: Body(node.cast(AccessorBlockSyntax.self), lines)
        case .closureExpr: Body(node.cast(ClosureExprSyntax.self), lines)
        default: nil
        }
    }

    private init(isClosure: Bool, id: SyntaxIdentifier, name: String, line: Int, statements: CodeBlockItemListSyntax) {
        self.isClosure = isClosure
        self.id = id
        self.name = name
        self.line = line
        self.statements = statements
    }

    private static func ownerName(_ block: AccessorBlockSyntax) -> String {
        if let binding = block.parent?.as(PatternBindingSyntax.self) { return binding.pattern.trimmedDescription }
        return block.parent?.is(SubscriptDeclSyntax.self) == true ? "subscript" : "a property"
    }
}
