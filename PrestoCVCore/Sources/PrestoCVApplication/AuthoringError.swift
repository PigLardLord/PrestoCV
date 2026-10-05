/// What presentation needs to know about a failed use case, without the shape of the port's errors (CleanErrors).
public enum AuthoringError: Error, Equatable, Sendable {
    /// The CV has no content to save yet.
    case notEnoughContent
    /// Another window or process changed the CV first; `storedRevision` is the revision now stored.
    case conflict(storedRevision: Int)
    /// The CV is no longer in the store.
    case deletedElsewhere
    /// The CV is too large to be stored.
    case tooLarge
    /// The store cannot be used, for a reason the user cannot act on from the editor.
    case unavailable
}

extension AuthoringError {
    /// The one place a repository's error is translated for presentation. What the user can act on keeps its own case;
    /// every other failure is `unavailable`.
    init(_ error: RepositoryError) {
        switch error {
        case .conflict(_, let storedRevision): self = .conflict(storedRevision: storedRevision)
        case .notFound: self = .deletedElsewhere
        case .wouldNotReadBack: self = .tooLarge
        case .alreadyExists, .corrupt, .unreadable, .upgradeRequired, .tooLarge, .invalidName, .storeUnavailable, .writeFailed:
            self = .unavailable
        }
    }
}
