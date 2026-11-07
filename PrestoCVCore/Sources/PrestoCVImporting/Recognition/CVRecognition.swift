// MARK: - A text that is already a CV

/// Whether a text is already a CV, read from what its import filled (ADR 0034). A text given to the AI draft that is
/// one is read by the import, as written, and is not sent to a model. It is one when the import filled at least
/// `minimumSections` of the sections a CV has, under their headings, and dated at least `minimumDatedEntries` of its
/// jobs and studies. Headings alone are a list in a description, and a year alone is in every description: only a text
/// with both structure and history is a CV. A CV with no date at all is not one, and goes to the AI draft.
public enum CVRecognition {

    /// The sections, of the seven `sections(of:)` counts, that a CV fills.
    public static let minimumSections = 2

    /// The jobs and studies with a period that a CV has.
    public static let minimumDatedEntries = 1

    public static func isAlreadyACV(_ cv: ImportedCV) -> Bool {
        sections(of: cv) >= minimumSections && datedEntries(of: cv) >= minimumDatedEntries
    }

    /// The sections the import filled: the summary under a heading, the experience, the education, the skills, the
    /// languages, the certifications and the interests. The head of the CV, its name, title and contacts, is none.
    static func sections(of cv: ImportedCV) -> Int {
        let filled = [
            cv.person.summary.map { $0.check != .summaryWithoutHeading } ?? false,
            !cv.experience.isEmpty,
            !cv.education.isEmpty,
            !cv.skills.isEmpty,
            !cv.languages.isEmpty,
            !cv.certifications.isEmpty,
            !cv.interests.isEmpty,
        ]
        return filled.filter { $0 }.count
    }

    /// The jobs and studies the import read a period for.
    static func datedEntries(of cv: ImportedCV) -> Int {
        cv.experience.filter { $0.period != nil }.count + cv.education.filter { $0.period != nil }.count
    }
}
