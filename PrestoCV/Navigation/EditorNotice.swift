import Foundation

/// A message the editor shows above a new CV, set by the screen that opened it.
enum EditorNotice: Hashable {
    /// The CV was drafted by AI from the person's description and has not been reviewed yet.
    case aiDraft

    var messageKey: String {
        switch self {
        case .aiDraft: return "editor.notice.ai_draft"
        }
    }
}
