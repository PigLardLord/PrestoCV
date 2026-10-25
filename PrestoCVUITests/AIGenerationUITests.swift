import XCTest

/// The AI screen can be used with VoiceOver, and with the keyboard up, and it waits for the language data a description needs.
final class AIGenerationUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
        app = XCUIApplication()
        // The simulator cannot run the model: the debug override offers the AI card all the same
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage",
            "-AIAvailabilityOverride", "available",
        ]
    }

    /// Launches the app, with the debug launch arguments of the test, if any.
    private func launch(_ arguments: [String] = []) {
        app.launchArguments += arguments
        app.launch()
    }

    /// Opens the AI screen from the card of the "New CV" screen.
    private func openTheAIScreen() {
        app.openTheNewCVScreen()
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "AI CV Generation")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The New CV screen should offer AI drafting")
        card.tap()
    }

    func testTheDescriptionFieldIsNamedByTheTitleAboveIt() throws {
        launch()
        openTheAIScreen()

        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "VoiceOver should name the description field")
    }

    /// A text view has no Return key that closes the keyboard, and the keyboard covered Generate.
    func testGenerateCanBeReachedAfterTypingTheDescription() throws {
        launch()
        openTheAIScreen()
        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should have a description to type into")
        description.tap()
        description.typeText("I have been a nurse at San Camillo hospital in Rome since 2015.")
        XCTAssertTrue(description.waitForKeyboardFocus(true), "Typing should give the description the keyboard focus")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), XCUIApplication.noSoftwareKeyboard)

        let done = app.toolbars.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The keyboard should offer a Done button")
        done.tap()
        XCTAssertTrue(description.waitForKeyboardFocus(false), "Done should take the keyboard focus from the description")
        XCTAssertTrue(waitUntil(app.keyboards.firstMatch, exists: false), "Done should close the keyboard")

        let generate = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Generate CV with AI")).firstMatch
        app.scrollTo(generate)
        XCTAssertTrue(generate.isHittable, "Generate should be reachable once the keyboard is closed")
        XCTAssertTrue(generate.isEnabled, "Generate should be on for the description just typed")
    }

    /// Going back from the AI screen used to throw the description away.
    func testTheDescriptionIsStillThereAfterGoingBack() throws {
        launch()
        openTheAIScreen()
        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should have a description to type into")
        let typed = "I have been a nurse at San Camillo hospital in Rome since 2015."
        description.tap()
        description.typeText(typed)

        app.backButton.tap()
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "AI CV Generation")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Back should return to the New CV screen")
        card.tap()

        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should open again")
        XCTAssertEqual(description.value as? String, typed, "The description should be as it was left")
    }

    // MARK: - Language data (#270)

    /// An English description, which the device can ground only with the English language data.
    private let englishDescription = "I have worked at San Camillo in Roma since 2015. I use Excel every day."
    /// The note of the overlay that covers a busy screen. Its loading view hides its own message from accessibility and is
    /// named "Processing...", which other screens also show; the note is only on this overlay.
    private let busy = "This can take up to a minute."
    private let endMessage = "This device cannot get the language data that drafts in English or German need."
    private let reminder = "Draft written by AI from your description."

    /// The device has no English data and the system never answers: the screen stays busy until the app's own 60-second bound,
    /// then says what the person can do instead, and the screen can be used again. The simulator cannot run the model, and its
    /// language data is whatever it has: the debug launch arguments script both.
    func testLanguageDataThatNeverArrivesEndsWithTheMessageAndTheScreenWorksAgain() throws {
        executionTimeAllowance = 300
        launch(["-PrestoCVUITestsScriptedDraft", "nurse", "-LanguageDataOverride", "neverArrives"])
        openTheAIScreenOnFirstRun()
        let generate = describeAndGenerate(englishDescription)

        XCTAssertTrue(app.staticTexts[busy].waitForExistence(timeout: 10), "The screen should stay busy while the app waits for the data")
        add(app.keptScreenshot(named: "Language data - waiting"))
        let alert = app.alerts["Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: 90), "The wait should end at its bound of 60 seconds, with a message")
        XCTAssertTrue(
            alert.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", endMessage)).firstMatch.exists,
            "The message should say that the device cannot get the data, and what to do instead"
        )
        add(app.keptScreenshot(named: "Language data - end message"))
        alert.buttons["OK"].tap()
        XCTAssertTrue(waitUntil(alert, exists: false), "OK should close the message")
        XCTAssertTrue(waitUntil(app.staticTexts[busy], exists: false), "The screen should no longer be busy")

        app.scrollTo(generate)
        XCTAssertTrue(generate.isEnabled, "Generate should be on again for the same description")
        generate.tap()
        XCTAssertTrue(app.staticTexts[busy].waitForExistence(timeout: 10), "Generate should start again")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(waitUntil(app.staticTexts[busy], exists: false), "Cancel should end the wait at once")
        XCTAssertFalse(alert.exists, "A cancelled wait shows no message")
    }

    /// The device has no English data until the app asks for it, and the system then gives it: the draft opens in the editor
    /// without another tap. The claim check fails, so the draft opens with the notice that says so and keeps the job.
    func testLanguageDataThatArrivesOpensTheDraftWithoutAnotherTap() throws {
        launch([
            "-PrestoCVUITestsScriptedDraft", "nurse", "-PrestoCVUITestsClaimCheck", "fail", "-LanguageDataOverride", "arrives",
        ])
        openTheAIScreenOnFirstRun()
        describeAndGenerate(englishDescription)

        let notice = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", reminder)).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The draft should open in the editor once the data has arrived")
        XCTAssertFalse(app.alerts.firstMatch.exists, "The arrived data should end in the draft, not in a message")
        add(app.keptScreenshot(named: "Language data - arrived, editor"))

        // The tab, wherever the device puts the tabs: a tab bar on an iPhone, the bar at the top of an iPad
        app.buttons["Experience"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "value == 'San Camillo'")).firstMatch
            .waitForExistence(timeout: 10), "The draft should hold the job of the description")
    }

    /// Opens the AI screen from the first-run screen, which offers the AI draft when the model can run.
    private func openTheAIScreenOnFirstRun() {
        let aiDraft = app.buttons["Draft My CV with AI"]
        XCTAssertTrue(aiDraft.waitForExistence(timeout: 20), "The first-run screen should offer the AI draft")
        aiDraft.tap()
    }

    /// Types `text` as the description, closes the keyboard and taps Generate, which it returns.
    @discardableResult
    private func describeAndGenerate(_ text: String) -> XCUIElement {
        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should have a description to type into")
        description.tap()
        description.typeText(text)
        let done = app.toolbars.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), XCUIApplication.noSoftwareKeyboard)
        done.tap()

        let generate = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Generate CV with AI")).firstMatch
        app.scrollTo(generate)
        generate.tap()
        return generate
    }

    private func waitUntil(_ element: XCUIElement, exists: Bool, timeout: TimeInterval = 10) -> Bool {
        let condition = expectation(for: NSPredicate(format: "exists == %@", NSNumber(value: exists)), evaluatedWith: element)
        return XCTWaiter().wait(for: [condition], timeout: timeout) == .completed
    }
}
