import PrestoCVPresentation
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Tells which window a view is in, when the person taps in it: the store's sheet opens in the window it is asked for, and
/// an app with several windows must say which. An empty view behind the content joins the anchor to the window; the
/// anchor never keeps the view or its window alive.
@MainActor
final class TipWindowAnchor {
    #if os(iOS)
    fileprivate weak var view: UIView?

    /// The scene of the window the view is in now; unknown while the view is in none.
    var window: TipWindow {
        view?.window?.windowScene.map(TipWindow.init) ?? .unknown
    }
    #else
    /// A Mac has no scenes to tell: the store picks the place of its sheet.
    var window: TipWindow { .unknown }
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
private struct TipWindowReader: View {
    let anchor: TipWindowAnchor

    var body: some View { EmptyView() }
}
#endif
