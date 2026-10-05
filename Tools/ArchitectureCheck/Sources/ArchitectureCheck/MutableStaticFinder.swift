import SwiftSyntax

/// The names of the `static var` and `class var` a file declares.
final class MutableStaticFinder: SyntaxVisitor {
    private(set) var names: Set<String> = []

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let isTypeLevel = node.modifiers.contains { $0.name.text == "static" || $0.name.text == "class" }
        if isTypeLevel, node.bindingSpecifier.tokenKind == .keyword(.var) {
            names.formUnion(node.boundNames)
        }
        return .visitChildren
    }
}
