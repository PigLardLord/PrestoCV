import PrestoCVCore

/// What an editor opens on. Each route to the editor carries its own, so nothing is left over from the editor opened
/// before it.
enum EditorRequest: Hashable, Sendable {
    /// The CV stored under this id.
    case stored(cvId: String)
    /// A CV that was never stored, starting from a template: a blank CV or an example. It is stored once it is changed.
    case new(template: CVModel)
    /// A CV drafted by AI from the person's description. It is stored as it is, and the editor asks the person to
    /// check it.
    case draft(CVModel)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .stored(let cvId):
            hasher.combine(0)
            hasher.combine(cvId)
        case .new(let template):
            hasher.combine(1)
            hasher.combine(template.id)
        case .draft(let cv):
            hasher.combine(2)
            hasher.combine(cv.id)
        }
    }
}
