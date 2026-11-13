/// A way on that the notice above the form offers while the person's text cannot be stored as it is (#402, decision 8),
/// as a code the view words (R13).
public enum StatusAction: Hashable, Sendable {
    /// Shows the CV as the store holds it now, dropping the changes made here (`EditorViewModel.reload()`).
    case reload
    /// Keeps the text in a new CV (`EditorViewModel.saveAsCopy()`).
    case saveAsCopy
    /// Closes the editor without storing its text (`ShellNavigationModel.discardEditor()`).
    case discard
    /// Writes the text again (`EditorViewModel.saveNow()`).
    case retry
}

extension SaveStatus {
    /// Whether this status keeps the person in the editor: no write can store the text as it is, so leaving would lose
    /// it. Another save conflicts, the CV is gone, the store refuses the text, or a text or the CV is above its limit.
    public var blocksLeaving: Bool {
        switch self {
        case .conflict, .deletedElsewhere, .failed, .tooLarge, .textTooLong, .tooManyEntries: true
        case .saved, .pending, .saving, .notEnoughContent, .unreadable: false
        }
    }

    /// The ways on the notice offers, in the order it shows them. A text or a CV above its limit offers none: the person
    /// shortens the text, and the next change is written as usual.
    public var statusActions: [StatusAction] {
        switch self {
        case .conflict: [.reload, .saveAsCopy]
        case .deletedElsewhere: [.saveAsCopy, .discard]
        case .failed: [.retry]
        case .tooLarge, .textTooLong, .tooManyEntries, .saved, .pending, .saving, .notEnoughContent, .unreadable: []
        }
    }
}
