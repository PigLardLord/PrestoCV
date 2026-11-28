#if canImport(StoreKit)
import PrestoCVWorkflowPorts
#if os(macOS)
import AppKit
import Synchronization
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
    /// Mac's window in the Dock or of a hidden app (`MacWindowFacts`) still is, unless it was seen closing.
    @MainActor
    static func of(_ window: TipWindow, isOpen: (Window) -> Bool) -> Self {
        guard window.isKnown else { return .storePicks }
        guard let found = window.current() as? Window, isOpen(found) else { return .closed }
        return .window(found)
    }
}

/// What a Mac's window shows of itself, to tell an open window from a closed one. AppKit states that `isVisible` is true
/// while the window is onscreen, even when other windows obscure it, and that `isMiniaturized` is true while it is in the
/// Dock; it does not say that a window of a hidden app (Cmd-H) is visible, and `NSApplication.windows` lists every window
/// that still exists, on or off screen, on any space. So a hidden app's window that is still listed is open, not closed,
/// unless it closed: a closed window that is not released (`isReleasedWhenClosed` is false) may stay listed, so its
/// closing is recorded from the tap (`MacWindowWatch`) and overrides the hidden-app exception.
struct MacWindowFacts: Equatable {
    var isVisible: Bool
    var isMiniaturized: Bool
    /// Whether the app is hidden (Cmd-H).
    var appIsHidden: Bool
    /// Whether the window is still one of the app's windows.
    var isListed: Bool
    /// Whether the window was seen closing (`MacWindowWatch`) since the tap. A closed window that is not released may
    /// stay listed, so closing is recorded, not inferred.
    var hasClosed: Bool

    /// Whether the window is still open: it has not closed, and it is on screen, in the Dock, or, while the app is
    /// hidden, still one of the app's windows.
    var isOpen: Bool {
        !hasClosed && (isVisible || isMiniaturized || (appIsHidden && isListed))
    }

    #if os(macOS)
    @MainActor
    init(of window: NSWindow, hasClosed: Bool) {
        self.init(
            isVisible: window.isVisible, isMiniaturized: window.isMiniaturized, appIsHidden: NSApp.isHidden,
            isListed: NSApp.windows.contains(window), hasClosed: hasClosed)
    }
    #endif

    init(isVisible: Bool, isMiniaturized: Bool, appIsHidden: Bool, isListed: Bool, hasClosed: Bool = false) {
        self.hasClosed = hasClosed
        self.isVisible = isVisible
        self.isMiniaturized = isMiniaturized
        self.appIsHidden = appIsHidden
        self.isListed = isListed
    }
}

#if os(macOS)
/// Records whether the tapped window closed, from before the product lookup until the purchase would start. AppKit does
/// not say that a window closed: a window that is not released when closed may stay in `NSApp.windows`, and with the app
/// hidden it would then read as open. The purchase stops the watch when it ends.
@MainActor
final class MacWindowWatch {
    /// Set by the notification wherever it is posted, read on the main actor.
    private let closed = ClosedFlag()
    private var observer: (any NSObjectProtocol)?

    var hasClosed: Bool { closed.value.withLock { $0 } }

    /// Starts watching `window`; nil, a window already gone, is not watched, and `TipWindow` reads it as closed.
    init(watching window: NSWindow?) {
        guard let window else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: nil
        ) { [closed] _ in
            closed.value.withLock { $0 = true }
        }
    }

    /// Ends the watch: the purchase has started or ended, and the window no longer matters.
    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }
}

/// The flag the notification sets, apart from the watch so that the observer's closure holds only the flag.
private final class ClosedFlag: Sendable {
    let value = Mutex(false)
}

typealias WindowClosure = MacWindowWatch
#else
/// Nothing to watch on iOS: a scene tells its own state (`activationState`).
@MainActor
final class WindowClosure {
    let hasClosed = false

    init() {}

    func stop() {}
}
#endif
#endif
