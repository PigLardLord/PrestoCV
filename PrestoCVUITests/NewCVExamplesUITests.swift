import XCTest

/// The "New CV" screen offers the examples, as the first run does.
final class NewCVExamplesUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage", "-PrestoCVUITestsKeepSavedConfirmation"]
        app.launch()
    }

    func testAnExampleChosenOnTheNewCVScreenOpensInTheEditor() throws {
        app.openTheNewCVScreen()

        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Example CV'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The New CV screen should offer the examples")
        app.scrollTo(card)
        card.tap()

        let example = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Senior Software Engineer")).firstMatch
        XCTAssertTrue(example.waitForExistence(timeout: 10), "The examples should be listed")
        example.tap()

        let name = app.textFields["Full Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The chosen example should open in the editor")
    }
}
