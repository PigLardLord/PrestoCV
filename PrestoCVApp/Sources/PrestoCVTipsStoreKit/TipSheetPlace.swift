#if canImport(StoreKit)
import PrestoCVWorkflowPorts
#if os(macOS)
import AppKit
#endif

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
    /// Mac's window in the Dock or of a hidden app (`MacWindowFacts`) still is. A window seen closing since the tap is
    /// closed (`TipWindow.hasClosed`), whatever `isOpen` says.
    @MainActor
    static func of(_ window: TipWindow, isOpen: (Window) -> Bool) -> Self {
        guard window.isKnown else { return .storePicks }
        guard !window.hasClosed, let found = window.current() as? Window, isOpen(found) else { return .closed }
        return .window(found)
    }
}

/// What a Mac's window shows of itself, to tell an open window from a closed one. AppKit states that `isVisible` is true
/// while the window is onscreen, even when other windows obscure it, and that `isMiniaturized` is true while it is in the
/// Dock; it does not say that a window of a hidden app (Cmd-H) is visible, and `NSApplication.windows` lists every window
/// that still exists, on or off screen, on any space. So a hidden app's window that is still listed is open, not closed,
/// unless it closed: a closed window that is not released (`isReleasedWhenClosed` is false) may stay listed, so its
/// closing is recorded from the tap (`TipWindowClosure`, read by `TipSheetPlace`) and overrides this exception.
struct MacWindowFacts: Equatable {
    var isVisible: Bool
    var isMiniaturized: Bool
    /// Whether the app is hidden (Cmd-H).
    var appIsHidden: Bool
    /// Whether the window is still one of the app's windows.
    var isListed: Bool
    /// Whether the window is open: on screen, in the Dock, or, while the app is hidden, still one of the app's windows.
    var isOpen: Bool {
        isVisible || isMiniaturized || (appIsHidden && isListed)
    }

    #if os(macOS)
    @MainActor
    init(of window: NSWindow) {
        self.init(
            isVisible: window.isVisible, isMiniaturized: window.isMiniaturized, appIsHidden: NSApp.isHidden,
            isListed: NSApp.windows.contains(window))
    }
    #endif

    init(isVisible: Bool, isMiniaturized: Bool, appIsHidden: Bool, isListed: Bool) {
        self.isVisible = isVisible
        self.isMiniaturized = isMiniaturized
        self.appIsHidden = appIsHidden
        self.isListed = isListed
    }
}
#endif
