import PrestoCVPresentation
import SwiftUI

/// The jobs: what the person did, where, when, and how it went. A note under the period says why it is not stored, once
/// the person has left it.
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
            PeriodField(
                period: job.period, field: .experiencePeriod, current: "editor.period.current.job",
                problem: editor.problem(of: .experiencePeriod, row: row.id), row: row.id, focus: focus,
                picked: { editor.fieldWasLeft(.experiencePeriod, row: row.id) }
            )
            fields.paragraph("editor.field.description", job.description, .experienceDescription)
        }
    }
}
