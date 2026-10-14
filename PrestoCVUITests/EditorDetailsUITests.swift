import XCTest

/// The rows of the Details tab.
final class EditorDetailsUITests: XCTestCase {

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
        app.buttons["Details"].firstMatch.tap()
    }

    /// The row used to say "Level" and then "Language Level" again, on the picker.
    func testTheLanguageRowNamesTheLevelOnce() throws {
        let addLanguage = app.buttons["Add Language"]
        var scrolls = 0
        while !addLanguage.isHittable && scrolls < 8 {
            app.swipeUp()
            scrolls += 1
        }
        addLanguage.tap()

        let picker = app.buttons["Level, B1 - Intermediate"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "A new language should have a level to pick, named Level")
        let labels = NSPredicate(format: "label == 'Level'")
        XCTAssertEqual(app.staticTexts.matching(labels).count, 1, "The row should name the level once")
        let doubled = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Language Level'"))
        XCTAssertEqual(doubled.count, 0, "The row should not call the level Language Level as well")
    }
}
