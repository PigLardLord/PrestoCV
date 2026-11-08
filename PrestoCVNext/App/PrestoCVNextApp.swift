import SwiftUI

/// The app of the new stack, built beside the released one until the switch (step 5 of the plan). It shows an empty
/// window until the shell arrives; everything it shows will come from `PrestoCVComposition` and `PrestoCVPresentation`.
@main
struct PrestoCVNextApp: App {
    var body: some Scene {
        WindowGroup {
            Color.clear
        }
    }
}
