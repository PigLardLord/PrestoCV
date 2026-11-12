import PrestoCVPresentation
import SwiftUI

/// The studies: the degree, the school, and a description, which shows for a new row too.
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
            fields.paragraph("editor.field.description", study.description, .educationDescription)
        }
    }
}
