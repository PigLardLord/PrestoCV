import Observation

/// The column a compact screen shows: the list, or the opened CV.
public enum ShellColumn: Hashable, Sendable {
    case sidebar
    case detail
}

/// What became of a request to leave the open editor: it was left, or it stays because its text is not stored and no
/// write can store it as it is (the status says why).
public enum LeaveVerdict: Hashable, Sendable {
    case left
    case stayed(SaveStatus)
}

/// What the shell shows in its window.
public enum ShellScreen: Hashable, Sendable {
    /// The store is being read.
    case loading
    /// The welcome of a first run, with the ways to start.
    case welcome
    /// The list in the sidebar and the open CV in the detail.
    case split
}

/// What the shell has open, which column a compact screen shows first, and whether the welcome or the split view shows.
/// The views bind to it and forward the person's taps; the rules that a stored CV closes when its row goes and that a
/// draft stays are here (R5).
///
/// The shell owns the open CV's editor. Leaving it never waits for the store: the editor left is handed to its
/// `saveNow()`, which stores every change, and the shell keeps it alive until that ended. An editor whose text no write
/// can store as it is keeps the person in it, and the verdict says why.
@MainActor
@Observable
public final class ShellNavigationModel {
    /// What the detail shows: a stored CV, or a draft that is not stored yet. Nil when nothing is open.
    public private(set) var detail: EditorStart?

    /// The editor of what the detail shows, nil when nothing is open.
    public private(set) var editor: EditorViewModel?

    @ObservationIgnored private let makeEditor: @MainActor (EditorStart) -> EditorViewModel
    /// The editors left and still storing, each by the number of its leaving.
    @ObservationIgnored private var flushing: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var leavings = 0

    /// The stored CV open in the detail, nil when none is open or the detail holds a draft, which has no row.
    public var selection: CVReference? {
        guard case .stored(let reference)? = detail else { return nil }
        return reference
    }

    /// The column a compact screen shows: the detail when something is open, otherwise the list. A regular screen shows
    /// both columns whatever this says.
    public var preferredColumn: ShellColumn { detail == nil ? .sidebar : .detail }

    /// - Parameter makeEditor: Makes the editor of what the detail opens.
    public init(makeEditor: @escaping @MainActor (EditorStart) -> EditorViewModel) {
        self.makeEditor = makeEditor
    }

    /// Opens a stored CV or a draft in the detail, in place of what was open. Opening the stored CV that is open changes
    /// nothing; a draft is new each time, so it always replaces. The editor that was open stays when its text cannot be
    /// stored as it is.
    @discardableResult
    public func open(_ start: EditorStart) -> LeaveVerdict {
        if case .stored(let reference) = start, reference == selection { return .left }
        if let status = blockingStatus { return .stayed(status) }
        letGo()
        detail = start
        editor = makeEditor(start)
        return .left
    }

    /// Closes what the detail shows, so that the list shows, unless the editor's text cannot be stored as it is.
    @discardableResult
    public func deselect() -> LeaveVerdict {
        guard detail != nil else { return .left }
        if let status = blockingStatus { return .stayed(status) }
        letGo()
        detail = nil
        return .left
    }

    /// Stores the open editor, which stays open, and waits for the editors left before it to end their writes: for the
    /// scene going to the background. As any store the person asks for, it names the fields that cannot be read.
    public func flushAll() async {
        let open = editor
        let left = Array(flushing.values)
        await open?.saveNow()
        for leaving in left { await leaving.value }
    }

    /// What the window shows. A first run shows the welcome until something is open; a store that was used, or could not
    /// be read, shows the split view, whose list says why.
    public func screen(for firstRun: FirstRunState) -> ShellScreen {
        if detail != nil { return .split }
        switch firstRun {
        case .loading: return .loading
        case .firstRun: return .welcome
        case .returning, .failed: return .split
        }
    }

    /// The listed row of the open CV, nil when none is open or the list does not have it.
    public func selectedRow(in rows: [CVRow]) -> CVRow? {
        guard let selection else { return nil }
        return rows.first { $0.reference == selection }
    }

    /// The system moved to `column`. Going back to the list closes what is open only while the split view shows one
    /// column at a time: the sidebar the system writes while the split view changes between one column and two (a
    /// rotation, a resized window) is not the person going back.
    public func columnChanged(to column: ShellColumn, isCollapsed: Bool) {
        if column == .sidebar, isCollapsed { _ = deselect() }
    }

    /// Closes the open CV when the list no longer has it, such as after it was deleted or the store lost it, unless its
    /// text cannot be stored as it is: the person can still keep it as a copy. A draft is not in the list, so it stays.
    public func reconcile(with rows: [CVRow]) {
        guard selection != nil, selectedRow(in: rows) == nil else { return }
        _ = deselect()
    }

    // MARK: Leaving

    /// The status of the open editor when no write can store its text as it is, so that leaving would lose it: another
    /// save conflicts, the CV is gone, the store refuses the text, or a text or the CV is above its limit.
    private var blockingStatus: SaveStatus? {
        guard let status = editor?.saveStatus else { return nil }
        switch status {
        case .conflict, .deletedElsewhere, .failed, .tooLarge, .textTooLong, .tooManyEntries: return status
        case .saved, .pending, .saving, .notEnoughContent, .unreadable: return nil
        }
    }

    /// Hands the open editor to its `saveNow()` and keeps it alive until that ended.
    private func letGo() {
        guard let left = editor else { return }
        editor = nil
        leavings += 1
        let number = leavings
        flushing[number] = Task { [weak self] in
            await left.saveNow()
            self?.flushing[number] = nil
        }
    }
}
