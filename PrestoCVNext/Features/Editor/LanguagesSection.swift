import PrestoCVPresentation
import SwiftUI

/// The languages, each with its level from a menu.
struct LanguagesSection: View {
    @Bindable var editor: EditorViewModel
    let focus: FocusState<RowFocus?>.Binding

    var body: some View {
        RowsSection(
            editor: editor, section: .languages, rows: editor.content.languages, name: \.rowName,
            summary: \.summary, focus: focus
        ) { row, fields in
            LanguageFields(editor: editor, row: row, fields: fields, onPage: false)
        }
    }
}

/// The fields of one language, in the form or on its page: the language and its level.
struct LanguageFields: View {
    @Bindable var editor: EditorViewModel
    let row: LanguageRow
    let fields: RowFields
    let onPage: Bool

    var body: some View {
        let language = $editor.content.languages[row: row.id, or: row]
        EntryGroup(onPage: onPage) {
            fields.line("editor.field.language", language.language, .language)
            ProficiencyPicker(proficiency: language.proficiency)
                .accessibilityIdentifier("editor.field.languageProficiency")
        }
    }
}
