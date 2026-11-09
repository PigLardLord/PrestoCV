import PrestoCVPresentation
import SwiftUI

/// The certifications: the name, who issued it and when, a link and a description. The date shows for a new row too, its
/// year empty until the person writes one.
struct CertificationsSection: View {
    @Bindable var editor: EditorViewModel
    let focus: FocusState<RowFocus?>.Binding

    var body: some View {
        RowsSection(
            editor: editor, section: .certifications, rows: editor.content.certifications, name: \.rowName,
            first: .certificationName, focus: focus
        ) { row, fields in
            let certification = $editor.content.certifications[row: row.id, or: row]
            fields.line("editor.field.certification", certification.name, .certificationName)
            fields.line("editor.field.issuer", certification.issuer, .certificationIssuer)
            IssuedField(
                date: certification.issued, problem: editor.problem(of: .certificationIssued, row: row.id), row: row.id,
                focus: focus, picked: { editor.fieldWasLeft(.certificationIssued, row: row.id) }
            )
            fields.line(
                "editor.field.link", certification.link, .certificationLink,
                note: noteWords(of: editor.problem(of: .certificationLink, row: row.id), unreadable: "editor.note.link")
            )
            fields.paragraph("editor.field.description", certification.description, .certificationDescription)
        }
    }
}
