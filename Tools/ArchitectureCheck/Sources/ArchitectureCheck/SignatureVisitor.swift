import SwiftSyntax

/// `parameterCount`: the parameters of each function and initialiser, protocol requirements included. A data
/// initialiser describes a data structure, not a behaviour, so it may take as many as the structure has.
final class SignatureVisitor: SyntaxVisitor {
    private(set) var hits: [Hit] = []
    private let lines: CodeLines
    private let dataInitializer: DataInitializer

    init(lines: CodeLines, constants: FileConstants) {
        self.lines = lines
        self.dataInitializer = DataInitializer(constants: constants)
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        check("func \(node.name.text)", node.signature.parameterClause.parameters.count, at: lines.line(of: node.name))
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        if !dataInitializer.matches(node) {
            check("init", node.signature.parameterClause.parameters.count, at: lines.line(of: node.initKeyword))
        }
        return .visitChildren
    }

    private func check(_ name: String, _ count: Int, at line: Int) {
        guard count > Limits.parameters else { return }
        hits.append(Hit(measured: "parameterCount", "\(name) takes \(count) parameters, at most \(Limits.parameters)", line: line))
    }
}
