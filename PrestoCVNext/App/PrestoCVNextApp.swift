import PrestoCVComposition
import SwiftUI

/// The app, which the target `PrestoCV` builds (step 5 of the plan). Everything it shows comes from
/// `PrestoCVComposition` and `PrestoCVPresentation`.
@main
struct PrestoCVNextApp: App {
    /// The only composition of the process (R4, ADR 0008), made from the launch arguments and the background time of this
    /// platform: every window shows the same one, and a retry after a failure makes a new one.
    private static let holder = CompositionHolder(launch: { settlement in
        await Composition.launch(
            arguments: ProcessInfo.processInfo.arguments, settlement: settlement, backgroundTime: SystemBackgroundTime()
        )
    })

    var body: some Scene {
        WindowGroup {
            RootView(holder: Self.holder)
        }
    }
}
