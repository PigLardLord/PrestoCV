import SwiftSyntax

extension VariableDeclSyntax {
    /// A `static` or `class` property belongs to the type, not to an instance.
    var isTypeLevel: Bool { modifiers.contains { $0.name.text == "static" || $0.name.text == "class" } }
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
