#if canImport(StoreKit)
import PrestoCVWorkflowPorts
import Testing
@testable import PrestoCVTipsStoreKit

@MainActor
@Suite("Where the store's sheet opens")
struct TipSheetPlaceTests {
    @Test("the window of the tap, still open when the purchase starts, is where the sheet opens")
    func openWindow() {
        let tapped = WindowStandIn(name: "left")

        let place = TipSheetPlace<WindowStandIn>.of(TipWindow(weak: tapped), isOpen: \.isOpen)

        #expect(place.code == "window left")
        withExtendedLifetime(tapped) {}
    }

    @Test("a window that closed after the tap gets no sheet, though it still exists")
    func closedWindow() {
        let tapped = WindowStandIn(name: "left")
        let window = TipWindow(weak: tapped)
        tapped.isOpen = false

        #expect(TipSheetPlace<WindowStandIn>.of(window, isOpen: \.isOpen).code == "closed")
        withExtendedLifetime(tapped) {}
    }

    @Test("a window gone after the tap gets no sheet: the tap's window does not keep it alive")
    func goneWindow() {
        let window = TipWindow(weak: WindowStandIn(name: "left"))

        #expect(window.current() == nil)
        #expect(TipSheetPlace<WindowStandIn>.of(window, isOpen: \.isOpen).code == "closed")
    }

    @Test("a window of a kind the adapter cannot open gets no sheet")
    func otherKind() {
        let tapped = OtherStandIn()

        #expect(TipSheetPlace<WindowStandIn>.of(TipWindow(weak: tapped), isOpen: \.isOpen).code == "closed")
        withExtendedLifetime(tapped) {}
    }

    @Test("without a window known at the tap the store picks, and nothing is asked about a window")
    func unknownWindow() {
        let place = TipSheetPlace<WindowStandIn>.of(.unknown) { _ in
            Issue.record("no window to ask about")
            return false
        }

        #expect(place.code == "store picks")
    }
}

extension TipSheetPlace where Window == WindowStandIn {
    /// What a test compares: the place, with the name of its window.
    fileprivate var code: String {
        switch self {
        case .window(let window): "window \(window.name)"
        case .storePicks: "store picks"
        case .closed: "closed"
        }
    }
}

/// A stand-in for a scene or a Mac's window: open until a test closes it.
@MainActor
final class WindowStandIn {
    let name: String
    var isOpen = true

    init(name: String) {
        self.name = name
    }
}

/// A window of another kind than the one the adapter opens.
final class OtherStandIn: Sendable {}

@Suite("When a Mac's window is open")
struct MacWindowFactsTests {
    private func facts(
        visible: Bool = false, miniaturized: Bool = false, hidden: Bool = false, listed: Bool = true,
        closed: Bool = false
    ) -> MacWindowFacts {
        MacWindowFacts(
            isVisible: visible, isMiniaturized: miniaturized, appIsHidden: hidden, isListed: listed)
    }

    @Test("a window on screen is open")
    func onScreen() {
        #expect(facts(visible: true).isOpen)
    }

    @Test("a window in the Dock is open")
    func inTheDock() {
        #expect(facts(miniaturized: true).isOpen)
    }

    @Test("an open window of an app hidden with Cmd-H is open: it is not visible, but still one of the app's windows")
    func hiddenApp() {
        #expect(facts(hidden: true).isOpen)
    }

    @Test("a window that is not visible, with the app showing, is closed")
    func closed() {
        #expect(!facts().isOpen)
    }

    @Test("a window gone from the app's windows is closed, whether or not the app is hidden")
    func gone() {
        #expect(!facts(hidden: true, listed: false).isOpen)
        #expect(!facts(listed: false).isOpen)
    }
}

#if os(macOS)
import AppKit

@MainActor
@Suite("A Mac's window closing between the tap and the purchase")
final class TipWindowClosureOnAMacTests {
    private func window() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled, .closable],
            backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        return window
    }

    /// The window as `TipWindowAnchor` hands it over at the tap: the watch of its closing starts there, on the main actor,
    /// before anything else runs, and its observer is removed with the test's `observers`.
    private func handedOver(_ window: NSWindow) -> TipWindow {
        let closure = TipWindowClosure()
        observers.append(
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) {
                _ in closure.markClosed()
            })
        return TipWindow(weak: window, closure: closure)
    }

    private var observers: [any NSObjectProtocol] = []

    /// What a hidden app shows of a window that is retained and still listed, closed or not.
    private let hiddenAppFacts = MacWindowFacts(
        isVisible: false, isMiniaturized: false, appIsHidden: true, isListed: true)

    @Test("a window closed after the tap and before the purchase starts gets no sheet, though retained, listed and the app hidden")
    func closedBeforeThePurchaseStarts() {
        let tapped = window()
        let handed = handedOver(tapped)

        tapped.close()

        let place = TipSheetPlace<NSWindow>.of(handed) { _ in hiddenAppFacts.isOpen }
        #expect(place.isClosed)
        #expect(handed.hasClosed)
    }

    @Test("a window closed while the product loads gets no sheet")
    func closedDuringTheLookup() async {
        let tapped = window()
        let handed = handedOver(tapped)

        await Task { @MainActor in tapped.close() }.value

        #expect(TipSheetPlace<NSWindow>.of(handed) { _ in hiddenAppFacts.isOpen }.isClosed)
    }

    @Test("an open window of a hidden app is where the sheet opens")
    func openWindowOfAHiddenApp() {
        let tapped = window()
        let handed = handedOver(tapped)

        let place = TipSheetPlace<NSWindow>.of(handed) { _ in hiddenAppFacts.isOpen }

        if case .window(let shown) = place { #expect(shown === tapped) } else { Issue.record("expected the window") }
        #expect(!handed.hasClosed)
    }

    @Test("another window closing changes nothing")
    func otherWindowClosing() {
        let tapped = window()
        let other = window()
        let handed = handedOver(tapped)

        other.close()

        #expect(!handed.hasClosed)
        #expect(!TipSheetPlace<NSWindow>.of(handed) { _ in hiddenAppFacts.isOpen }.isClosed)
    }
}

extension TipSheetPlace {
    fileprivate var isClosed: Bool {
        if case .closed = self { return true }
        return false
    }
}
#endif

@MainActor
@Suite("The record of a window's closing")
struct TipWindowClosureTests {
    @Test("a window whose closing was recorded is closed for the place of the sheet, though it still reads as open")
    func recordedClosing() {
        let tapped = WindowStandIn(name: "left")
        let closure = TipWindowClosure()
        let window = TipWindow(weak: tapped, closure: closure)
        #expect(TipSheetPlace<WindowStandIn>.of(window, isOpen: \.isOpen).code == "window left")

        closure.markClosed()

        #expect(window.hasClosed)
        #expect(TipSheetPlace<WindowStandIn>.of(window, isOpen: \.isOpen).code == "closed")
    }

    @Test("a window that was not watched has not closed")
    func notWatched() {
        #expect(!TipWindow(weak: OtherStandIn()).hasClosed)
        #expect(!TipWindow.unknown.hasClosed)
    }
}
#endif
