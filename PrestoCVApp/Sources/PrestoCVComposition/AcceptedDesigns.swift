#if DEBUG
import CVDesignCatalog

/// The gate of the UI tests that are not about the designs or the first launch: it accepts every bundled design without
/// rendering it, so that an export soon after a launch on an empty folder does not wait for the renders of the real gate
/// (three designs in each of their font schemes), which the app runs once it is open (#566). The sync, its validator and the
/// design store stay the real ones. It exists
/// in Debug builds only (`ReleaseHygieneTests`) and is chosen by the composition from a launch argument (`LaunchFixtures`)
/// that needs a folder of the fixture, so the device's own design store never holds a design that no render checked.
struct AcceptedDesigns: DesignRenderingGate {
    func verify(_ design: ValidatedDesign) async throws {
        // Accepted as it is: the UI tests that check the designs launch without the fixture
    }
}
#endif
