import PrestoCVPresentation
import SwiftUI

/// The jobs: what the person did, where, when, and how it went. A note under the period says why it is not stored, once
/// the person has left it.
struct ExperienceSection: View {
    @Bindable var editor: EditorViewModel
    let focus: FocusState<RowFocus?>.Binding

    var body: some View {
        RowsSection(
            editor: editor, section: .experiences, rows: editor.content.experiences, name: \.rowName,
            summary: \.summary, focus: focus
        ) { row, fields in
            JobFields(editor: editor, row: row, fields: fields, onPage: false)
        }
    }
}

/// The fields of one job, in the form or on the job's page: the job, the company and the city; then when; then what the
/// person did there.
struct JobFields: View {
    @Bindable var editor: EditorViewModel
    let row: ExperienceRow
    let fields: RowFields
    let onPage: Bool

    var body: some View {
        let job = $editor.content.experiences[row: row.id, or: row]
        EntryGroup(onPage: onPage) {
            fields.line("editor.field.role", job.role, .experienceRole)
            fields.line("editor.field.company", job.company, .experienceCompany)
            fields.line("editor.field.location", job.location, .experienceLocation)
        }
        EntryGroup(onPage: onPage, title: "editor.entry.dates") {
            PeriodField(
                period: job.period, field: .experiencePeriod, current: "editor.period.current.job",
                problem: editor.problem(of: .experiencePeriod, row: row.id), row: row.id, focus: fields.focus,
                picked: { editor.fieldWasLeft(.experiencePeriod, row: row.id) }
            )
        }
        EntryGroup(onPage: onPage, title: "editor.entry.whatYouDid") {
            fields.paragraph("editor.field.description", job.description, .experienceDescription)
        }
    }
}
