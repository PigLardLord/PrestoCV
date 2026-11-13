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
            summary: \.summary, focus: focus
        ) { row, fields in
            CertificationFields(editor: editor, row: row, fields: fields, onPage: false)
        }
    }
}

/// The fields of one certification, in the form or on its page: the name and who issued it; then when; then the link and
/// the description.
struct CertificationFields: View {
    @Bindable var editor: EditorViewModel
    let row: CertificationRow
    let fields: RowFields
    let onPage: Bool

    var body: some View {
        let certification = $editor.content.certifications[row: row.id, or: row]
        EntryGroup(onPage: onPage) {
            fields.line("editor.field.certification", certification.name, .certificationName)
            fields.line("editor.field.issuer", certification.issuer, .certificationIssuer)
        }
        EntryGroup(onPage: onPage) {
            IssuedField(
                date: certification.issued, problem: editor.problem(of: .certificationIssued, row: row.id), row: row.id,
                focus: fields.focus, picked: { editor.fieldWasLeft(.certificationIssued, row: row.id) }
            )
        }
        EntryGroup(onPage: onPage) {
            fields.line(
                "editor.field.link", certification.link, .certificationLink,
                note: noteWords(of: editor.problem(of: .certificationLink, row: row.id), field: .certificationLink)
            )
            fields.paragraph("editor.field.description", certification.description, .certificationDescription)
        }
    }
}
