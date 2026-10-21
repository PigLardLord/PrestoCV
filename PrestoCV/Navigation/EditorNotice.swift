import Foundation

/// A message the editor shows above a new CV, set by the screen that opened it.
enum EditorNotice: Hashable {
    /// The CV was drafted by AI from the person's description and has not been reviewed yet.
    case aiDraft
    /// The CV was read from the person's own text or PDF: the values to check and the text not imported come with it.
    case imported(ImportReview)

    var messageKey: String {
        switch self {
        case .aiDraft: return "editor.notice.ai_draft"
        case .imported: return "editor.notice.imported"
        }
    }

    /// What the person can review from the notice: the values to check and the text not imported, if there are any.
    var review: ImportReview? {
        guard case .imported(let review) = self, !review.isEmpty else { return nil }
        return review
    }
}
