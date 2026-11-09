import SwiftUI

/// A note under a field about the text in it, such as text that cannot be read as an e-mail address: a warning symbol
/// and what to do. The symbol is for the eye; VoiceOver reads the note as one element, after the field.
struct FieldNote: View {
    private let words: LocalizedStringResource

    init(_ words: LocalizedStringResource) {
        self.words = words
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            WholeWordsText(words)
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
        .accessibilityElement(children: .combine)
    }
}
