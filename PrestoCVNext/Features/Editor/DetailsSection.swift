import PrestoCVPresentation
import SwiftUI

/// The details of the CV in the order the PDF shows them: its name, the person, how to reach them, and the summary. The
/// e-mail address and the phone are stacked, never side by side. A note under a contact field says its text cannot be
/// read, once the person has left the field: the editor names the problem, and this view words it.
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
            LabeledField(
                "editor.field.email", text: $editor.content.email, focus: focus, as: .email,
                note: noteWords(of: editor.problem(of: .email), unreadable: "editor.note.email")
            )
            .fieldInput(EditorField.email.input)
            .accessibilityIdentifier("editor.field.email")
            LabeledField(
                "editor.field.phone", text: $editor.content.phone, focus: focus, as: .phone,
                note: noteWords(of: editor.problem(of: .phone), unreadable: "editor.note.phone")
            )
            .fieldInput(EditorField.phone.input)
            .accessibilityIdentifier("editor.field.phone")
            LabeledField("editor.field.location", text: $editor.content.location, focus: focus, as: .location)
                .fieldInput(EditorField.location.input)
                .accessibilityIdentifier("editor.field.location")
            LabeledField(
                "editor.field.website", text: $editor.content.website, focus: focus, as: .website,
                note: noteWords(of: editor.problem(of: .website), unreadable: "editor.note.website")
            )
            .fieldInput(EditorField.website.input)
            .accessibilityIdentifier("editor.field.website")
            ParagraphField("editor.field.summary", text: $editor.content.summary, focus: focus, as: .summary)
                .fieldInput(EditorField.summary.input)
                .accessibilityIdentifier("editor.field.summary")
        }
    }
}
