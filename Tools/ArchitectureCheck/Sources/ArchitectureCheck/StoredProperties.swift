import SwiftSyntax

/// A property a type declares, and what every initialiser runs for it.
struct Property {
    let name: String
    private let isComputed: Bool
    private let hasAttribute: Bool
    /// The initial value that runs in every initialiser: none for a property without one, and none for a lazy one, which
    /// runs its initial value when it is first used and not in the initialiser.
    private let initialValue: ExprSyntax?

    init(_ binding: PatternBindingSyntax, of variable: VariableDeclSyntax) {
        name = binding.propertyName ?? binding.pattern.trimmedDescription
        isComputed = binding.isComputed
        hasAttribute = !variable.attributes.isEmpty
        initialValue = variable.isLazy ? nil : binding.initializer?.value
    }

    /// Assigning it only stores. A property with an attribute is not stored, whatever the attribute: a property wrapper runs
    /// code on every assignment, a macro can rewrite the property, and syntax cannot tell either from `@MainActor` or any
    /// other attribute.
    var isStored: Bool { !isComputed && !hasAttribute }

    /// Whether an initialiser runs nothing for it, whether it assigns it or not: a computed property has nothing to start, and a
    /// stored one starts with its initial value, before the body of the initialiser, which has to be a literal or a constant, and
    /// a wrapper runs code to start.
    func runsNothing(under values: ConstantValue) -> Bool {
        isComputed || (!hasAttribute && initialValue.map { values.accepts($0) } ?? true)
    }
}

extension Array where Element == Property {
    /// The names that assigning only stores: a name that any declaration makes computed is not one.
    var storedNames: Set<String> {
        Set(filter(\.isStored).map(\.name)).subtracting(filter { !$0.isStored }.map(\.name))
    }
}

extension VariableDeclSyntax {
    /// A `static` or `class` property belongs to the type, not to an instance.
    var isTypeLevel: Bool { modifiers.contains { $0.name.text == "static" || $0.name.text == "class" } }

    var isLazy: Bool { modifiers.contains { $0.name.text == "lazy" } }

    var properties: [Property] { bindings.map { Property($0, of: self) } }
}

extension PatternBindingSyntax {
    /// The name that the binding introduces, for a binding of one name.
    var propertyName: String? { pattern.as(IdentifierPatternSyntax.self)?.identifier.text }

    /// A computed property has an accessor besides observers. A type's own observers do not run in its initialisers, so a
    /// property with `willSet` or `didSet` stores like any other.
    var isComputed: Bool {
        guard let block = accessorBlock else { return false }
        guard case .accessors(let accessors) = block.accessors else { return true }
        return !accessors.allSatisfy { ["willSet", "didSet"].contains($0.accessorSpecifier.text) }
    }
}
