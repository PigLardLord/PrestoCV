import Foundation

/// A message the editor shows above a new CV, set by the screen that opened it.
enum EditorNotice: Hashable {
    /// The CV was drafted by AI from the person's description and has not been reviewed yet.
    case aiDraft
    /// The CV was drafted by AI, but the claim check gave no answer, so its skills, languages, interests, headline title and
    /// place were left blank for the person to add (ADR 0028).
    case aiDraftUnchecked
    /// The CV was read from the person's own text or PDF: the values to check and the text not imported come with it.
    case imported(ImportReview)
    /// A text given to the AI screen was already a CV, so the import read it as written instead of the AI drafting it
    /// (ADR 0034): the notice says so, then what any import says, and leads to the same review.
    case importedDescription(ImportReview)

    /// The lines of the message, in the order shown.
    var messageKeys: [String] {
        switch self {
        case .aiDraft: return ["editor.notice.ai_draft"]
        case .aiDraftUnchecked: return ["editor.notice.ai_draft", "editor.notice.ai_draft.unchecked"]
        case .imported: return ["editor.notice.imported"]
        case .importedDescription: return ["editor.notice.imported.from_description", "editor.notice.imported"]
        }
    }

    /// The SF Symbol shown before the message.
    var iconName: String {
        switch self {
        case .aiDraft, .aiDraftUnchecked: return "sparkles"
        case .imported, .importedDescription: return "doc.on.clipboard"
        }
    }

    /// What the person can review from the notice: the values to check and the text not imported, if there are any.
    var review: ImportReview? {
        switch self {
        case .aiDraft, .aiDraftUnchecked:
            return nil
        case .imported(let review), .importedDescription(let review):
            return review.isEmpty ? nil : review
        }
    }
}
