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

    /// The identity of the row at `index` of this section, by which the form scrolls to it.
    func identity(ofRow index: Int) -> RowIdentity {
        RowIdentity(section: ObjectIdentifier(self), index: index)
    }
}

/// A row of a section, told apart from the rows of the other sections of the same form.
struct RowIdentity: Hashable {
    let section: ObjectIdentifier
    let index: Int
}

extension EnvironmentValues {
    /// The focus request of the section a row is in; nil outside a section of the editor.
    @Entry var newRowFocus: NewRowFocus? = nil
    /// The place of a row in its section.
    @Entry var rowIndex = 0
    /// Scrolls the form a row is in; nil outside a form that brings its new rows into view.
    @Entry var formScroll: ScrollViewProxy? = nil
}

extension View {
    /// Marks the field a person fills in first in a row: it takes the keyboard focus when the row has just been added.
    func firstFieldOfRow() -> some View {
        modifier(FirstFieldOfRow())
    }

    /// Lets the rows added to the sections of this form, which scrolls, bring themselves into view.
    func bringsNewRowsIntoView() -> some View {
        ScrollViewReader { form in
            self.environment(\.formScroll, form)
        }
    }
}

private struct FirstFieldOfRow: ViewModifier {
    @Environment(\.newRowFocus) private var newRowFocus
    @Environment(\.rowIndex) private var rowIndex
    @Environment(\.formScroll) private var formScroll
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .task {
                // The field takes the focus once it is on the screen, not while its row is still being inserted
                guard let newRowFocus, newRowFocus.take(row: rowIndex) else { return }
                isFocused = true
                // Since iOS 27 the form brings a field that takes the focus low on the screen only to the keyboard's top
                // edge, under the Done button that floats over it: the new row comes up to the top of the form instead
                withAnimation(DesignTokens.Animations.standardEaseInOut) {
                    formScroll?.scrollTo(newRowFocus.identity(ofRow: rowIndex), anchor: .top)
                }
            }
    }
}
