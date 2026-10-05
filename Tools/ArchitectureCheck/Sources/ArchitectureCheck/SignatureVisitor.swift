import SwiftSyntax

/// `parameterCount`: the parameters of each function and initialiser, protocol requirements included. A data
/// initialiser describes a data structure, not a behaviour, so it may take as many as the structure has.
final class SignatureVisitor: SyntaxVisitor {
    private(set) var hits: [Hit] = []
    private let lines: CodeLines

    init(lines: CodeLines) {
        self.lines = lines
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        check("func \(node.name.text)", node.signature.parameterClause.parameters.count, at: lines.line(of: node.name))
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        if !DataInitializer.matches(node) {
            check("init", node.signature.parameterClause.parameters.count, at: lines.line(of: node.initKeyword))
        }
        return .visitChildren
    }

    private func check(_ name: String, _ count: Int, at line: Int) {
        guard count > Limits.parameters else { return }
        hits.append(Hit(measured: "parameterCount", "\(name) takes \(count) parameters, at most \(Limits.parameters)", line: line))
    }
}

/// An initialiser that only stores its parameters: each parameter is assigned to the stored property of the same name
/// (`self.x = x`), or all of them are passed unchanged to another initialiser of the type (`self.init(x: x, y: y)`).
enum DataInitializer {
    static func matches(_ node: InitializerDeclSyntax) -> Bool {
        guard let statements = node.body?.statements, !statements.isEmpty else { return false }
        let parameters = node.signature.parameterClause.parameters.map { ($0.secondName ?? $0.firstName).text }.sorted()
        return assignedNames(statements)?.sorted() == parameters || delegatedNames(statements)?.sorted() == parameters
    }

    /// The names of the `self.name = name` statements; nil unless every statement is one.
    private static func assignedNames(_ statements: CodeBlockItemListSyntax) -> [String]? {
        let names = statements.compactMap { assignedName($0.item) }
        return names.count == statements.count ? names : nil
    }

    private static func assignedName(_ item: CodeBlockItemSyntax.Item) -> String? {
        guard let sequence = item.as(SequenceExprSyntax.self), sequence.elements.count == 3 else { return nil }
        let parts = Array(sequence.elements)
        guard let target = parts[0].as(MemberAccessExprSyntax.self), target.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "self",
              parts[1].is(AssignmentExprSyntax.self), let source = parts[2].as(DeclReferenceExprSyntax.self),
              target.declName.baseName.text == source.baseName.text else { return nil }
        return source.baseName.text
    }

    /// The names passed by a lone `self.init(...)`; nil unless it is the only statement and passes nothing but parameters.
    private static func delegatedNames(_ statements: CodeBlockItemListSyntax) -> [String]? {
        guard statements.count == 1, let call = statements.first?.item.as(FunctionCallExprSyntax.self),
              let callee = call.calledExpression.as(MemberAccessExprSyntax.self), callee.declName.baseName.text == "init",
              callee.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "self" else { return nil }
        let names = call.arguments.compactMap { $0.expression.as(DeclReferenceExprSyntax.self)?.baseName.text }
        return names.count == call.arguments.count ? names : nil
    }
}
