import XCTest

/// At the largest text size the welcome alone used to fill the first screen, and every way to start was below it.
/// The person reaches them without scrolling, whatever the device can do with AI.
final class FirstRunLargeTextUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    /// Launches on an empty store at the largest text size, with the availability the debug override reports: the
    /// simulator cannot run the model itself.
    private func launchAtTheLargestTextSize(aiAvailability: String) {
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage",
            "-AIAvailabilityOverride", aiAvailability,
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()
    }

    private let aiDraft = "Draft My CV with AI"
    private let blank = "Create My First CV"
    private let examples = "Start from an example"

    func testTheWaysToStartAreOnScreenWhereTheAIDraftWorks() throws {
        launchAtTheLargestTextSize(aiAvailability: "available")

        assertOnScreenWithoutScrolling([aiDraft, blank, examples])
    }

    func testTheWaysToStartAreOnScreenWhereAppleIntelligenceIsOff() throws {
        launchAtTheLargestTextSize(aiAvailability: "appleIntelligenceNotEnabled")

        assertOnScreenWithoutScrolling([blank, examples, aiDraft])
    }

    func testTheWaysToStartAreOnScreenWhileTheModelDownloads() throws {
        launchAtTheLargestTextSize(aiAvailability: "modelNotReady")

        assertOnScreenWithoutScrolling([blank, examples, aiDraft])
    }

    func testTheWaysToStartAreOnScreenWhereTheDeviceCannotRunTheModel() throws {
        launchAtTheLargestTextSize(aiAvailability: "deviceNotEligible")

        assertOnScreenWithoutScrolling([blank, examples])
        XCTAssertFalse(app.buttons[aiDraft].exists, "A device that cannot run the model should not be offered the AI draft")
    }

    /// Each way to start can be tapped where the first screen shows it. The examples are offered once they are
    /// loaded, so the check waits for them; the welcome is still there, after them.
    private func assertOnScreenWithoutScrolling(_ actions: [String], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons[examples].waitForExistence(timeout: 20), "The first run should offer the examples", file: file, line: line)
        for action in actions {
            let button = app.buttons[action]
            XCTAssertTrue(button.exists, "The first run should offer \"\(action)\"", file: file, line: line)
            XCTAssertTrue(button.isHittable, "\"\(action)\" should be on the first screen, without scrolling", file: file, line: line)
        }
        let welcome = app.staticTexts["Welcome to PrestoCV"]
        XCTAssertTrue(welcome.exists, "The welcome should still follow the ways to start", file: file, line: line)
    }
}
