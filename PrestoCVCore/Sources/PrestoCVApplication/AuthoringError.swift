/// What presentation needs to know about a failed use case, without the shape of the port's errors (CleanErrors).
public enum AuthoringError: Error, Equatable, Sendable {
    case notEnoughContent, conflict(storedRevision: Int), deletedElsewhere, tooLarge, unavailable
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
