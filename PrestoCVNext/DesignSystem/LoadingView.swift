import SwiftUI

/// A screen that waits: a progress indicator and what it waits for. The indicator and the text are one element for
/// VoiceOver, and VoiceOver focus moves to it when it appears.
struct LoadingView: View {
    private let label: LocalizedStringResource
    @AccessibilityFocusState private var focused: Bool

    init(_ label: LocalizedStringResource) {
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
        .accessibilityFocused($focused)
        // A retry shows it in place of the error screen: VoiceOver moves to it and reads what it waits for
        .task { focused = true }
    }
}
