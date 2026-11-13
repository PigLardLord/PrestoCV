import SwiftUI

extension View {
    /// Puts the Edit button in the bar: while it reads Done, each row that can move shows a handle to drag it. It is
    /// off while no section has two rows, except while it reads Done, so that edit mode can always be left. A Mac
    /// moves a row by a drag with no edit mode, so there it changes nothing.
    func editRowsButton(canReorder: Bool) -> some View {
        #if os(iOS)
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditRowsButton(canReorder: canReorder)
            }
        }
        #else
        self
        #endif
    }
}

#if os(iOS)
/// The system's Edit button, off while there is nothing to reorder and edit mode is off.
private struct EditRowsButton: View {
    let canReorder: Bool
    @Environment(\.editMode) private var editMode

    var body: some View {
        EditButton()
            .disabled(!canReorder && editMode?.wrappedValue.isEditing != true)
            .accessibilityIdentifier("editor.edit")
    }
}
#endif
