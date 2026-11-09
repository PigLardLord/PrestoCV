import SwiftUI

/// A field of one line under its label, with the note about its text under it when there is one. The label stays in sight
/// while the person types, and VoiceOver reads it as the field's name. The field shows no placeholder, since the label
/// says what goes in it, and it is at least as tall as the smallest tap target: a tap anywhere on it, its label and its
/// note included, puts the cursor in it. Its accessibility identifier, set on it, reaches the text field: the label and
/// the note are hidden from VoiceOver.
///
/// VoiceOver reads the note with the field, each time the field gets the focus, as custom content of high importance: a
/// hint would say it too, but a person can turn hints off, and the note is what they need to correct the text.
///
/// The keyboard and the corrections the field takes come from the modifiers around it.
struct LabeledField<Focus: Hashable>: View {
    private let label: LocalizedStringResource
    @Binding private var text: String
    private let focus: FocusState<Focus?>.Binding
    private let name: Focus
    private let note: LocalizedStringResource?

    /// - Parameters:
    ///   - focus: The focus of the form, which holds `name` while the person types in this field.
    ///   - note: What the person should know about the text in the field, such as that it cannot be read; nil when the
    ///     field shows no note.
    init(
        _ label: LocalizedStringResource, text: Binding<String>, focus: FocusState<Focus?>.Binding, as name: Focus,
        note: LocalizedStringResource? = nil
    ) {
        self.label = label
        _text = text
        self.focus = focus
        self.name = name
        self.note = note
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            FieldLabel(label)
            TextField(text: $text, prompt: Text(verbatim: "")) { Text(label) }
                .labelsHidden()
                // An empty prompt leaves the field with no name of its own
                .accessibilityLabel(Text(label))
                .accessibilityCustomContent(
                    AccessibilityCustomContentKey("field.note", id: "field.note"), note.map { Text($0) }, importance: .high
                )
                .frame(minHeight: TapTarget.minimumHeight)
                .focused(focus, equals: name)
            if let note {
                FieldNote(note)
            }
        }
        .focusingOnTap(focus, as: name)
    }
}

/// The label above a field: for the eye only, since the field carries it for VoiceOver. A tap on it goes through to the
/// field's own tap area behind it.
struct FieldLabel: View {
    private let label: LocalizedStringResource

    init(_ label: LocalizedStringResource) {
        self.label = label
    }

    var body: some View {
        WholeWordsText(label)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

extension View {
    /// Moves the focus to `name` on a tap anywhere in this labeled field that its text input does not take itself: the
    /// label, and the room around a line of text that makes the field tall enough to tap. The tap area sits behind the
    /// field, so a tap on the text still places the cursor where it lands.
    func focusingOnTap<Focus: Hashable>(_ focus: FocusState<Focus?>.Binding, as name: Focus) -> some View {
        background {
            Color.clear
                .contentShape(.rect)
                .onTapGesture { focus.wrappedValue = name }
                .accessibilityHidden(true)
        }
    }
}
