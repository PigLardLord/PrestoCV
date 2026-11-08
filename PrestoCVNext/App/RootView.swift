import PrestoCVComposition
import SwiftUI

/// The first screen: it shows what the holder's composition has reached. While the composition is launching it shows the
/// loading state, and when it failed the error screen with a retry. The identifiers name each state for the UI tests; the
/// shell replaces the ready state in step 5-9b.
struct RootView: View {
    /// The app's one composition holder, made once for the whole process
    let holder: CompositionHolder

    var body: some View {
        content
            .task { holder.start() }
    }

    @ViewBuilder
    private var content: some View {
        switch holder.phase {
        case .launching:
            LoadingView("root.loading")
                .accessibilityIdentifier("root.loading")
        case .ready:
            Color.clear
                .accessibilityElement()
                .accessibilityIdentifier("root.ready")
        case .failed(let failure):
            CompositionFailedView(failure: failure, retry: holder.retry)
        }
    }
}
