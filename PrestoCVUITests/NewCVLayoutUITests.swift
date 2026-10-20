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

    /// On an iPad the card used to be a square of a thousand points.
    func testTheEmptyCVCardKeepsToTheReadableWidthAndIsNotASquare() throws {
        app.openTheNewCVScreen()

        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Empty CV'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The New CV screen should offer an empty CV")
        XCTAssertLessThanOrEqual(card.frame.width, 672, "The card should not be wider than the readable width")
        XCTAssertLessThan(card.frame.height, card.frame.width, "The card should not be a square")
    }
}
