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

extension EditorSection {
    /// The key of the question that is asked before a row of this kind is deleted.
    var deleteConfirmationTitleKey: String {
        switch self {
        case .skills: return "editor.delete_row.title.skill"
        case .experience: return "editor.delete_row.title.experience"
        case .education: return "editor.delete_row.title.education"
        case .languages: return "editor.delete_row.title.language"
        case .certifications: return "editor.delete_row.title.certification"
        case .social: return "editor.delete_row.title.social_link"
        case .interests: return "editor.delete_row.title.interest"
        }
    }

    /// The question that is asked before a row of this kind is deleted: "Delete this certification?"
    var deleteConfirmationTitle: String {
        deleteConfirmationTitleKey.localized
    }
}

/// A row that waits for the user to confirm that it can go. There is no undo, so a row with content is never deleted unasked.
struct PendingDeletion: Equatable {
    let section: EditorSection
    let index: Int
    /// How the row is called in the confirmation.
    let rowName: String
    /// Which row was asked about. The index alone is not enough to name it: once a row is gone, the next one takes its place.
    let rowIdentity: AnyHashable

    /// The question of the confirmation, which names the kind of row.
    var title: String {
        section.deleteConfirmationTitle
    }

    /// What the confirmation says about the row.
    var message: String {
        "editor.delete_row.message".localizedWithArgs(rowName)
    }
}
