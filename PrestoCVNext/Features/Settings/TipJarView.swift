import PrestoCVPresentation
import SwiftUI

/// The tip jar: what the store offers, or why it offers nothing. It reads the offers when it opens, and a failure that
/// can change offers a new try. A row shows a size and its price as the store writes it, and buys that tip through the
/// store's sheet; what became of the purchase shows above the offers until the screen closes.
struct TipJarView: View {
    let tips: TipJarViewModel

    var body: some View {
        content
            .navigationTitle(Text("settings.tips.title"))
            .inlineNavigationTitle()
            .task { await tips.load() }
            .announce(tips.attempt, sentences: \.sentences, told: { _ in })
            .sensoryFeedback(.success, trigger: tips.attempt) { _, new in new == .thanked }
    }

    @ViewBuilder
    private var content: some View {
        switch tips.state {
        case .loading:
            LoadingView("settings.tips.loading")
        case .offers(let rows):
            Form {
                purchaseNotice
                introduction
                Section {
                    ForEach(rows) { row in
                        TipRowView(row: row, isBuying: tips.attempt == .buying(row.size)) {
                            Task { await tips.buy(row.size) }
                        }
                        .disabled(tips.attempt.isBuying)
                    }
                }
            }
            .formStyle(.grouped)
        case .unavailable(let reason):
            Form {
                introduction
                Section { notice(for: reason) }
            }
            .formStyle(.grouped)
        }
    }

    /// What became of the tip the person chose: nothing for a purchase running or cancelled.
    @ViewBuilder
    private var purchaseNotice: some View {
        switch tips.attempt {
        case .idle, .buying:
            EmptyView()
        case .thanked:
            Section {
                InlineNotice(actions: []) {
                    Label {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            WholeWordsText("settings.tips.thanks.title")
                                .font(.headline)
                            WholeWordsText("settings.tips.thanks.body")
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
                .accessibilityIdentifier("settings.tips.thanks")
            }
        case .pending:
            purchaseNotice("settings.tips.pending")
                .accessibilityIdentifier("settings.tips.pending")
        case .failed:
            purchaseNotice("settings.tips.purchaseFailed")
                .accessibilityIdentifier("settings.tips.purchaseFailed")
        case .unreachable:
            purchaseNotice("settings.tips.unreachable")
                .accessibilityIdentifier("settings.tips.purchaseUnreachable")
        }
    }

    /// A notice with no button: the rows below are the new try.
    private func purchaseNotice(_ words: LocalizedStringResource) -> some View {
        Section {
            InlineNotice(actions: []) {
                WholeWordsText(words)
            }
        }
    }

    private var introduction: some View {
        Section {
            Text("settings.tips.intro")
                .accessibilityIdentifier("settings.tips.intro")
        }
    }

    @ViewBuilder
    private func notice(for reason: TipUnavailability) -> some View {
        switch reason {
        case .notAllowed:
            InlineNotice(actions: []) {
                WholeWordsText("settings.tips.notAllowed")
            }
            .accessibilityIdentifier("settings.tips.notAllowed")
        case .unreachable:
            retryNotice { WholeWordsText("settings.tips.unreachable") }
        case .noOffers:
            retryNotice { WholeWordsText("settings.tips.noOffers") }
        case .failed:
            retryNotice { WholeWordsText("settings.tips.failed") }
        }
    }

    private func retryNotice(@ViewBuilder _ message: () -> some View) -> some View {
        InlineNotice(actionTitle: "settings.tips.retry", actionIdentifier: "settings.tips.retry",
                     action: { Task { await tips.retry() } }, message: message)
    }
}

/// A size and its price, one button that buys that tip. While it buys, a spinner takes the place of the price. The price
/// goes under the name at the accessibility sizes.
private struct TipRowView: View {
    let row: TipRow
    let isBuying: Bool
    let buy: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.small))
            : AnyLayout(HStackLayout(spacing: Spacing.small))
        Button(action: buy) {
            layout {
                Text(name)
                if !textSize.isAccessibilitySize {
                    Spacer(minLength: Spacing.small)
                }
                if isBuying {
                    ProgressView()
                } else {
                    Text(verbatim: row.price)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: TapTarget.minimumHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityValue(isBuying ? Text("settings.tips.row.buying") : Text(verbatim: ""))
        .accessibilityHint(Text("settings.tips.row.hint"))
        .accessibilityIdentifier("settings.tips.row.\(String(describing: row.size))")
    }

    private var name: LocalizedStringResource {
        switch row.size {
        case .small: "settings.tips.small"
        case .medium: "settings.tips.medium"
        case .large: "settings.tips.large"
        }
    }
}

extension TipAttempt {
    /// Whether a purchase runs, so that no row starts a second one.
    fileprivate var isBuying: Bool {
        if case .buying = self { true } else { false }
    }

    /// What VoiceOver says when the purchase ends: the notice's words. A purchase running or cancelled says nothing.
    fileprivate var sentences: [LocalizedStringResource] {
        switch self {
        case .idle, .buying: []
        case .thanked: ["settings.tips.thanks.title", "settings.tips.thanks.body"]
        case .pending: ["settings.tips.pending"]
        case .failed: ["settings.tips.purchaseFailed"]
        case .unreachable: ["settings.tips.unreachable"]
        }
    }
}
