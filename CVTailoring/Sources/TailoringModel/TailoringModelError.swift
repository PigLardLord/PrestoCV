/// Why a value of the tailoring model cannot be built. Every case is a code that names the place; the wording is
/// produced at the edges (R7, R13). Nothing here carries a string.
public enum TailoringModelError: Error, Hashable, Sendable {
    /// A language tag that is none of the six (ADR 0013). It never falls back to English.
    case unsupportedLanguage
}
