import SwiftUI

/// A screen for something that went wrong: a symbol, a title, a message, the code that names the failure and the action
/// that tries again. VoiceOver focus moves to the title when it appears. It scrolls, so that it stays usable at the largest text size.
struct ErrorStateView: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey
    private let code: LocalizedStringKey
    private let retryTitle: LocalizedStringKey
    private let retry: () -> Void
    @AccessibilityFocusState private var titleFocused: Bool

    /// `code` is the line that names the failure, already formed with the failure's code in it.
    init(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        code: LocalizedStringKey,
        retryTitle: LocalizedStringKey,
        retry: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.code = code
        self.retryTitle = retryTitle
        self.retry = retry
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.medium) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: IconSize.state))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                ScreenTitle(title)
                    .accessibilityFocused($titleFocused)
                WholeWordsText(message)
                    .multilineTextAlignment(.center)
                WholeWordsText(code)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("error.code")
                PrimaryButton(retryTitle, action: retry)
                    .accessibilityIdentifier("error.retry")
            }
            .padding(Spacing.large)
            .readableWidth()
        }
        // The screen replaces the loading state: VoiceOver moves to its heading and reads it
        .task { titleFocused = true }
    }
}
