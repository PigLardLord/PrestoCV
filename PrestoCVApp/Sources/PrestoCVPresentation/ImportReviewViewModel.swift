import Observation

/// The review of an import, shown beside the editor: the values to check and the text not imported. It ends when the
/// person dismisses it or when the editor stored the CV, and a review with nothing in it is never shown.
@MainActor
@Observable
public final class ImportReviewViewModel {

    public let entries: [ReviewEntry]
    public let notImported: String

    public var hasEntries: Bool { !entries.isEmpty }
    public var hasNotImported: Bool { !notImported.isEmpty }
    public var isShown: Bool { !ended && (hasEntries || hasNotImported) }

    private var ended = false

    public init(review: ImportReview) {
        entries = review.entries
        notImported = review.notImported
    }

    public func dismiss() { ended = true }

    /// The editor stored the CV: what the review points at is the person's CV now.
    public func editorStored() { ended = true }
}
