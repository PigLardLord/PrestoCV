import XCTest

/// The phone field accepted "abc" without a word. It still accepts it, and says beside the field that it is not a
/// phone number.
final class EditorPhoneHintUITests: XCTestCase {

    private var app: XCUIApplication!
    private let hint = "This doesn’t look like a phone number: it has no digits."

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage"]
        app.launch()
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
    }

    func testAPhoneWithoutDigitsGetsAHintAndOneWithDigitsDoesNot() throws {
        let phone = app.textFields["Phone"]
        app.scrollTo(phone)
        XCTAssertTrue(phone.waitForExistence(timeout: 10), "The editor should have a phone to type into")
        XCTAssertFalse(app.staticTexts[hint].exists, "An empty phone should get no hint")

        phone.tap()
        phone.typeText("abc")
        XCTAssertTrue(app.staticTexts[hint].waitForExistence(timeout: 5), "A phone without digits should get the hint")

        phone.typeText("1")
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.staticTexts[hint])
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "A phone with a digit should lose the hint")
    }
}
