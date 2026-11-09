import SwiftUI

/// A note under a field about the text in it, such as text that cannot be read as an e-mail address: a warning symbol
/// and what to do. It is for the eye only: the field carries its words for VoiceOver (`LabeledField`), so that they are
/// read with the field and not a second time.
struct FieldNote: View {
    private let words: LocalizedStringResource

    init(_ words: LocalizedStringResource) {
        self.words = words
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
            WholeWordsText(words)
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
        .accessibilityHidden(true)
    }
}
