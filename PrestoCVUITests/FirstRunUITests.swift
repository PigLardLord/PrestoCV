import XCTest

/// The first run leads with the AI draft where the device can draft now. Elsewhere it shows the draft dimmed, after
/// the ways to start that work, with a line that says why; a tap shows the full explanation, and the welcome does not
/// promise the draft.
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

    func testTheAIDraftIsDimmedLastAndExplainsWhileTheModelDownloads() throws {
        checkTheDimmedAIDraft(.modelNotReady)
    }

    func testTheAIDraftIsDimmedLastAndExplainsWhereAppleIntelligenceIsOff() throws {
        checkTheDimmedAIDraft(.appleIntelligenceNotEnabled)
    }

    func testTheAIDraftIsDimmedLastAndExplainsWhereTheDeviceCannotRunIt() throws {
        checkTheDimmedAIDraft(.deviceNotEligible)
    }

    func testTheAIDraftIsDimmedLastAndExplainsWhenTheReasonIsUnknown() throws {
        checkTheDimmedAIDraft(.unknown)
    }

    /// The AI draft is there, dimmed, after the ways to start that work; a tap explains it; the welcome promises no
    /// AI draft.
    private func checkTheDimmedAIDraft(_ draft: DimmedAIDraft, file: StaticString = #filePath, line: UInt = #line) {
        launch(aiAvailability: draft.override)

        let examples = app.buttons["Start from an example"]
        XCTAssertTrue(examples.waitForExistence(timeout: 20), "The first run should offer the examples", file: file, line: line)
        XCTAssertTrue(aiDraft.exists, "The first run should show the AI draft", file: file, line: line)
        XCTAssertLessThan(examples.frame.minY, aiDraft.frame.minY, "The AI draft should come last", file: file, line: line)
        let welcome = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Write your CV, keep it on your device")).firstMatch
        XCTAssertTrue(welcome.exists, "The welcome should speak of what the device can do now", file: file, line: line)
        let promise = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "AI drafts your CV")).firstMatch
        XCTAssertFalse(promise.exists, "The welcome should not promise the AI draft", file: file, line: line)

        app.checkDimmedAIDraft(aiDraft, says: draft, file: file, line: line)
    }
}
