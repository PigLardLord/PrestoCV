import PrestoCVPresentation
import SwiftUI

/// The languages, each with its level from a menu.
struct LanguagesSection: View {
    @Bindable var editor: EditorViewModel
    let focus: FocusState<RowFocus?>.Binding

    var body: some View {
        RowsSection(
            editor: editor, section: .languages, rows: editor.content.languages, name: \.rowName, first: .language,
            focus: focus
        ) { row, fields in
            let language = $editor.content.languages[row: row.id, or: row]
            fields.line("editor.field.language", language.language, .language)
            ProficiencyPicker(proficiency: language.proficiency)
                .accessibilityIdentifier("editor.field.languageProficiency")
        }
    }
}
