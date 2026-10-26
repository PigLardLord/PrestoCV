import XCTest

/// At the largest text size the welcome alone used to fill the first screen, and every way to start was below it.
/// The person reaches them without scrolling, whatever the device can do with AI, and they keep their order: the import,
/// the AI draft, the examples, the blank CV. The dimmed AI draft fits the screen and explains itself in German too,
/// where the words are long: there the four titles take three or four lines each, more than a phone's screen holds at
/// that size, and the first run scrolls to them rather than draw them smaller than the person chose.
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

    private let importCV = "Paste or import a CV"
    private let aiDraft = "Draft My CV with AI"
    private let examples = "Start from an example"
    private let blank = "Create My First CV"

    func testTheWaysToStartAreOnScreenWhereTheAIDraftWorks() throws {
        launchAtTheLargestTextSize(aiAvailability: "available")

        assertOnScreenWithoutScrolling([importCV, aiDraft, examples, blank])
    }

    func testTheWaysToStartAreOnScreenWhereAppleIntelligenceIsOff() throws {
        launchAtTheLargestTextSize(aiAvailability: "appleIntelligenceNotEnabled")

        assertOnScreenWithoutScrolling([importCV, aiDraft, examples, blank])
    }

    func testTheWaysToStartAreOnScreenWhileTheModelDownloads() throws {
        launchAtTheLargestTextSize(aiAvailability: "modelNotReady")

        assertOnScreenWithoutScrolling([importCV, aiDraft, examples, blank])
    }

    func testTheWaysToStartAreOnScreenWhereTheDeviceCannotRunTheModel() throws {
        launchAtTheLargestTextSize(aiAvailability: "deviceNotEligible")

        assertOnScreenWithoutScrolling([importCV, aiDraft, examples, blank])
        XCTAssertEqual(app.buttons[aiDraft].value as? String, DimmedAIDraft.deviceNotEligible.announcement, "The AI draft should be unavailable")
    }

    func testTheWaysToStartAreOnScreenWhenTheReasonIsUnknown() throws {
        launchAtTheLargestTextSize(aiAvailability: "unknown")

        assertOnScreenWithoutScrolling([importCV, aiDraft, examples, blank])
        XCTAssertEqual(app.buttons[aiDraft].value as? String, DimmedAIDraft.unknown.announcement, "The AI draft should be unavailable")
    }

    /// The German titles are the longest: the dimmed AI draft still fits the width of the screen, between the import
    /// and the examples, reads its explanation, and a tap shows it.
    func testTheDimmedAIDraftFitsTheScreenInGerman() throws {
        launchAtTheLargestTextSize(aiAvailability: "deviceNotEligible", language: "de", locale: "de_DE")
        let examplesButton = app.buttons["Mit einem Beispiel beginnen"]
        XCTAssertTrue(examplesButton.waitForExistence(timeout: 20), "The first run should offer the examples")
        let aiDraftButton = app.buttons["Meinen Lebenslauf mit KI entwerfen"]
        XCTAssertTrue(aiDraftButton.exists, "The first run should show the AI draft")

        app.scrollTo(aiDraftButton)

        XCTAssertTrue(aiDraftButton.isHittable, "The AI draft should be on screen once scrolled to")
        XCTAssertTrue(aiDraftButton.isEnabled, "The dimmed AI draft should still be activated to explain itself")
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(aiDraftButton.frame.minX, screen.minX, "The AI draft should not run off the left of the screen")
        XCTAssertLessThanOrEqual(aiDraftButton.frame.maxX, screen.maxX, "The AI draft should not run off the right of the screen")
        XCTAssertFalse(aiDraftButton.frame.intersects(examplesButton.frame), "The AI draft should not cover the examples")
        XCTAssertEqual(aiDraftButton.value as? String, "Nicht verfügbar. " + Self.notOnThisDeviceInGerman, "VoiceOver should read that it is unavailable, and why")
        add(app.keptScreenshot(named: "First run, German, largest text, device not eligible"))

        aiDraftButton.tap()

        XCTAssertTrue(app.text(Self.notOnThisDeviceInGerman).waitForExistence(timeout: 10), "A tap should show the full explanation")
        add(app.keptScreenshot(named: "First run, German, largest text, device not eligible, explanation"))
        app.barButton("Fertig").tap()
    }

    private static let notOnThisDeviceInGerman = "Dieses Gerät unterstützt keine KI-Entwürfe. "
        + "Sie können Ihren Lebenslauf selbst erstellen oder mit einem Beispiel beginnen."

    /// Each way to start can be tapped where the first screen shows it, and they come in the order given, from the top.
    /// The examples are offered once they are loaded, so the check waits for them; the welcome is still there, after
    /// them.
    private func assertOnScreenWithoutScrolling(_ actions: [String], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons[examples].waitForExistence(timeout: 20), "The first run should offer the examples", file: file, line: line)
        for action in actions {
            let button = app.buttons[action]
            XCTAssertTrue(button.exists, "The first run should offer \"\(action)\"", file: file, line: line)
            XCTAssertTrue(button.isHittable, "\"\(action)\" should be on the first screen, without scrolling", file: file, line: line)
        }
        for (above, below) in zip(actions, actions.dropFirst()) {
            XCTAssertLessThan(app.buttons[above].frame.minY, app.buttons[below].frame.minY, "\"\(above)\" should come before \"\(below)\"", file: file, line: line)
        }
        let welcome = app.staticTexts["Welcome to PrestoCV"]
        XCTAssertTrue(welcome.exists, "The welcome should still follow the ways to start", file: file, line: line)
    }
}
