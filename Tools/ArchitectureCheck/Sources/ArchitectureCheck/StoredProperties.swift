import SwiftSyntax

/// A property a type declares, and whether assigning it only stores.
struct Property {
    let name: String
    let isStored: Bool
}

extension VariableDeclSyntax {
    /// A `static` or `class` property belongs to the type, not to an instance.
    var isTypeLevel: Bool { modifiers.contains { $0.name.text == "static" || $0.name.text == "class" } }

    /// The properties of the declaration. A property with an attribute is not stored, whatever the attribute: a property
    /// wrapper runs code on every assignment, a macro can rewrite the property, and syntax cannot tell either from
    /// `@MainActor` or any other attribute.
    var properties: [Property] {
        bindings.compactMap { binding in binding.propertyName.map { Property(name: $0, isStored: attributes.isEmpty && binding.isStored) } }
    }
}

extension PatternBindingSyntax {
    /// The name that the binding introduces, for a binding of one name.
    var propertyName: String? { pattern.as(IdentifierPatternSyntax.self)?.identifier.text }

    /// A stored property has no accessor besides observers. A type's own observers do not run in its initialisers, so a
    /// property with `willSet` or `didSet` stores like any other.
    var isStored: Bool {
        guard let block = accessorBlock else { return true }
        guard case .accessors(let accessors) = block.accessors else { return false }
        return accessors.allSatisfy { ["willSet", "didSet"].contains($0.accessorSpecifier.text) }
    }
}
