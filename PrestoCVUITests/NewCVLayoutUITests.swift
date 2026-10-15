import XCTest

/// The "New CV" screen keeps to a readable width, as the list and the editor do.
final class NewCVLayoutUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage"]
        app.launch()
    }

    /// Saves a first CV and opens the "New CV" screen from the "+" of the list.
    private func openTheNewCVScreen() {
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
        let name = app.textFields["Full Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The editor should have a full name to type into")
        name.tap()
        name.typeText("Maria Rossi\n")
        app.buttons["Save"].tap()
        let done = app.alerts.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "Saving should confirm")
        done.tap()
        let add = app.navigationBars.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "The list should offer to add a CV")
        add.tap()
    }

    /// On an iPad the card used to be a square of a thousand points.
    func testTheEmptyCVCardKeepsToTheReadableWidthAndIsNotASquare() throws {
        openTheNewCVScreen()

        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Empty CV'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The New CV screen should offer an empty CV")
        XCTAssertLessThanOrEqual(card.frame.width, 672, "The card should not be wider than the readable width")
        XCTAssertLessThan(card.frame.height, card.frame.width, "The card should not be a square")
    }
}
