import SwiftUI

/// A screen or a column that has nothing to show yet: a symbol, a title and a message that says what to do. It scrolls,
/// so that it stays usable at the largest text size.
struct EmptyStateView: View {
    private let symbol: String
    private let title: LocalizedStringResource
    private let message: LocalizedStringResource

    /// `symbol` is the name of a system symbol.
    init(symbol: String, title: LocalizedStringResource, message: LocalizedStringResource) {
        self.symbol = symbol
        self.title = title
        self.message = message
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.medium) {
                Image(systemName: symbol)
                    .font(.system(size: IconSize.state))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                ScreenTitle(title)
                WholeWordsText(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.large)
            .readableWidth()
        }
    }
}
