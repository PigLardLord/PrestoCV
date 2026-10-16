import XCTest

/// VoiceOver names a field by its label, not by its placeholder: a filled field without a label is announced by its
/// text alone.
final class EditorFieldNamesUITests: XCTestCase {

    private var app: XCUIApplication!

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

    func testTheCVNameFieldHasALabel() throws {
        let name = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "CV Name")).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The editor should have a CV name to type into")
        name.tap()
        name.typeText("Ward Nurse CV\n")
        XCTAssertEqual(name.label, "CV Name", "The CV name field should be announced by its name")
    }
}
