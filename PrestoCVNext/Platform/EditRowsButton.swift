import SwiftUI

extension View {
    /// Puts the Edit button in the bar: while it reads Done, each row that can move shows a handle to drag it. A Mac
    /// moves a row by a drag with no edit mode, so there it changes nothing.
    func editRowsButton() -> some View {
        #if os(iOS)
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .accessibilityIdentifier("editor.edit")
            }
        }
        #else
        self
        #endif
    }
}
