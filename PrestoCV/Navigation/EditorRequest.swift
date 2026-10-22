import PrestoCVCore

/// What an editor opens on. Each route to the editor carries its own, so nothing is left over from the editor opened
/// before it.
enum EditorRequest: Hashable, Sendable {
    /// The CV stored under this id.
    case stored(cvId: String)
    /// A CV that was never stored, starting from a template: a blank CV, an example, an AI draft or a CV imported from
    /// the person's text or PDF, with the notice the editor shows above it.
    case new(template: CVModel, notice: EditorNotice?)

    /// Whether the editor stores the CV as it opens, without waiting for a change. An AI draft and an imported CV were
    /// made from what the person gave, and nothing else holds them: the system's copy of an opened PDF is deleted. A
    /// blank CV or an example is stored only once it is changed, so one left untouched leaves nothing behind.
    var storesAsItIs: Bool {
        guard case .new(_, let notice?) = self else { return false }
        switch notice {
        case .aiDraft, .imported:
            return true
        }
    }

    static func == (lhs: EditorRequest, rhs: EditorRequest) -> Bool {
        switch (lhs, rhs) {
        case let (.stored(lhsId), .stored(rhsId)):
            return lhsId == rhsId
        case let (.new(lhsTemplate, lhsNotice), .new(rhsTemplate, rhsNotice)):
            return lhsTemplate == rhsTemplate && lhsNotice == rhsNotice
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .stored(let cvId):
            hasher.combine(0)
            hasher.combine(cvId)
        case .new(let template, let notice):
            hasher.combine(1)
            hasher.combine(template.id)
            hasher.combine(notice)
        }
    }
}
