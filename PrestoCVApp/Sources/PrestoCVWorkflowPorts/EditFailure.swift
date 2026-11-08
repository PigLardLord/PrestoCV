import PrestoCVDomain

/// Why an editing or browsing operation did not happen, in the words the app needs (R7). A cancelled task is not one of
/// these: it stays a `CancellationError`.
public enum EditFailure: Error, Equatable, Sendable {
    /// The stored CV moved on: someone saved it since this copy was read.
    case conflict(storedRevision: Int)
    /// The CV is not in the store any more.
    case deletedElsewhere
    /// The file the store would write is too big to read back.
    case tooLarge
    /// The CV has nothing to keep yet.
    case notEnoughContent
    /// A text is above its limit, a section above its entries, or the CV above the limits as a whole.
    case textTooLong(CVTextField), tooManyEntries(CVSection), cvTooLarge
    /// The store cannot be used.
    case unavailable
}
