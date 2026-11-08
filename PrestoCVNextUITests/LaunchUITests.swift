import XCTest

/// The new app makes its one composition from the arguments it was launched with, and its first screen names the state the
/// composition reached: ready, or failed with the failure's code.
final class LaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// On an empty store of its own, the composition is ready.
    @MainActor
    func testALaunchOnAnEmptyStoreIsReady() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-PrestoCVNextEmptyStorage"]
        app.launch()
        XCTAssertEqual(reachedState(of: app), "root.ready")
    }

    /// A launch argument the app cannot read fails the launch with its code, and the app makes nothing.
    @MainActor
    func testAnUnreadableLaunchArgumentFailsTheLaunchWithItsCode() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-PrestoCVNextStorage", "../outside"]
        app.launch()
        XCTAssertEqual(reachedState(of: app), "root.failed.launchFixturesRejected")
    }

    /// The identifier of the first screen once the composition is no longer loading, or nil when it never got there.
    @MainActor
    private func reachedState(of app: XCUIApplication) -> String? {
        let reached = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'root.' AND identifier != 'root.loading'"))
            .firstMatch
        guard reached.waitForExistence(timeout: 30) else { return nil }
        return reached.identifier
    }
}
