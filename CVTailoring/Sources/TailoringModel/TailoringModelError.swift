/// Why a value of the tailoring model cannot be built. Every case is a code that names the place; the wording is
/// produced at the edges (R7, R13). Nothing here carries a string.
public enum TailoringModelError: Error, Hashable, Sendable {
    /// A language tag that is none of the six (ADR 0013). It never falls back to English.
    case unsupportedLanguage
    /// A field that must say something is empty, or only whitespace.
    case emptyField(Field)
    /// A field longer than `TailoringLimits.maxTextBytes`, or an advert longer than `TailoringLimits.maxAdvertBytes` (R8).
    case tooLarge(Field)
    /// A section with more entries than `TailoringLimits` allows (R8).
    case tooMany(Collection)
    /// A skill level outside 1 to 5.
    case invalidSkillLevel
    /// A reference to an experience or a statement the snapshot does not have.
    case referenceOutOfRange
    /// A year outside 1900 to 2200, or a month outside 1 to 12.
    case invalidDate
    /// A period that ends before it starts.
    case invalidPeriod

    /// The text fields of the model, by what they hold, not by which type holds them.
    public enum Field: Hashable, Sendable {
        case fullName, professionalTitle, email, phone, location, website
        case skillName, languageName, platform, link
        case degree, school, certificationName, issuer, description
        case role, company, statement
        case summary, interest
    }

    /// The lists of the model, by what they hold, not by which type holds them.
    public enum Collection: Hashable, Sendable {
        case experiences, education, skills, languages, certifications, profiles, interests
        case statements
    }
}
