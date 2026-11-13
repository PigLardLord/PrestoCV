import SwiftUI

/// A screen or a column that has nothing to show yet: a symbol, a title, a message that says what to do, and the actions
/// it offers, if any (`NoticeButtons`). It scrolls, so that it stays usable at the largest text size.
struct EmptyStateView: View {
    private let symbol: String
    private let title: LocalizedStringResource
    private let message: LocalizedStringResource
    private let actions: [NoticeAction]
    /// The symbol grows with the text size, as the text beside it does
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize = IconSize.state

    /// `symbol` is the name of a system symbol.
    init(symbol: String, title: LocalizedStringResource, message: LocalizedStringResource) {
        self.init(symbol: symbol, title: title, message: message, actions: [])
    }

    /// An empty state with the actions it offers, in the order given, under its message.
    init(symbol: String, title: LocalizedStringResource, message: LocalizedStringResource, actions: [NoticeAction]) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actions = actions
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.medium) {
                Image(systemName: symbol)
                    .font(.system(size: symbolSize))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                ScreenTitle(title)
                WholeWordsText(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if !actions.isEmpty {
                    NoticeButtons(actions, alignment: .center)
                }
            }
            .padding(Spacing.large)
            .readableWidth()
        }
    }
}
