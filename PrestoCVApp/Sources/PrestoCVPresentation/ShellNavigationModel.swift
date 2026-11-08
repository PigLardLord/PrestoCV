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

    /// Closes the open CV when the list no longer has it, such as after it was deleted or the store lost it.
    public func reconcile(with rows: [CVRow]) {
        guard let selection, !rows.contains(where: { $0.reference == selection }) else { return }
        deselect()
    }
}
