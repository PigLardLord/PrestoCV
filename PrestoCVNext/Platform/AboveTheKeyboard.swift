import SwiftUI

extension View {
    /// Puts `content` at the bottom of the view while `shown`. The on-screen keyboard is part of the view's safe area, so
    /// the content rides just above it; with a hardware keyboard it sits at the bottom of the view. A Mac has no
    /// on-screen keyboard, so there it changes nothing.
    ///
    /// - Parameters:
    ///   - shown: Whether the content is there: while a field of the view has the focus.
    ///   - content: What goes above the keyboard, such as `KeyboardDoneBar`.
    func aboveTheKeyboard<Content: View>(shown: Bool, @ViewBuilder content: () -> Content) -> some View {
        #if os(iOS)
        safeAreaInset(edge: .bottom, spacing: 0) {
            if shown {
                content()
            }
        }
        #else
        self
        #endif
    }
}
