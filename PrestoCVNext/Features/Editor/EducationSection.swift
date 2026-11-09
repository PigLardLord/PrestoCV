import PrestoCVPresentation
import SwiftUI

/// The studies: the degree, the school, when, and a description, which shows for a new row too. A note under the period
/// says why it is not stored, once the person has left it.
struct EducationSection: View {
    @Bindable var editor: EditorViewModel
    let focus: FocusState<RowFocus?>.Binding

    var body: some View {
        RowsSection(
            editor: editor, section: .education, rows: editor.content.education, name: \.rowName, first: .educationDegree,
            focus: focus
        ) { row, fields in
            let study = $editor.content.education[row: row.id, or: row]
            fields.line("editor.field.degree", study.degree, .educationDegree)
            fields.line("editor.field.school", study.school, .educationSchool)
            PeriodField(
                period: study.period, field: .educationPeriod, current: "editor.period.current.study",
                problem: editor.problem(of: .educationPeriod, row: row.id), row: row.id, focus: focus,
                picked: { editor.fieldWasLeft(.educationPeriod, row: row.id) }
            )
            fields.paragraph("editor.field.description", study.description, .educationDescription)
        }
    }
}
