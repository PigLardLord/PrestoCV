import Observation

/// The column a compact screen shows: the list, or the opened CV.
public enum ShellColumn: Hashable, Sendable {
    case sidebar
    case detail
}

/// Which CV the shell has open, and which column a compact screen shows first. The views bind to it and forward the
/// person's taps; the rule that a selection ends with its CV is here (R5).
@MainActor
@Observable
public final class ShellNavigationModel {
    /// The CV open in the detail, nil when none is.
    public private(set) var selection: CVReference?

    /// The column a compact screen shows: the opened CV when one is selected, otherwise the list. A regular screen shows
    /// both columns whatever this says.
    public var preferredColumn: ShellColumn { selection == nil ? .sidebar : .detail }

    public init() {}

    /// Opens the CV. Opening the CV that is open changes nothing.
    public func select(_ reference: CVReference) {
        guard selection != reference else { return }
        selection = reference
    }

    /// Closes the open CV, so that the list shows.
    public func deselect() {
        guard selection != nil else { return }
        selection = nil
    }

    /// The listed row of the open CV, nil when none is open or the list does not have it.
    public func selectedRow(in rows: [CVRow]) -> CVRow? {
        guard let selection else { return nil }
        return rows.first { $0.reference == selection }
    }

    /// The system moved to `column`. Going back to the list closes the open CV only while the split view shows one column
    /// at a time: the sidebar the system writes while the split view changes between one column and two (a rotation, a
    /// resized window) is not the person going back.
    public func columnChanged(to column: ShellColumn, isCollapsed: Bool) {
        if column == .sidebar, isCollapsed { deselect() }
    }

    /// Closes the open CV when the list no longer has it, such as after it was deleted or the store lost it.
    public func reconcile(with rows: [CVRow]) {
        guard selection != nil, selectedRow(in: rows) == nil else { return }
        deselect()
    }
}
