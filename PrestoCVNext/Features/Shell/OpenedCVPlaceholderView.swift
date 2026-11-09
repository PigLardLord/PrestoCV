import SwiftUI

/// The detail column while a CV is open: its label, or "New CV" for a draft, until the editor takes its place.
struct OpenedCVPlaceholderView: View {
    let title: Text

    var body: some View {
        ScrollView {
            title
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("shell.detail.title")
                .padding(Spacing.large)
                .readableWidth()
        }
        .navigationTitle(title)
        .inlineNavigationTitle()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shell.detail.opened")
    }
}
