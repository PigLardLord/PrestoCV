import PrestoCVCore

/// What an editor opens on. Each route to the editor carries its own, so nothing is left over from the editor opened
/// before it.
enum EditorRequest: Hashable, Sendable {
    /// The CV stored under this id.
    case stored(cvId: String)
    /// A CV that was never stored, starting from a template: a blank CV, an example or an AI draft, with the notice the
    /// editor shows above it.
    case new(template: CVModel, notice: EditorNotice?)
    /// Edits an earlier run of the app kept, with the claim the window took on them to restore them.
    case restoring(RestoredUnsavedEdits)

    static func == (lhs: EditorRequest, rhs: EditorRequest) -> Bool {
        switch (lhs, rhs) {
        case let (.stored(lhsId), .stored(rhsId)):
            return lhsId == rhsId
        case let (.new(lhsTemplate, lhsNotice), .new(rhsTemplate, rhsNotice)):
            return lhsTemplate == rhsTemplate && lhsNotice == rhsNotice
        case let (.restoring(lhsEdits), .restoring(rhsEdits)):
            // Each restore holds a claim of its own: two restores of the same edits are two requests
            return lhsEdits === rhsEdits
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
        case .restoring(let restored):
            hasher.combine(2)
            hasher.combine(ObjectIdentifier(restored))
        }
    }
}
