import XCTest

/// The new app makes its one composition from the arguments it was launched with, and its first screen names the state the
/// composition reached: ready, or failed with the failure's code.
final class LaunchUITests: RuntimeIssueFailingTestCase {
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

    // MARK: One launch in dark mode and one in landscape (#416; the launch in each language is LanguagePassUITests)

    /// The tests that run next start upright, also after a test that turned the device stopped on a failure.
    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    /// Launches on an empty store and waits for the first run's welcome, as the English catalog writes it.
    @MainActor
    private func launchFirstRun() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage"]
        app.launch()
        let title = app.descendants(matching: .any).matching(identifier: "firstRun.title").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 30), "The first run should show its welcome")
        XCTAssertEqual(title.label, "Welcome to PrestoCV")
        return app
    }

    /// The tests that run next get back the appearance the device had, also when this one stops on a failure.
    @MainActor
    func testLaunchesInDarkMode() throws {
        let before = XCUIDevice.shared.appearance
        addTeardownBlock { await MainActor.run { XCUIDevice.shared.appearance = before } }
        XCUIDevice.shared.appearance = .dark
        _ = launchFirstRun()
    }

    /// The first launch only finds out whether this screen has a landscape: the launch under test starts with the device
    /// already on its side. Skipped only where no app turns, as on the outer screen of the iPhone Duo.
    @MainActor
    func testLaunchesInLandscape() throws {
        let upright = launchFirstRun()
        guard try upright.turnsToLandscape() else {
            XCTFail("The first run should turn to landscape")
            return
        }
        upright.terminate()
        let app = launchFirstRun()
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.width, window.height, "The first run should start in landscape")
        XCTAssertTrue(app.buttons["start.blank"].exists, "The first run should offer its ways to start in landscape")
    }

    /// The identifier of the first screen once the composition is no longer loading. When it never gets there, the
    /// identifier the first screen still shows (`root.loading` for a composition that never ends), or nil when there is no
    /// first screen at all.
    @MainActor
    private func reachedState(of app: XCUIApplication) -> String? {
        let reached = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'root.' AND identifier != 'root.loading'"))
            .firstMatch
        guard reached.waitForExistence(timeout: 30) else {
            let shown = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'root.'"))
                .firstMatch
            return shown.exists ? shown.identifier : nil
        }
        return reached.identifier
    }
}
