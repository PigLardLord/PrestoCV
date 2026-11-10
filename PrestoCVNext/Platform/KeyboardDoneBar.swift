import SwiftUI

extension View {
    /// Puts a button above the on-screen keyboard that puts it away, for the keyboards that have no key to do so (the
    /// phone pad) and for a text of several lines, whose return key starts a new line. A Mac has no on-screen keyboard,
    /// so there it changes nothing.
    ///
    /// - Parameters:
    ///   - title: The button's words, which the feature gives.
    ///   - done: What putting the keyboard away does, such as clearing the focus.
    func keyboardDoneBar(_ title: LocalizedStringResource, done: @escaping () -> Void) -> some View {
        #if os(iOS)
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(action: done) { Text(title) }
                    .accessibilityIdentifier("keyboard.done")
            }
        }
        #else
        self
        #endif
    }
}
