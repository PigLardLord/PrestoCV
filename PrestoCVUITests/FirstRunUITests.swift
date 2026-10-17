import XCTest

/// The first run leads with the AI draft where the device can run it, and promises it nowhere else.
final class FirstRunUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
        app = XCUIApplication()
    }

    /// Launches on an empty store with the availability the debug override reports: the simulator cannot run the
    /// model itself.
    private func launch(aiAvailability: String) {
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage",
            "-AIAvailabilityOverride", aiAvailability,
        ]
        app.launch()
    }

    private var aiDraft: XCUIElement { app.buttons["Draft My CV with AI"] }

    func testTheAIDraftLeadsTheFirstRunAndOpensTheAIScreen() throws {
        launch(aiAvailability: "available")

        XCTAssertTrue(aiDraft.waitForExistence(timeout: 20), "The first run should offer the AI draft")
        let blank = app.buttons["Create My First CV"]
        XCTAssertTrue(blank.exists, "The first run should still offer a blank CV")
        XCTAssertLessThan(aiDraft.frame.minY, blank.frame.minY, "The AI draft should come first")
        XCTAssertTrue(app.buttons["Start from an example"].waitForExistence(timeout: 10), "The first run should still offer the examples")

        aiDraft.tap()

        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI draft should open the AI screen")
    }

    func testTheAIDraftIsOffAndSaysWhyWhereAppleIntelligenceIsOff() throws {
        launch(aiAvailability: "appleIntelligenceNotEnabled")

        let blank = app.buttons["Create My First CV"]
        XCTAssertTrue(blank.waitForExistence(timeout: 20), "The first run should offer a blank CV")
        XCTAssertTrue(aiDraft.exists, "The first run should show the AI draft the device can make once Apple Intelligence is on")
        XCTAssertFalse(aiDraft.isEnabled, "The AI draft should be off until Apple Intelligence is on")
        XCTAssertLessThan(blank.frame.minY, aiDraft.frame.minY, "What works now should come first")
        let reason = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Apple Intelligence is turned off")).firstMatch
        XCTAssertTrue(reason.exists, "The first run should say how to turn Apple Intelligence on")
    }

    func testTheFirstRunDoesNotPromiseAIWhereTheDeviceCannotRunIt() throws {
        launch(aiAvailability: "deviceNotEligible")

        XCTAssertTrue(app.buttons["Create My First CV"].waitForExistence(timeout: 20), "The first run should offer a blank CV")
        XCTAssertFalse(aiDraft.exists, "A device that cannot run the model should not be offered the AI draft")
        let mentionsAI = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "AI")).firstMatch
        XCTAssertFalse(mentionsAI.exists, "The welcome should not promise AI on a device that cannot run it")
    }
}
