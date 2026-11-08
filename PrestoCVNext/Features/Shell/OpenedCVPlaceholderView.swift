import SwiftUI

/// The detail column while a CV is open: its label, until the editor takes its place.
struct OpenedCVPlaceholderView: View {
    let label: String

    var body: some View {
        ScrollView {
            Text(verbatim: label)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("shell.detail.title")
                .padding(Spacing.large)
                .readableWidth()
        }
        .navigationTitle(Text(verbatim: label))
        .inlineNavigationTitle()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shell.detail.opened")
    }
}
