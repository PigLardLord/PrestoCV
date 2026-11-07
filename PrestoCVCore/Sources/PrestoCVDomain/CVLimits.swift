/// How much a CV can hold and still be saved (R6). A CV that is within them maps to a document the exporter's validator
/// accepts, so "can be saved" implies "can be rendered". The domain cannot import that validator (R1); a test in the
/// integration package pins these numbers to its limits, which they equal or sit below.
///
/// Nothing is ever cut: a CV above a limit, such as a stored or imported one, still opens, and saving it is refused
/// with the reason (`SaveVerdict`).
public enum CVLimits {
    /// The UTF-8 bytes of one text.
    public static let maxTextBytes = 16_384
    /// The characters of one text, the cap the stored file also keeps.
    public static let maxTextCharacters = 10_000
    /// The UTF-8 bytes of all the texts of a CV together.
    public static let maxTotalTextBytes = 262_144
    /// The entries of each section, the interests included.
    public static let maxEntriesPerSection = 200
}

/// The sections of a CV, in the order the save rule looks at them.
public enum CVSection: String, Hashable, Sendable, CaseIterable {
    case experiences, education, skills, languages, certifications, profiles, interests
}

/// A free-text field of a CV, named in the refusal of a text that is too long. The e-mail, phone and web addresses
/// have their own bounds in their value objects.
public enum CVTextField: String, Hashable, Sendable, CaseIterable {
    case title, fullName, professionalTitle, location, summary
    case experienceRole, experienceCompany, experienceLocation, experienceDescription
    case educationDegree, educationSchool, educationDescription
    case skillName, language
    case certificationName, certificationIssuer, certificationDescription
    case profilePlatform, interest
}
