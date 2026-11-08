import SwiftUI

/// The detail column while no CV is open.
struct DetailPlaceholderView: View {
    var body: some View {
        EmptyStateView(symbol: "doc.text", title: "shell.nothing.title", message: "shell.nothing.message")
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("shell.detail.empty")
    }
}
