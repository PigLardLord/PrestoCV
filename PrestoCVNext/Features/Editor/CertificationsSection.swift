import PrestoCVPresentation
import SwiftUI

/// The certifications: the name, who issued it and when, a link and a description. The year shows for a new row too,
/// empty until the person writes one.
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
            fields.line("editor.field.year", certification.issued.year, .certificationIssued)
            fields.line("editor.field.link", certification.link, .certificationLink)
            fields.paragraph("editor.field.description", certification.description, .certificationDescription)
        }
    }
}
