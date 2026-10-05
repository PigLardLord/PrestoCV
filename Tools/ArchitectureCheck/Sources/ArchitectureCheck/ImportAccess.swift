/// The access that an import of a module must have in a target (`requiredImportAccess`). `internal` means that the import
/// is `internal`, `fileprivate` or `private`, so that no type of the module appears in the target's public API.
enum ImportAccess: String, ClosedSet {
    case `internal`

    static let subject = "import access"
}
