/// The bounds of every snapshot (R8). A model's reply and a request on a server are untrusted, so every initialiser of
/// the model checks these. Text is measured in UTF-8 bytes.
public enum TailoringLimits {
    /// One text field, a statement included.
    public static let maxTextBytes = 10_000

    /// The entries of one section of a CV: experiences, education, skills, languages, certifications, profiles, interests,
    /// and the lines of a tailored experience.
    public static let maxEntriesPerSection = 200

    /// The statements of one experience.
    public static let maxStatementsPerExperience = 200

    /// The text of an advert.
    public static let maxAdvertBytes = 50_000

    /// The lines of a recipient's address.
    public static let maxAddressLines = 6

    /// The paragraphs of a letter's body.
    public static let maxParagraphs = 20

    /// The documents a letter lists as attached.
    public static let maxAttachments = 20

    /// A BCP 47 language tag, which is read only up to this length.
    public static let maxLanguageTagBytes = 64

    /// The statements one tailored line names as its sources.
    public static let maxSourcesPerLine = 200
}
