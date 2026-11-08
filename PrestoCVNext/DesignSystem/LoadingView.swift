import SwiftUI

/// A screen that waits: a progress indicator and what it waits for. The indicator and the text are one element for
/// VoiceOver.
struct LoadingView: View {
    private let label: LocalizedStringKey

    init(_ label: LocalizedStringKey) {
        self.label = label
    }

    var body: some View {
        VStack(spacing: Spacing.medium) {
            ProgressView()
                .controlSize(.large)
            WholeWordsText(label)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
