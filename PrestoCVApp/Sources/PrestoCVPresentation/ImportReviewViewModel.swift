import Observation

/// The review of an import, shown over the editor: the values to check and the text not imported. It ends when the
/// person dismisses it or when the editor stored the CV, and a review with nothing in it is never shown. Its sheet may
/// stay open after it ended.
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

    /// What the notice says, by what the review holds, while it is shown: nil once it ended, and for a review that holds
    /// nothing (R13: the view words it).
    public var noticeKind: ReviewNoticeKind? {
        guard isShown else { return nil }
        return switch (hasEntries, hasNotImported) {
        case (true, true): .checkAndCopy
        case (true, false): .checkOnly
        case (false, true): .copyOnly
        case (false, false): nil
        }
    }

    /// Whether the sheet with the whole review is open. It stays open when the review ends meanwhile, so that the text to
    /// copy is not taken from under the person, until they close it.
    public private(set) var isSheetShown = false

    /// How many times the person copied the text not imported since the sheet opened, so that each copy is told.
    public private(set) var copyCount = 0

    /// Whether the text not imported was copied since the sheet opened, so that the button says so.
    public var didCopy: Bool { copyCount > 0 }

    /// Opens the sheet with the whole review, while the review is shown, with nothing copied yet.
    public func openSheet() {
        guard isShown else { return }
        copyCount = 0
        isSheetShown = true
    }

    /// Closes the sheet: the person is done with it, or swiped it away. The count of copies stays until the next sheet,
    /// so that the sheet on its way out tells nothing more.
    public func closeSheet() { isSheetShown = false }

    /// The person copied the text not imported.
    public func noteCopied() { copyCount += 1 }

    public func dismiss() { ended = true }

    /// The editor stored a change the person made: what the review points at is the person's CV now.
    public func editorStored() { ended = true }
}

/// What the notice over the editor says, so that it never offers a check or a copy that does not exist.
public enum ReviewNoticeKind: Hashable, Sendable {
    /// Values to check and a text the import could not place.
    case checkAndCopy
    /// Values to check only.
    case checkOnly
    /// A text the import could not place only.
    case copyOnly
}

extension ImportReviewViewModel: Identifiable {}
