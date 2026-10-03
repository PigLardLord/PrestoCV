/// The bounds of every snapshot (R8). A model's reply and a request on a server are untrusted, so every initialiser of
/// the model checks these. Text is measured in UTF-8 bytes.
public enum TailoringLimits {
    /// One text field, a statement included.
    public static let maxTextBytes = 10_000

    /// The entries of one section of a CV: experiences, education, skills, languages, certifications, profiles, interests.
    public static let maxEntriesPerSection = 200

    /// The statements of one experience.
    public static let maxStatementsPerExperience = 200
}
