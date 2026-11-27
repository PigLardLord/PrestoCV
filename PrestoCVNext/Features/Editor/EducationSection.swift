import PrestoCVPresentation
import SwiftUI

/// The studies: the degree, the school, when, and a description, which shows for a new row too. A note under the period
/// says why it is not stored, once the person has left it.
struct EducationSection: View {
    @Bindable var editor: EditorViewModel
    let focus: FocusState<RowFocus?>.Binding

    var body: some View {
        RowsSection(
            editor: editor, section: .education, rows: editor.content.education, name: \.rowName,
            summary: \.summary, focus: focus
        ) { row, fields in
            DegreeFields(editor: editor, row: row, fields: fields, onPage: false)
        }
    }
}

/// The fields of one study, in the form or on its page: the degree and the school; then when; then the description.
struct DegreeFields: View {
    @Bindable var editor: EditorViewModel
    let row: EducationRow
    let fields: RowFields
    let onPage: Bool

    var body: some View {
        let study = $editor.content.education[row: row.id, or: row]
        EntryGroup(onPage: onPage) {
            fields.line("editor.field.degree", study.degree, .educationDegree)
            fields.line("editor.field.school", study.school, .educationSchool)
        }
        EntryGroup(onPage: onPage, title: "editor.entry.dates") {
            PeriodField(
                period: study.period, field: .educationPeriod, current: "editor.period.current.study",
                problem: editor.problem(of: .educationPeriod, row: row.id), row: row.id, focus: fields.focus,
                picked: { editor.fieldWasLeft(.educationPeriod, row: row.id) }
            )
        }
        EntryGroup(onPage: onPage) {
            fields.paragraph("editor.field.description", study.description, .educationDescription)
        }
    }
}
