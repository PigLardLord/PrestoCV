import XCTest

/// The AI screen can be used with VoiceOver, and with the keyboard up.
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
        openTheAIScreen()

        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "VoiceOver should name the description field")
    }

    /// A text view has no Return key that closes the keyboard, and the keyboard covered Generate.
    func testGenerateCanBeReachedAfterTypingTheDescription() throws {
        openTheAIScreen()
        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should have a description to type into")
        description.tap()
        description.typeText("I have been a nurse at San Camillo hospital in Rome since 2015.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), "Typing should show the keyboard")

        let done = app.toolbars.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The keyboard should offer a Done button")
        done.tap()
        XCTAssertTrue(waitUntil(app.keyboards.firstMatch, exists: false), "Done should close the keyboard")

        let generate = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Generate CV with AI")).firstMatch
        app.scrollTo(generate)
        XCTAssertTrue(generate.isHittable, "Generate should be reachable once the keyboard is closed")
        XCTAssertTrue(generate.isEnabled, "Generate should be on for the description just typed")
    }

    /// Going back from the AI screen used to throw the description away.
    func testTheDescriptionIsStillThereAfterGoingBack() throws {
        openTheAIScreen()
        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should have a description to type into")
        let typed = "I have been a nurse at San Camillo hospital in Rome since 2015."
        description.tap()
        description.typeText(typed)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "AI CV Generation")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Back should return to the New CV screen")
        card.tap()

        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should open again")
        XCTAssertEqual(description.value as? String, typed, "The description should be as it was left")
    }

    private func waitUntil(_ element: XCUIElement, exists: Bool, timeout: TimeInterval = 10) -> Bool {
        let condition = expectation(for: NSPredicate(format: "exists == %@", NSNumber(value: exists)), evaluatedWith: element)
        return XCTWaiter().wait(for: [condition], timeout: timeout) == .completed
    }
}
