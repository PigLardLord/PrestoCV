import PrestoCVComposition
import SwiftUI

/// The one error screen of a launch that could not assemble the app: the failure's code, and a retry that launches again.
struct CompositionFailedView: View {
    let failure: CompositionFailure
    let retry: () -> Void

    var body: some View {
        NavigationStack {
            ErrorStateView(
                title: "failed.title",
                message: "failed.message",
                code: "failed.code \(failure.rawValue)",
                retryTitle: "failed.retry",
                retry: retry
            )
            .navigationTitle(Text(verbatim: "PrestoCV"))
            .inlineNavigationTitle()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("root.failed.\(failure.rawValue)")
    }
}
