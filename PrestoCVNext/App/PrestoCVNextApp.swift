import PrestoCVComposition
import SwiftUI

/// The app of the new stack, built beside the released one until the switch (step 5 of the plan). Everything it shows
/// comes from `PrestoCVComposition` and `PrestoCVPresentation`.
@main
struct PrestoCVNextApp: App {
    /// The only composition of the process (R4, ADR 0008), made from the launch arguments: every window shows the same
    /// one, and a retry after a failure makes a new one.
    private static let holder = CompositionHolder(launch: {
        await Composition.launch(arguments: ProcessInfo.processInfo.arguments)
    })

    var body: some Scene {
        WindowGroup {
            RootView(holder: Self.holder)
        }
    }
}
