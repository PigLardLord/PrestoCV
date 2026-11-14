import SwiftUI

extension View {
    /// Puts a bar with a button that puts the keyboard away at the bottom of the view while `shown`, for the keyboards
    /// that have no key to do so (the phone pad) and for a text of several lines, whose return key starts a new line. The
    /// on-screen keyboard is part of the view's safe area, so the bar rides just above it. A Mac has no on-screen keyboard,
    /// so there it changes nothing.
    ///
    /// The bar is drawn here rather than asked of the system (`ToolbarItemPlacement.keyboard`): the system's bar makes
    /// SwiftUI log "Invalid frame dimension (negative or non-finite)." once the keyboard is up, and in the detail of a split
    /// view as soon as the view appears, on iOS 26.5 and 27.0, Apple's own example of the placement included (#478).
    ///
    /// - Parameters:
    ///   - title: The button's words, which the feature gives.
    ///   - shown: Whether the bar is there: while a field of the view has the focus.
    ///   - done: What putting the keyboard away does, such as clearing the focus.
    func keyboardDoneBar(_ title: LocalizedStringResource, shown: Bool, done: @escaping () -> Void) -> some View {
        #if os(iOS)
        safeAreaInset(edge: .bottom, spacing: 0) {
            if shown {
                HStack {
                    Spacer()
                    Button(action: done) {
                        Text(title)
                            .fontWeight(.semibold)
                            .frame(minHeight: TapTarget.minimumHeight)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("keyboard.done")
                }
                .padding(.horizontal, Spacing.medium)
                .background(.bar)
            }
        }
        #else
        self
        #endif
    }
}
