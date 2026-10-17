import SwiftUI

/// The row of a section that takes the keyboard focus when its first field appears: the row the person has just
/// added, so that they can type into it at once. It is asked for once; a row drawn again later, as the form
/// scrolls, does not take the focus back.
@MainActor
final class NewRowFocus {
    private var requestedRow: Int?

    /// Asks the row at `index` to take the focus when it appears.
    func request(row index: Int) {
        requestedRow = index
    }

    /// True for the row that was asked to take the focus, the first time it asks.
    func take(row index: Int) -> Bool {
        guard requestedRow == index else { return false }
        requestedRow = nil
        return true
    }
}

extension EnvironmentValues {
    /// The focus request of the section a row is in; nil outside a section of the editor.
    @Entry var newRowFocus: NewRowFocus? = nil
    /// The place of a row in its section.
    @Entry var rowIndex = 0
}

extension View {
    /// Marks the field a person fills in first in a row: it takes the keyboard focus when the row has just been added.
    func firstFieldOfRow() -> some View {
        modifier(FirstFieldOfRow())
    }
}

private struct FirstFieldOfRow: ViewModifier {
    @Environment(\.newRowFocus) private var newRowFocus
    @Environment(\.rowIndex) private var rowIndex
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .task {
                // The field takes the focus once it is on the screen, not while its row is still being inserted
                if newRowFocus?.take(row: rowIndex) == true {
                    isFocused = true
                }
            }
    }
}
