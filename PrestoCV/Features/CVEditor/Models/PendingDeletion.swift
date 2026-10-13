/// The parts of a CV that the editor lists row by row.
enum EditorSection: CaseIterable {
    case skills
    case experience
    case education
    case languages
    case certifications
    case social
    case interests
}

/// A row that waits for the user to confirm that it can go. There is no undo, so a row with content is never deleted unasked.
struct PendingDeletion: Equatable {
    let section: EditorSection
    let index: Int
    /// How the row is called in the confirmation.
    let rowName: String
}
