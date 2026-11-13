internal import PrestoCVDomain

/// An editor the person left whose text is not stored: its last write failed after they left it, or one of its fields
/// cannot be read (#402, decisions 16 and 17). The shell keeps it, so nothing typed is dropped, until a write stores
/// its text or the person opens it again; the list shows a notice for it, on its CV's row when the list has one.
public struct KeptEditor: Hashable, Sendable, Identifiable {
    /// The number the shell keeps it by
    public let id: Int
    /// The stored CV it writes, nil for a draft that stored no CV yet
    public let reference: CVReference?
    /// Why its text is not stored
    public let status: SaveStatus
    /// What its CV is called, from the text it holds
    let title: CVTitle

    /// Whether another write may store its text as it is: after a write that failed, or one that has not ended. A text
    /// another window changed or deleted, a field that cannot be read and a text above its limit need the person in the
    /// editor, so the notice offers only to open it.
    public var canRetry: Bool {
        switch status {
        case .failed, .pending, .saving: return true
        case .saved, .notEnoughContent, .textTooLong, .tooManyEntries, .tooLarge, .unreadable, .conflict, .deletedElsewhere:
            return false
        }
    }

    @MainActor
    init(id: Int, editor: EditorViewModel) {
        let content = editor.content
        self.init(
            id: id, reference: editor.storedReference, status: editor.saveStatus,
            title: CVTitle(name: content.title, person: content.fullName, role: content.professionalTitle)
        )
    }

    init(id: Int, reference: CVReference?, status: SaveStatus, title: CVTitle) {
        self.id = id
        self.reference = reference
        self.status = status
        self.title = title
    }
}

/// The notice the list shows for a kept editor: what it names, why the text is not stored, and whether it offers to write
/// the text again besides opening it.
public struct KeptNotice: Hashable, Sendable, Identifiable {
    /// The kept editor's number, which the shell's `openKept(_:)` and `retryKept(_:)` take
    public let id: Int
    /// The row's label when the list has the CV, else the title the editor's own text gives it
    public let label: String
    /// Why its text is not stored
    public let status: SaveStatus
    /// Whether the notice offers to write the text again (`KeptEditor.canRetry`)
    public let canRetry: Bool
}

/// The notices of the kept editors, where the list shows them.
public struct KeptNotices: Hashable, Sendable {
    /// Above the rows, in the order the editors were left
    public var above: [KeptNotice]
    /// Under the row of each listed CV
    public var under: [CVReference: KeptNotice]
}
