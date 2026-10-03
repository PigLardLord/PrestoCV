/// The checks the initialisers of the model share, so a bound is written once (R8).
enum Bounds {
    static func text(_ value: String, _ field: TailoringModelError.Field) throws(TailoringModelError) {
        guard value.utf8.count <= TailoringLimits.maxTextBytes else { throw .tooLarge(field) }
    }

    static func optionalText(_ value: String?, _ field: TailoringModelError.Field) throws(TailoringModelError) {
        if let value { try text(value, field) }
    }

    /// Text that must say something: not empty once its whitespace is trimmed. The value itself is kept as written.
    static func requiredText(_ value: String, _ field: TailoringModelError.Field) throws(TailoringModelError) {
        guard value.contains(where: { !$0.isWhitespace }) else { throw .emptyField(field) }
        try text(value, field)
    }
}
