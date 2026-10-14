import XCTest

/// The description of an education is always there to type into, as it is for an experience.
final class EditorDescriptionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage"]
        app.launch()
    }

    func testEducationDescriptionCanBeTypedClearedAndTypedAgain() throws {
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
        app.buttons["Experience"].firstMatch.tap()

        let addEducation = app.buttons["Add Education"]
        var scrolls = 0
        while !addEducation.isHittable && scrolls < 8 {
            app.swipeUp()
            scrolls += 1
        }
        addEducation.tap()

        let description = app.textViews["Description"]
        XCTAssertTrue(description.waitForExistence(timeout: 10), "A new education should have a description to type into")
        description.tap()
        description.typeText("Thesis on triage")
        XCTAssertEqual(description.value as? String, "Thesis on triage")

        description.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Thesis on triage".count))
        XCTAssertTrue(description.exists, "Clearing the description must not remove the box")
        XCTAssertEqual(description.value as? String, "", "The description should be empty after clearing it")

        description.typeText("Second thought")
        XCTAssertEqual(description.value as? String, "Second thought", "The description can be typed again after it was cleared")
    }
}
