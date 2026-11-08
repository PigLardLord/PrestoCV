import PrestoCVComposition
import SwiftUI

/// The first screen: it waits for the app's one composition and names the state it reached, for the UI tests. It shows
/// nothing yet; the loading state, the error screen and the shell replace it in step 5-9.
struct RootView: View {
    /// The app's one composition, made once for the whole process
    let composition: Task<CompositionState, Never>
    @State private var reached: CompositionState?

    var body: some View {
        Color.clear
            .accessibilityElement()
            .accessibilityIdentifier(identifier)
            .task { reached = await composition.value }
    }

    private var identifier: String {
        switch reached {
        case nil: "root.loading"
        case .ready: "root.ready"
        case .failed(let failure): "root.failed.\(failure.rawValue)"
        }
    }
}
