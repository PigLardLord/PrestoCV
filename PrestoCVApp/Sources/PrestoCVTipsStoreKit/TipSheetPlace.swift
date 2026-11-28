#if canImport(StoreKit)
import PrestoCVWorkflowPorts

/// Where the store's sheet opens for a purchase asked for in a `TipWindow`. The tip's product loads first, and the person
/// may close the window of the tap meanwhile, so the place is decided on the main actor right before the purchase starts,
/// with nothing awaited in between. `Window` is what the adapter opens: a scene on iOS, a window on a Mac.
enum TipSheetPlace<Window> {
    /// The window of the tap, still open: the sheet opens there.
    case window(Window)
    /// No window was known at the tap: the store picks.
    case storePicks
    /// The window of the tap has closed, is gone, or is not one the adapter can open: no purchase starts, so no sheet
    /// opens in another window and nothing is charged.
    case closed

    /// The place for `window` now. `isOpen` tells whether the platform's window still is: a scene in the background or a
    /// Mac's window in the Dock still is.
    @MainActor
    static func of(_ window: TipWindow, isOpen: (Window) -> Bool) -> Self {
        guard window.isKnown else { return .storePicks }
        guard let found = window.current() as? Window, isOpen(found) else { return .closed }
        return .window(found)
    }
}
#endif
