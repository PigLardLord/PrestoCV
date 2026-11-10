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
/// `saveNow()`, which stores every change, and the shell keeps it alive until that ended. Opening that CV again
/// meanwhile gets the same editor back, so one writer keeps its writes in order. An editor whose text no write can store
/// as it is keeps the person in it, and the verdict says why.
///
/// An editor left whose text its write did not store, because the write failed or a field cannot be read, is kept
/// (#402, decisions 16 and 17): nothing typed is dropped. The list shows a notice for each (`keptEditors`), from which
/// the person writes it again or opens it; storing every editor for the background writes the kept ones too.
@MainActor
@Observable
public final class ShellNavigationModel {
    /// What the detail shows: a stored CV, or a draft that is not stored yet. Nil when nothing is open.
    public private(set) var detail: EditorStart?

    /// The editor of what the detail shows, nil when nothing is open.
    public private(set) var editor: EditorViewModel?

    @ObservationIgnored private let makeEditor: @MainActor (EditorStart) -> EditorViewModel
    @ObservationIgnored private let backgroundTime: any BackgroundTime
    /// The editors left and still storing, each by the number of its leaving.
    @ObservationIgnored private var flushing: [Int: Leaving] = [:]
    @ObservationIgnored private var leavings = 0
    /// The editors left whose write ended without storing their text, each by the number of its leaving. Observed: the
    /// list shows a notice for each.
    private var kept: [Int: Kept] = [:]

    /// An editor left, what it opened, and its `saveNow()`, which stores it.
    private struct Leaving {
        let editor: EditorViewModel
        let start: EditorStart
        let storing: Task<Void, Never>
    }

    /// An editor left whose text is not stored, and what it opened.
    private struct Kept {
        let editor: EditorViewModel
        let start: EditorStart
    }

    /// The editors left whose text is not stored, in the order they were left, for the list's notices. One that stored
    /// its text since is no longer among them.
    public var keptEditors: [KeptEditor] {
        kept.sorted { $0.key < $1.key }
            .filter { Self.keeps($0.value.editor.saveStatus) }
            .map { KeptEditor(id: $0.key, editor: $0.value.editor) }
    }

    /// The stored CV open in the detail: the one the detail opened, or the copy its editor was saved as since. Nil when
    /// none is open or the detail holds a draft, which has no row.
    public var selection: CVReference? {
        guard case .stored(let reference)? = detail else { return nil }
        return editor?.storedReference ?? reference
    }

    /// The column a compact screen shows: the detail when something is open, otherwise the list. A regular screen shows
    /// both columns whatever this says.
    public var preferredColumn: ShellColumn { detail == nil ? .sidebar : .detail }

    /// Whether the person can leave the open editor now. While they cannot, the view offers no way back, and a selection
    /// stays where it was (`open(_:)` and `deselect()` say why).
    public var canLeave: Bool { blockingStatus == nil }

    /// - Parameters:
    ///   - makeEditor: Makes the editor of what the detail opens.
    ///   - backgroundTime: The time the system grants to end the writes once the app leaves the foreground.
    public init(makeEditor: @escaping @MainActor (EditorStart) -> EditorViewModel, backgroundTime: any BackgroundTime) {
        self.makeEditor = makeEditor
        self.backgroundTime = backgroundTime
    }

    /// The scene became active, or stopped being active. On its way to the background a scene is inactive first, and from
    /// then on the open CV, the ones left and the ones kept are stored at once, under time asked of the system, so that a
    /// suspension does not cut a write off; the time is given back once every write ended. As any store the person asks
    /// for, it names the fields that cannot be read.
    public func sceneChanged(isActive: Bool) {
        guard !isActive else { return }
        let hold = backgroundTime.hold()
        Task {
            await flushAll()
            hold.end()
        }
    }

