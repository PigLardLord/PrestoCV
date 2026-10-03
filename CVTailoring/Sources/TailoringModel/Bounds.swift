/// The checks the initialisers of the model share, so a bound is written once (R8).
enum Bounds {
    static func text(_ value: String, _ field: TailoringModelError.Field) throws(TailoringModelError) {
        guard value.utf8.count <= TailoringLimits.maxTextBytes else { throw .tooLarge(field) }
    }
}
