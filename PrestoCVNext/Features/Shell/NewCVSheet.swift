import PrestoCVPresentation
import SwiftUI

/// The ways to start another CV, which "+" in the sidebar opens: the same choices as the first run, without its welcome.
struct NewCVSheet: View {
    let firstRun: FirstRunViewModel
    /// The person chose a way to start; the presenter closes the sheet and then opens it.
    let choose: (StartChoice) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                StartChoicesView(firstRun: firstRun, choose: choose)
                    .padding(Spacing.large)
                    .readableWidth()
            }
            .navigationTitle(Text("start.title"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("start.cancel") { dismiss() }
                        .accessibilityIdentifier("start.cancel")
                }
            }
        }
    }
}