    /// Opens a stored CV or a draft in the detail, in place of what was open. Opening the stored CV that is open changes
    /// nothing; a draft is new each time, so it always replaces. Opening a CV whose editor was left and still stores it,
    /// or is kept, gets that editor back. The editor that was open stays when its text cannot be stored as it is.
    @discardableResult
    public func open(_ start: EditorStart) -> LeaveVerdict {
        if case .stored(let reference) = start, reference == selection { return .left }
        if let status = blockingStatus { return .stayed(status) }
        letGo()
        detail = start
        editor = takeBack(start) ?? makeEditor(start)
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

    /// Stores the open editor, which stays open, waits for the editors left before it to end their writes, and writes
    /// the kept ones again: for the scene leaving the foreground (`sceneChanged(isActive:)`). A kept editor whose text
    /// is stored then is no longer kept.
    func flushAll() async {
        let open = editor
        let left = flushing.values.map(\.storing)
        let keptOnes = kept.values.map(\.editor)
        await open?.saveNow()
        for storing in left { await storing.value }
        for editor in keptOnes { await editor.saveNow() }
        prune()
    }

    // MARK: Kept editors

    /// Opens a kept editor in the detail, in place of what was open, as `open(_:)` does: the editor that was open stays
    /// when its text cannot be stored as it is. A kept editor no longer kept, because a write stored it meanwhile,
    /// opens nothing.
    @discardableResult
    public func openKept(_ id: Int) -> LeaveVerdict {
        guard let found = kept[id] else { return .left }
        if let status = blockingStatus { return .stayed(status) }
        letGo()
        kept[id] = nil
        detail = found.editor.storedReference.map { .stored($0) } ?? found.start
        editor = found.editor
        return .left
    }

    /// Writes a kept editor's text again, from the notice's Retry. Stored, it is no longer kept; a write that fails
    /// again keeps it.
    public func retryKept(_ id: Int) async {
        guard let found = kept[id] else { return }
        await found.editor.saveNow()
        prune()
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

    // MARK: Discarding

    /// Drops the open editor and its text that is not stored, on the person's word, so that the detail shows nothing:
    /// after another window deleted the CV, the person chose not to keep the text as a copy, or the CV could not be
    /// opened. Nothing is written. In any other state it does nothing, and so while a copy runs (`isReplacing`): the copy
    /// may store the text the person meant to drop, and the editor goes on with it.
    public func discardEditor() {
        guard let editor, editor.canBeDiscarded else { return }
        self.editor = nil
        detail = nil
    }

    // MARK: Leaving

    /// The status of the open editor when no write can store its text as it is, so that leaving would lose it: another
    /// save conflicts, the CV is gone, the store refuses the text, or a text or the CV is above its limit.
    private var blockingStatus: SaveStatus? {
        guard let status = editor?.saveStatus, status.blocksLeaving else { return nil }
        return status
    }

    /// Hands the open editor to its `saveNow()` and keeps it alive until that ended; when that did not store its text,
    /// the editor is kept (`landed(_:)`). Every caller reads what the detail opened before it changes the detail.
    private func letGo() {
        guard let left = editor else { return }
        let start = detail ?? .blank
        editor = nil
        leavings += 1
        let number = leavings
        let storing = Task { [weak self] in
            await left.saveNow()
            self?.landed(number)
        }
        flushing[number] = Leaving(editor: left, start: start, storing: storing)
    }

    /// The write of the editor left as `number` ended: it is no longer among the ones storing, and is kept when its text
    /// is not stored. One taken back meanwhile is open again, and nothing changes.
    private func landed(_ number: Int) {
        guard let leaving = flushing.removeValue(forKey: number) else { return }
        if Self.keeps(leaving.editor.saveStatus) {
            kept[number] = Kept(editor: leaving.editor, start: leaving.start)
        }
        prune()
    }

    /// Whether an editor left with this status still holds text the store does not have. A text too short to be a CV
    /// is not one: nothing worth keeping was typed (#402).
    static func keeps(_ status: SaveStatus) -> Bool {
        switch status {
        case .saved, .notEnoughContent: return false
        case .pending, .saving, .textTooLong, .tooManyEntries, .tooLarge, .unreadable, .conflict, .deletedElsewhere, .failed:
            return true
        }
    }

    /// Lets go of the kept editors whose text a write stored since.
    private func prune() {
        let held = kept.filter { Self.keeps($0.value.editor.saveStatus) }
        if held.count != kept.count { kept = held }
    }

    /// The editor left that still stores the CV `start` opens, or is kept with it, no longer among the ones left or kept;
    /// nil when none does. It is found by the CV it stores now, not by what it opened, since a draft stores a CV from its
    /// first write on. Taking it back keeps its writer: its writes stay in order, and its text not stored yet is not read
    /// again from an older revision, which would conflict with its own write (#402).
    private func takeBack(_ start: EditorStart) -> EditorViewModel? {
        guard case .stored(let reference) = start else { return nil }
        if let found = flushing.first(where: { $0.value.editor.storedReference == reference }) {
            flushing[found.key] = nil
            return found.value.editor
        }
        if let found = kept.first(where: { $0.value.editor.storedReference == reference }) {
            kept[found.key] = nil
            return found.value.editor
        }
        return nil
    }
}
