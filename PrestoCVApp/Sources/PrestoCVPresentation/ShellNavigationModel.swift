import Observation

/// The column a compact screen shows: the list, or the opened CV.
public enum ShellColumn: Hashable, Sendable {
    case sidebar
    case detail
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
@MainActor
@Observable
public final class ShellNavigationModel {
    /// What the detail shows: a stored CV, or a draft that is not stored yet. Nil when nothing is open.
    public private(set) var detail: EditorStart?

    /// The stored CV open in the detail, nil when none is open or the detail holds a draft, which has no row.
    public var selection: CVReference? {
        guard case .stored(let reference)? = detail else { return nil }
        return reference
    }

    /// The column a compact screen shows: the detail when something is open, otherwise the list. A regular screen shows
    /// both columns whatever this says.
    public var preferredColumn: ShellColumn { detail == nil ? .sidebar : .detail }

    public init() {}

    /// Opens a stored CV or a draft in the detail, in place of what was open. Opening the stored CV that is open changes
    /// nothing; a draft is new each time, so it always replaces.
    public func open(_ start: EditorStart) {
        if case .stored(let reference) = start, reference == selection { return }
        detail = start
    }

    /// Closes what the detail shows, so that the list shows.
    public func deselect() {
        guard detail != nil else { return }
        detail = nil
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
        if column == .sidebar, isCollapsed { deselect() }
    }

    /// Closes the open CV when the list no longer has it, such as after it was deleted or the store lost it. A draft is
    /// not in the list, so it stays.
    public func reconcile(with rows: [CVRow]) {
        guard selection != nil, selectedRow(in: rows) == nil else { return }
        deselect()
    }
}
