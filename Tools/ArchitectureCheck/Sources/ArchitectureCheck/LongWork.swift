import SwiftSyntax

/// One entry of `longWorkCalls` (R19m): a call that blocks its thread for a time that grows with the person's data or waits
/// on the outside world. The entry is written like a Swift function reference, with the labels the call starts with:
///
///   `Data(contentsOf:)`        a constructor or a free function, bare or module-qualified (`Foundation.Data(…)`, `Data.init(…)`)
///   `Thread.sleep()`           a call of a member of a named type: the path, after the module qualifiers, is `Thread.sleep`
///   `.removeItem(at:)`         a call of a member of any value (`manager.removeItem(at:)`, `FileManager.default.removeItem(at:)`)
///
/// The labels are the leading labels of the call, `_` for an argument without one; `()` matches any arguments.
struct LongWorkCall: Equatable {
    let text: String
    /// The type path in front of the name; empty for a free function, a constructor or a member of any value.
    let qualifier: [String]
    let name: String
    let anyBase: Bool
    let labels: [String]

    /// Nil when the entry is not of one of the forms above.
    init?(_ text: String) {
        guard let open = text.firstIndex(of: "("), text.hasSuffix(")") else { return nil }
        let inner = text[text.index(after: open)..<text.index(before: text.endIndex)]
        guard inner.isEmpty || inner.hasSuffix(":") else { return nil }
        let labels = inner.isEmpty ? [] : inner.dropLast().split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard !labels.contains(where: \.isEmpty) else { return nil }
        var head = text[..<open]
        let anyBase = head.hasPrefix(".")
        if anyBase { head = head.dropFirst() }
        let parts = head.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard !parts.contains(where: \.isEmpty), !anyBase || parts.count == 1 else { return nil }
        self.text = text
        self.qualifier = Array(parts.dropLast())
        self.name = parts[parts.count - 1]
        self.anyBase = anyBase
        self.labels = labels
    }

    func matches(_ call: FunctionCallExprSyntax) -> Bool {
        let arguments = Array(call.arguments)
        guard arguments.count >= labels.count,
              zip(arguments, labels).allSatisfy({ ($0.label?.text ?? "_") == $1 }) else { return false }
        if anyBase {
            guard let access = call.calledExpression.as(MemberAccessExprSyntax.self), access.base != nil else { return false }
            return Scanner.name(access.declName.baseName) == name
        }
        guard var path = Scanner.unqualifiedPath(call.calledExpression) else { return false }
        if path.count >= 2, path.last == "init" { path.removeLast() }
        return path == qualifier + [name]
    }
}

/// What the files of one target declare that R19 needs from all of them: the actors (an extension of one is part of it) and
/// the global actors, which isolate what they annotate like an actor.
struct ConcurrencyIndex {
    var actors: Set<String> = []
    var globalActors: Set<String> = ["MainActor"]

    static func collect(in tree: SourceFileSyntax) -> ConcurrencyIndex {
        final class Collector: SyntaxVisitor {
            var index = ConcurrencyIndex()
            func globalActor(_ name: TokenSyntax, _ attributes: AttributeListSyntax) {
                if attributes.contains(where: { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "globalActor" }) {
                    index.globalActors.insert(Scanner.name(name))
                }
            }
            override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
                index.actors.insert(Scanner.name(node.name)); globalActor(node.name, node.attributes); return .visitChildren
            }
            override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind { globalActor(node.name, node.attributes); return .visitChildren }
            override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind { globalActor(node.name, node.attributes); return .visitChildren }
            override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind { globalActor(node.name, node.attributes); return .visitChildren }
        }
        let collector = Collector(viewMode: .sourceAccurate)
        collector.walk(tree)
        return collector.index
    }

    mutating func merge(_ other: ConcurrencyIndex) {
        actors.formUnion(other.actors)
        globalActors.formUnion(other.globalActors)
    }
}
