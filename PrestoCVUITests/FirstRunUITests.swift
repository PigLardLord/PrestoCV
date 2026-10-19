import XCTest

/// The first run leads with the AI draft where the device can run it. Elsewhere it shows the draft off, after what
/// works, with the sentence that says why, and the welcome does not promise it where the device cannot make it.
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

    /// A text on screen. A query by a label longer than 128 characters needs a predicate.
    private func text(_ label: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// The sentence under the AI draft on a device that cannot run the model.
    private let notOnThisDevice = "This device doesn't support AI drafts yet. We're working on bringing them to more devices. "
        + "Meanwhile, you can create your CV by hand or start from an example."

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
        let reason = aiDraft.value as? String ?? ""
        XCTAssertTrue(reason.hasPrefix("Apple Intelligence is turned off"), "VoiceOver should read how to turn Apple Intelligence on, after the title")
        XCTAssertFalse(text(reason).exists, "VoiceOver should read the sentence once, with the AI draft")
    }

    func testTheAIDraftIsOffAndSaysWhyWhereTheDeviceCannotRunIt() throws {
        launch(aiAvailability: "deviceNotEligible")

        let blank = app.buttons["Create My First CV"]
        XCTAssertTrue(blank.waitForExistence(timeout: 20), "The first run should offer a blank CV")
        XCTAssertTrue(aiDraft.exists, "The first run should show the AI draft on a device that cannot make it yet")
        XCTAssertFalse(aiDraft.isEnabled, "The AI draft should be off, and VoiceOver should read it as dimmed")
        XCTAssertLessThan(blank.frame.minY, aiDraft.frame.minY, "What works now should come first")
        XCTAssertEqual(aiDraft.value as? String, notOnThisDevice, "VoiceOver should read why, after the title")
        XCTAssertFalse(text(notOnThisDevice).exists, "VoiceOver should read the sentence once, with the AI draft")
        let welcome = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Write your CV, keep it on your device")).firstMatch
        XCTAssertTrue(welcome.exists, "The welcome should speak of what the device can do")
        let promise = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "AI drafts your CV")).firstMatch
        XCTAssertFalse(promise.exists, "The welcome should not promise AI on a device that cannot run it")
    }
}
