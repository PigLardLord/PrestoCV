import PrestoCVPresentation
import SwiftUI

/// The person's profiles online: the platform and the link.
struct ProfilesSection: View {
    @Bindable var editor: EditorViewModel
    let focus: FocusState<RowFocus?>.Binding

    var body: some View {
        RowsSection(
            editor: editor, section: .profiles, rows: editor.content.profiles, name: \.rowName, first: .profilePlatform,
            focus: focus
        ) { row, fields in
            let profile = $editor.content.profiles[row: row.id, or: row]
            fields.line("editor.field.platform", profile.platform, .profilePlatform)
            fields.line(
                "editor.field.link", profile.link, .profileLink,
                note: noteWords(of: editor.problem(of: .profileLink, row: row.id), unreadable: "editor.note.link")
            )
        }
    }
}
