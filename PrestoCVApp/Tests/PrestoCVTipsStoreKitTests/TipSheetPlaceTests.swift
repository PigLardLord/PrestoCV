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
            isVisible: visible, isMiniaturized: miniaturized, appIsHidden: hidden, isListed: listed, hasClosed: closed)
    }

    @Test("a window seen closing is closed, though the app is hidden and the window is still listed")
    func closedWhileHidden() {
        #expect(!facts(hidden: true, closed: true).isOpen)
        #expect(!facts(miniaturized: true, closed: true).isOpen)
        #expect(!facts(visible: true, closed: true).isOpen)
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
@Suite("Watching a Mac's window for its closing")
struct MacWindowWatchTests {
    private func window() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled, .closable],
            backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        return window
    }

    @Test("a window that closes after the watch started has closed, though it is retained and the app is hidden")
    func closeAfterTheTap() {
        let tapped = window()
        let watch = MacWindowWatch(watching: tapped)
        #expect(!watch.hasClosed)

        tapped.close()

        #expect(watch.hasClosed)
        let facts = MacWindowFacts(
            isVisible: false, isMiniaturized: false, appIsHidden: true, isListed: true, hasClosed: watch.hasClosed)
        #expect(!facts.isOpen)
        watch.stop()
    }

    @Test("another window closing does not close the watched one")
    func otherWindow() {
        let tapped = window()
        let other = window()
        let watch = MacWindowWatch(watching: tapped)

        other.close()

        #expect(!watch.hasClosed)
        watch.stop()
    }

    @Test("a watch stopped before the window closes sees nothing")
    func stopped() {
        let tapped = window()
        let watch = MacWindowWatch(watching: tapped)
        watch.stop()

        tapped.close()

        #expect(!watch.hasClosed)
    }
}
#endif
#endif
