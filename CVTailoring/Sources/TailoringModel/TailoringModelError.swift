/// Why a value of the tailoring model cannot be built. Every case is a code that names the place; the wording is
/// produced at the edges (R7, R13). Nothing here carries a string.
public enum TailoringModelError: Error, Hashable, Sendable {
    /// A language tag that is none of the six (ADR 0013). It never falls back to English.
    case unsupportedLanguage
    /// A field that must say something is empty, or only whitespace.
    case emptyField(Field)
    /// A field longer than `TailoringLimits.maxTextBytes`, or an advert longer than `TailoringLimits.maxAdvertBytes` (R8).
    case tooLarge(Field)
    /// A year outside 1900 to 2200, or a month outside 1 to 12.
    case invalidDate
    /// A period that ends before it starts.
    case invalidPeriod

    /// The text fields of the model, by what they hold, not by which type holds them.
    public enum Field: Hashable, Sendable {
        case statement
    }
}
