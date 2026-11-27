import PrestoCVPresentation
import SwiftUI

/// The first screen of a first run: the welcome, then the ways to start. At the accessibility text sizes and in compact
/// height the ways to start come first and the welcome has no symbol, so that each way can be tapped without scrolling
/// past the welcome. On a large screen it stands in the middle at the readable width.
struct FirstRunView: View {
    let firstRun: FirstRunViewModel
    /// Opens what the person chose.
    let choose: (StartChoice) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// The symbol grows with the text size, as the title under it does
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize = IconSize.hero

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .padding(Spacing.large)
                    .readableWidth()
                    // Centred in the screen while it fits, scrolled from the top when it does not
                    .frame(minHeight: proxy.size.height)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("firstRun")
    }

    /// The ways to start keep their place in the stack whatever the density, so that turning the iPhone does not close
    /// the examples sheet they opened; the welcome moves around them.
    private var content: some View {
        let isDense = StartChoicesView.isDense(dynamicTypeSize, verticalSizeClass)
        return VStack(spacing: isDense ? Spacing.medium : Spacing.large) {
            if !isDense {
                Image(systemName: "doc.text")
                    .font(.system(size: heroSize))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                welcome
            }
            StartChoicesView(firstRun: firstRun, choose: choose)
            if isDense {
                welcome
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: Spacing.small) {
            ScreenTitle("firstRun.title")
                .accessibilityIdentifier("firstRun.title")
            WholeWordsText("firstRun.message")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
