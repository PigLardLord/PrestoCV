import PrestoCVPresentation
import SwiftUI

/// The details of the CV in the order the PDF shows them: its name, the person, how to reach them, and the summary. The
/// e-mail address and the phone are stacked, never side by side. A note under a contact field says its text cannot be
/// read, once the person has left the field: the editor names the problem, and this view words it. The return key of a
/// field of one line moves to the next field (`FieldEntry`), also where the field wraps at a large text size.
struct DetailsSection: View {
    @Bindable var editor: EditorViewModel
    let focus: FocusState<EditorField?>.Binding
    /// How many times the return key made each field anew, since a field that wraps shows its line break until then.
    @State private var refreshed: [EditorField: Int] = [:]
    /// What each field was handed last, since a field can hand the same text over twice.
    @State private var entries = FieldEntries()

    var body: some View {
        Section("editor.details") {
            lineField("editor.field.title", .title, \.title)
                .accessibilityIdentifier("editor.field.title")
            lineField("editor.field.fullName", .fullName, \.fullName)
                .accessibilityIdentifier("editor.field.fullName")
            lineField("editor.field.professionalTitle", .professionalTitle, \.professionalTitle)
                .accessibilityIdentifier("editor.field.professionalTitle")
            lineField(
                "editor.field.email", .email, \.email,
                note: noteWords(of: editor.problem(of: .email), field: .email)
            )
            .accessibilityIdentifier("editor.field.email")
            lineField(
                "editor.field.phone", .phone, \.phone,
                note: noteWords(of: editor.problem(of: .phone), field: .phone)
            )
            .accessibilityIdentifier("editor.field.phone")
            lineField("editor.field.location", .location, \.location)
                .accessibilityIdentifier("editor.field.location")
            lineField(
                "editor.field.website", .website, \.website,
                note: noteWords(of: editor.problem(of: .website), field: .website)
            )
            .accessibilityIdentifier("editor.field.website")
            ParagraphField("editor.field.summary", text: $editor.content.summary, focus: focus, as: .summary)
                .fieldInput(EditorField.summary.input)
                .accessibilityIdentifier("editor.field.summary")
        }
    }

    /// A field of the details that takes one line, with the keyboard of its kind; its return key moves to the next field.
    private func lineField(
        _ label: LocalizedStringResource, _ field: EditorField, _ path: WritableKeyPath<EditorContent, String>,
        note: LocalizedStringResource? = nil
    ) -> some View {
        LabeledField(
            label, text: entry(field, path), focus: focus, as: field, note: note, refreshed: refreshed[field, default: 0]
        )
        .fieldInput(field.input)
        .submitLabel(.next)
        .onSubmit { focus.wrappedValue = field.nextDetail }
    }

    /// The field's text, through `FieldEntries`: the return key moves the focus on and leaves the text as it was, and the
    /// field is made anew, since it still shows the line break.
    private func entry(_ field: EditorField, _ path: WritableKeyPath<EditorContent, String>) -> Binding<String> {
        Binding {
            editor.content[keyPath: path]
        } set: { new in
            switch entries.entry(new, after: editor.content[keyPath: path], in: field) {
            case .text(let text):
                editor.content[keyPath: path] = text
            case .returnKey(let next):
                refreshed[field, default: 0] += 1
                focus.wrappedValue = next
            }
        }
    }
}
