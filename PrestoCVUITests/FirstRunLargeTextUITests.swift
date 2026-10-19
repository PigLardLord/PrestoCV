import XCTest

/// At the largest text size the welcome alone used to fill the first screen, and every way to start was below it.
/// The person reaches them without scrolling, whatever the device can do with AI. The AI draft that is off keeps its
/// sentence, in German too, where the words are long.
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
    private func launchAtTheLargestTextSize(aiAvailability: String, language: String = "en", locale: String = "en_US") {
        app.launchArguments += [
            "-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-PrestoCVUITestsEmptyStorage",
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

        assertOnScreenWithoutScrolling([blank, examples, aiDraft])
        XCTAssertFalse(app.buttons[aiDraft].isEnabled, "The AI draft should be off on a device that cannot run the model")
    }

    /// The German titles and the sentence are the longest: the AI draft that is off still fits the width of the
    /// screen, below the ways to start that work, and reads its sentence.
    func testTheAIDraftThatIsOffFitsTheScreenInGerman() throws {
        launchAtTheLargestTextSize(aiAvailability: "deviceNotEligible", language: "de", locale: "de_DE")
        let examplesButton = app.buttons["Mit einem Beispiel beginnen"]
        XCTAssertTrue(examplesButton.waitForExistence(timeout: 20), "The first run should offer the examples")
        let aiDraftButton = app.buttons["Meinen Lebenslauf mit KI entwerfen"]
        XCTAssertTrue(aiDraftButton.exists, "The first run should show the AI draft")

        app.scrollTo(aiDraftButton)

        XCTAssertTrue(aiDraftButton.isHittable, "The AI draft should be on screen once scrolled to")
        XCTAssertFalse(aiDraftButton.isEnabled, "The AI draft should be off")
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(aiDraftButton.frame.minX, screen.minX, "The AI draft should not run off the left of the screen")
        XCTAssertLessThanOrEqual(aiDraftButton.frame.maxX, screen.maxX, "The AI draft should not run off the right of the screen")
        XCTAssertFalse(aiDraftButton.frame.intersects(examplesButton.frame), "The AI draft should not cover the examples")
        XCTAssertEqual(aiDraftButton.value as? String, Self.notOnThisDeviceInGerman, "VoiceOver should read why, after the title")
        add(app.keptScreenshot(named: "First run, German, largest text, device not eligible"))
    }

    private static let notOnThisDeviceInGerman = "Dieses Gerät unterstützt KI-Entwürfe noch nicht. "
        + "Wir arbeiten daran, sie auf weitere Geräte zu bringen. "
        + "Bis dahin können Sie Ihren Lebenslauf selbst erstellen oder mit einem Beispiel beginnen."

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
