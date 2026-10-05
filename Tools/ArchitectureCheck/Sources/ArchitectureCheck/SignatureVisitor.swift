import SwiftSyntax

/// `parameterCount`: the parameters of each function and initialiser, protocol requirements included. A data
/// initialiser describes a data structure, not a behaviour, so it may take as many as the structure has.
final class SignatureVisitor: SyntaxVisitor {
    private(set) var hits: [Hit] = []
    private let lines: CodeLines
    private let dataInitializer: DataInitializer

    init(lines: CodeLines, dataInitializer: DataInitializer) {
        self.lines = lines
        self.dataInitializer = dataInitializer
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        check("func \(node.name.text)", node.signature.parameterClause.parameters.count, at: lines.line(of: node.name))
        return .visitChildren
    }

    /// The parameters are counted first, and only an initialiser over the cap is searched for a reason to be exempt.
    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let count = node.signature.parameterClause.parameters.count
        if count > Limits.parameters, !dataInitializer.matches(node) { check("init", count, at: lines.line(of: node.initKeyword)) }
        return .visitChildren
    }

    override func visitPost(_ node: SourceFileSyntax) {
        guard dataInitializer.isExhausted else { return }
        let detail = "the search for data initialisers stopped at its budget of \(dataInitializer.budget) steps, so the initialisers it did not reach count as not exempt"
        hits.append(Hit(measured: "parameterCount", detail, line: 1))
    }

    private func check(_ name: String, _ count: Int, at line: Int) {
        guard count > Limits.parameters else { return }
        hits.append(Hit(measured: "parameterCount", "\(name) takes \(count) parameters, at most \(Limits.parameters)", line: line))
    }
}
