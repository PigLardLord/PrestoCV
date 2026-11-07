internal import PrestoCVApplication
import PrestoCVWorkflowPorts

/// Where the list stands with the store, as a code the view words (R13).
public enum ListStatus: Hashable, Sendable {
    /// The store is being read.
    case loading
    case loaded
    /// The store could not be read. The rows loaded before stay.
    case failed
}

/// Where the last change of a row stands, when it did not work.
public enum RowStatus: Hashable, Sendable {
    /// Someone saved the CV elsewhere since the list read it; the list reloads and the change can be made again.
    case conflict
    /// The CV is not in the store any more; the list reloads without it.
    case gone
    /// The CV, or the text given, is above what the store accepts.
    case tooLarge
    /// The store could not do it.
    case failed
}

/// What kind of file the store could not read. The path stays inside the store (R13).
public enum StoreIssueKind: Hashable, Sendable {
    case corrupt, upgradeRequired, unreadable, tooLarge, quarantineFailed
}

/// The files the store could not read, as a count and the kind of each. One issue never hides the other CVs.
public struct StoreNotice: Hashable, Sendable {
    public let kinds: [StoreIssueKind]
    public var count: Int { kinds.count }

    public init(kinds: [StoreIssueKind]) { self.kinds = kinds }
}

extension RowStatus {
    /// Every failure of the store has its status (R7).
    init(_ failure: EditFailure) {
        switch failure {
        case .conflict: self = .conflict
        case .deletedElsewhere: self = .gone
        case .tooLarge, .cvTooLarge, .textTooLong, .tooManyEntries: self = .tooLarge
        case .notEnoughContent, .unavailable: self = .failed
        }
    }
}

extension StoreIssueKind {
    init(_ issue: StoreIssue) {
        switch issue {
        case .corrupt: self = .corrupt
        case .upgradeRequired: self = .upgradeRequired
        case .unreadable: self = .unreadable
        case .tooLarge: self = .tooLarge
        case .quarantineFailed: self = .quarantineFailed
        }
    }
}
