import XCTest

/// The first run leads with the import of a CV the person already has, and the blank CV comes last. The AI draft follows
/// the import, then the examples. Where the device cannot draft now, the draft is shown dimmed in the same place, with
/// a line that says why; a tap shows the full explanation, and the welcome does not promise the draft.
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

    /// The ways to start, from the top: the import, the AI draft, the examples, the blank CV.
    private let waysToStart = ["Paste or import a CV", "Draft My CV with AI", "Start from an example", "Create My First CV"]

    private func checkTheOrderOfTheWaysToStart(file: StaticString = #filePath, line: UInt = #line) {
        for way in waysToStart {
            XCTAssertTrue(app.buttons[way].waitForExistence(timeout: 20), "The first run should offer \"\(way)\"", file: file, line: line)
        }
        for (above, below) in zip(waysToStart, waysToStart.dropFirst()) {
            XCTAssertLessThan(app.buttons[above].frame.minY, app.buttons[below].frame.minY, "\"\(above)\" should come before \"\(below)\"", file: file, line: line)
        }
    }

    func testTheImportLeadsTheFirstRunAndTheAIDraftFollowsItAndOpensTheAIScreen() throws {
        launch(aiAvailability: "available")

        checkTheOrderOfTheWaysToStart()

        app.scrollTo(aiDraft)
        aiDraft.tap()

        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI draft should open the AI screen")
    }

    func testTheAIDraftIsDimmedAfterTheImportAndExplainsWhileTheModelDownloads() throws {
        checkTheDimmedAIDraft(.modelNotReady)
    }

    func testTheAIDraftIsDimmedAfterTheImportAndExplainsWhereAppleIntelligenceIsOff() throws {
        checkTheDimmedAIDraft(.appleIntelligenceNotEnabled)
    }

    func testTheAIDraftIsDimmedAfterTheImportAndExplainsWhereTheDeviceCannotRunIt() throws {
        checkTheDimmedAIDraft(.deviceNotEligible)
    }

    func testTheAIDraftIsDimmedAfterTheImportAndExplainsWhenTheReasonIsUnknown() throws {
        checkTheDimmedAIDraft(.unknown)
    }

    func testVoiceControlAndSwitchControlCanOpenTheExplanation() throws {
        launch(aiAvailability: DimmedAIDraft.deviceNotEligible.override)
        XCTAssertTrue(aiDraft.waitForExistence(timeout: 20), "The first run should show the AI draft")

        app.activateAsAnAssistiveTechnology(aiDraft, says: .deviceNotEligible)
    }

    /// The AI draft is there, dimmed, after the import and before the examples; a tap explains it; the welcome promises
    /// no AI draft.
    private func checkTheDimmedAIDraft(_ draft: DimmedAIDraft, file: StaticString = #filePath, line: UInt = #line) {
        launch(aiAvailability: draft.override)

        checkTheOrderOfTheWaysToStart(file: file, line: line)
        let welcome = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Write your CV, keep it on your device")).firstMatch
        XCTAssertTrue(welcome.exists, "The welcome should speak of what the device can do now", file: file, line: line)
        let promise = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "AI drafts your CV")).firstMatch
        XCTAssertFalse(promise.exists, "The welcome should not promise the AI draft", file: file, line: line)

        app.checkDimmedAIDraft(aiDraft, says: draft, file: file, line: line)
    }
}
