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
    /// Each kind once, in the order the store met them: the view words one line per kind.
    public var distinctKinds: [StoreIssueKind] {
        kinds.reduce(into: []) { seen, kind in
            if !seen.contains(kind) { seen.append(kind) }
        }
    }

    public init(kinds: [StoreIssueKind]) { self.kinds = kinds }
}

/// What the list column shows in place of its rows.
public enum ListContent: Hashable, Sendable {
    /// The first read has not ended.
    case loading
    /// The store holds no CV: the ways to start show.
    case empty
    /// The rows, none when the store could not be read (a notice says so).
    case rows
}

/// A notice above the rows, in the order the view shows them.
public enum ListNotice: Hashable, Sendable {
    /// A change was stored and the list could not be read again: the rows may be out of date.
    case stale
    /// The store could not be read.
    case failed
    /// Files the store could not read, until the person dismisses it.
    case unreadable(StoreNotice)
    /// A row whose last change did not work, until the person dismisses it.
    case rowFailure(RowFailure)
}

/// What the person can do to a row. The menu and the actions of VoiceOver offer each; a swipe offers some of them.
public enum RowAction: Hashable, Sendable {
    case duplicate, rename, delete
}

/// The row whose last change did not work, named by its label. The number tells this failure from a newer one of the same
/// row, so that dismissing the older notice leaves the newer one.
public struct RowFailure: Hashable, Sendable {
    public let reference: CVReference
    public let label: String
    public let status: RowStatus
    public let number: Int
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
