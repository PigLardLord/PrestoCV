import PrestoCVPresentation
import SwiftUI

/// The jobs: what the person did, where, and how it went. The period comes with the problems of the rows (5-11c).
struct ExperienceSection: View {
    @Bindable var editor: EditorViewModel
    let focus: FocusState<RowFocus?>.Binding

    var body: some View {
        RowsSection(
            editor: editor, section: .experiences, rows: editor.content.experiences, name: \.rowName, first: .experienceRole,
            focus: focus
        ) { row, fields in
            let job = $editor.content.experiences[row: row.id, or: row]
            fields.line("editor.field.role", job.role, .experienceRole)
            fields.line("editor.field.company", job.company, .experienceCompany)
            fields.line("editor.field.location", job.location, .experienceLocation)
            fields.paragraph("editor.field.description", job.description, .experienceDescription)
        }
    }
}
