import PrestoCVPresentation
import SwiftUI

/// The tip jar: what the store offers, or why it offers nothing. It reads the offers when it opens, and a failure that
/// can change offers a new try. A row only shows a size and its price as the store writes it.
struct TipJarView: View {
    let tips: TipJarViewModel

    var body: some View {
        content
            .navigationTitle(Text("settings.tips.title"))
            .inlineNavigationTitle()
            .task { await tips.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch tips.state {
        case .loading:
            LoadingView("settings.tips.loading")
        case .offers(let rows):
            Form {
                introduction
                Section {
                    ForEach(rows) { row in
                        TipRowView(row: row)
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

/// A size and its price, read as one element. The price goes under the name at the accessibility sizes.
private struct TipRowView: View {
    let row: TipRow
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.small))
            : AnyLayout(HStackLayout(spacing: Spacing.small))
        layout {
            Text(name)
            if !textSize.isAccessibilitySize {
                Spacer(minLength: Spacing.small)
            }
            Text(verbatim: row.price)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: TapTarget.minimumHeight)
        .accessibilityElement(children: .combine)
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
