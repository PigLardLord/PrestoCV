import PrestoCVPresentation
import SwiftUI

/// The interests, one line each. They stay in the form on every screen.
struct InterestsSection: View {
    @Bindable var editor: EditorViewModel
    let focus: FocusState<RowFocus?>.Binding

    var body: some View {
        RowsSection(
            editor: editor, section: .interests, rows: editor.content.interests, name: \.rowName, summary: nil,
            focus: focus
        ) { row, fields in
            fields.line("editor.field.interest", $editor.content.interests[row: row.id, or: row].text, .interest)
        }
    }
}
