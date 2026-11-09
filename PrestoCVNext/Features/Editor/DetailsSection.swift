import PrestoCVPresentation
import SwiftUI

/// The details of the CV in the order the PDF shows them: its name, the person, how to reach them, and the summary. The
/// e-mail address and the phone are stacked, never side by side. A note under a contact field says its text cannot be
/// read, once the person has left the field.
struct DetailsSection: View {
    @Bindable var editor: EditorViewModel
    let focus: FocusState<EditorField?>.Binding

    var body: some View {
        Section("editor.details") {
            LabeledField("editor.field.title", text: $editor.content.title, focus: focus, as: .title)
                .fieldInput(EditorField.title.input)
                .accessibilityIdentifier("editor.field.title")
            LabeledField("editor.field.fullName", text: $editor.content.fullName, focus: focus, as: .fullName)
                .fieldInput(EditorField.fullName.input)
                .accessibilityIdentifier("editor.field.fullName")
            LabeledField(
                "editor.field.professionalTitle", text: $editor.content.professionalTitle, focus: focus, as: .professionalTitle
            )
            .fieldInput(EditorField.professionalTitle.input)
            .accessibilityIdentifier("editor.field.professionalTitle")
            VStack(alignment: .leading, spacing: Spacing.small) {
                LabeledField("editor.field.email", text: $editor.content.email, focus: focus, as: .email)
                    .fieldInput(EditorField.email.input)
                    .accessibilityIdentifier("editor.field.email")
                if hasProblem(.email) {
                    FieldNote("editor.note.email")
                        .accessibilityIdentifier("editor.note.email")
                }
            }
            VStack(alignment: .leading, spacing: Spacing.small) {
                LabeledField("editor.field.phone", text: $editor.content.phone, focus: focus, as: .phone)
                    .fieldInput(EditorField.phone.input)
                    .accessibilityIdentifier("editor.field.phone")
                if hasProblem(.phone) {
                    FieldNote("editor.note.phone")
                        .accessibilityIdentifier("editor.note.phone")
                }
            }
            LabeledField("editor.field.location", text: $editor.content.location, focus: focus, as: .location)
                .fieldInput(EditorField.location.input)
                .accessibilityIdentifier("editor.field.location")
            VStack(alignment: .leading, spacing: Spacing.small) {
                LabeledField("editor.field.website", text: $editor.content.website, focus: focus, as: .website)
                    .fieldInput(EditorField.website.input)
                    .accessibilityIdentifier("editor.field.website")
                if hasProblem(.website) {
                    FieldNote("editor.note.website")
                        .accessibilityIdentifier("editor.note.website")
                }
            }
            ParagraphField("editor.field.summary", text: $editor.content.summary, focus: focus, as: .summary)
                .fieldInput(EditorField.summary.input)
                .accessibilityIdentifier("editor.field.summary")
        }
    }

    /// Whether the editor names a problem with the text of a field of the details.
    private func hasProblem(_ field: EditorField) -> Bool {
        editor.problems.contains { $0.row == nil && $0.field == field }
    }
}
