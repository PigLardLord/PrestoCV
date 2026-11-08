internal import PrestoCVDomain
import PrestoCVWorkflowPorts

/// What the editor opens: a stored CV, a blank new one, or a draft someone made that is not stored yet.
public enum EditorStart: Sendable {
    case stored(CVReference)
    case blank
    case draft(CVDraft)
}

/// A stored CV, as the list hands it to the editor. Only this target reads what it holds.
public struct CVReference: Hashable, Sendable {
    let id: CVID

    init(id: CVID) { self.id = id }
}

/// A CV made by the app and not stored yet, such as an import or an example. The editor stores it under its own identity
/// the first time it writes it; opening it stores nothing.
public struct CVDraft: Sendable {
    let cv: CV

    init(cv: CV) { self.cv = cv }
}

/// How far the editor got with opening its CV.
public enum OpeningStatus: Hashable, Sendable {
    case opening
    case open
    /// The stored CV is not in the store any more.
    case missing
    /// The store could not be read.
    case failed
}

extension OpeningStatus {
    /// Why a stored CV could not be opened.
    init(_ failure: EditFailure) {
        switch failure {
        case .deletedElsewhere: self = .missing
        case .conflict, .tooLarge, .cvTooLarge, .notEnoughContent, .textTooLong, .tooManyEntries, .unavailable: self = .failed
        }
    }
}
