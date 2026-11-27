import SwiftUI

/// A field of several lines under its label, as `LabeledField` is for a line of text. Its return key starts a new line,
/// and it is a few lines tall before the person writes, taller at a larger text size.
struct ParagraphField<Focus: Hashable>: View {
    private let label: LocalizedStringResource
    @Binding private var text: String
    private let focus: FocusState<Focus?>.Binding
    private let name: Focus
    @ScaledMetric(relativeTo: .body) private var minimumHeight = ParagraphHeight.minimum

    /// - Parameter focus: The focus of the form, which holds `name` while the person types in this field.
    init(_ label: LocalizedStringResource, text: Binding<String>, focus: FocusState<Focus?>.Binding, as name: Focus) {
        self.label = label
        _text = text
        self.focus = focus
        self.name = name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            FieldLabel(label)
            TextEditor(text: $text)
                .frame(minHeight: minimumHeight)
                .focused(focus, equals: name)
                .accessibilityLabel(Text(label))
        }
        .focusingOnTap(focus, as: name)
    }
}
