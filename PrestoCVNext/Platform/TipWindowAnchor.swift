import PrestoCVPresentation
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Tells which window a view is in, when the person taps in it: the store's sheet opens in the window it is asked for, and
/// an app with several windows must say which. An empty view behind the content joins the anchor to the window; neither
/// the anchor nor the window it hands over keeps the view or its window alive. On a Mac the window handed over also
/// carries the record of its closing, started when it is handed over.
@MainActor
final class TipWindowAnchor {
    #if os(iOS)
    fileprivate weak var view: UIView?

    /// The scene of the window the view is in now; unknown while the view is in none.
    var window: TipWindow {
        view?.window?.windowScene.map { TipWindow(weak: $0) } ?? .unknown
    }
    #else
    fileprivate weak var view: NSView?

    /// The observer of the closing of the window handed over last; one at a time, replaced at the next tap.
    private var closingObserver: (any NSObjectProtocol)?

    /// The window the view is in now; unknown while the view is in none. A Mac's window does not say that it closed, so the
    /// watch of its closing starts here, at the tap, on the main actor and before the purchase task is created: a window
    /// that closes between the tap and the store's call is seen closing, even if it stays among the app's windows.
    var window: TipWindow {
        stopWatching()
        guard let window = view?.window else { return .unknown }
        let closure = TipWindowClosure()
        closingObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: nil
        ) { _ in
            closure.markClosed()
        }
        return TipWindow(weak: window, closure: closure)
    }

    private func stopWatching() {
        if let closingObserver { NotificationCenter.default.removeObserver(closingObserver) }
        closingObserver = nil
    }

    isolated deinit {
        stopWatching()
    }
    #endif
}

extension View {
    /// Joins `anchor` to the window this view is in.
    func tipWindow(_ anchor: TipWindowAnchor) -> some View {
        background(TipWindowReader(anchor: anchor))
    }
}

#if os(iOS)
private struct TipWindowReader: UIViewRepresentable {
    let anchor: TipWindowAnchor

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        anchor.view = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        anchor.view = view
    }
}
#else
private struct TipWindowReader: NSViewRepresentable {
    let anchor: TipWindowAnchor

    func makeNSView(context: Context) -> NSView {
        let view = UntouchedView()
        view.setAccessibilityElement(false)
        anchor.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        anchor.view = view
    }
}

/// An empty view that takes no click: every click goes to the content in front of it.
private final class UntouchedView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
#endif
