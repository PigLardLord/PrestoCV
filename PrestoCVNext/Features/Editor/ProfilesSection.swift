import PrestoCVPresentation
import SwiftUI

/// The person's profiles online: the platform and the link.
struct ProfilesSection: View {
    @Bindable var editor: EditorViewModel
    let focus: FocusState<RowFocus?>.Binding

    var body: some View {
        RowsSection(
            editor: editor, section: .profiles, rows: editor.content.profiles, name: \.rowName,
            summary: \.summary, focus: focus
        ) { row, fields in
            ProfileFields(editor: editor, row: row, fields: fields, onPage: false)
        }
    }
}

/// The fields of one profile, in the form or on its page: the platform and the link.
struct ProfileFields: View {
    @Bindable var editor: EditorViewModel
    let row: ProfileRow
    let fields: RowFields
    let onPage: Bool

    var body: some View {
        let profile = $editor.content.profiles[row: row.id, or: row]
        EntryGroup(onPage: onPage) {
            fields.line("editor.field.platform", profile.platform, .profilePlatform)
            fields.line(
                "editor.field.link", profile.link, .profileLink,
                note: noteWords(of: editor.problem(of: .profileLink, row: row.id), field: .profileLink)
            )
        }
    }
}
