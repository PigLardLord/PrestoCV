import SwiftSyntax

/// `typeLength`: the code lines of each type declaration and of each extension, measured separately. A nested type is
/// measured on its own and not counted again in the type that holds it.
final class TypeLengthVisitor: SyntaxAnyVisitor {
    private(set) var hits: [Hit] = []
    private var regions = Regions()
    private let lines: CodeLines

    init(lines: CodeLines) {
        self.lines = lines
        super.init(viewMode: .sourceAccurate)
    }

    override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
        if let declaration = TypeDeclaration(node, lines) { regions.push(declaration.region) }
        return .visitChildren
    }

    override func visitAnyPost(_ node: Syntax) {
        if TypeDeclaration(node, lines) != nil { report(regions.pop()) }
    }

    override func visit(_ token: TokenSyntax) -> SyntaxVisitorContinueKind {
        regions.add(token, counting: lines)
        return .visitChildren
    }

    private func report(_ region: Regions.Region) {
        guard region.lines.count > Limits.typeLines else { return }
        hits.append(Hit(measured: "typeLength", "\(region.name) has \(region.lines.count) lines of code, at most \(Limits.typeLines)",
                        line: region.line))
    }
}
