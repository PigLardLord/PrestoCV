import XCTest

/// The keyboard of the editor can be closed from a text view, and gives the form its space while it is up.
final class EditorKeyboardUITests: XCTestCase {

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

    /// The professional summary is the one text view of the Basics tab; a text view has no Return key that closes the keyboard.
    func testTheDoneButtonClosesTheKeyboardOpenedByATextView() throws {
        let summary = app.textViews.firstMatch
        var scrolls = 0
        while !summary.isHittable && scrolls < 8 {
            app.swipeUp()
            scrolls += 1
        }
        summary.tap()
        summary.typeText("Ten years of emergency care.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), "Typing should show the keyboard")

        let done = app.toolbars.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The keyboard should offer a Done button")
        done.tap()

        XCTAssertTrue(waitUntil(app.keyboards.firstMatch, exists: false), "Done should close the keyboard")
        XCTAssertEqual(summary.value as? String, "Ten years of emergency care.", "Closing the keyboard keeps what was typed")
    }

    func testTheTabBarAndTheExportButtonMakeWayWhileTypingAndComeBack() throws {
        let export = app.buttons["Preview & export"]
        let experienceTab = app.buttons["Experience"].firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 10), "The editor should offer to preview and export")
        XCTAssertTrue(experienceTab.exists, "The editor should show its tabs")

        app.textFields["Full Name"].tap()
        XCTAssertTrue(waitUntil(export, exists: false), "The export button should make way for the keyboard")
        XCTAssertTrue(waitUntil(experienceTab, exists: false), "The tab bar should make way for the keyboard")

        app.toolbars.buttons["Done"].tap()
        XCTAssertTrue(waitUntil(export, exists: true), "The export button should come back with the keyboard gone")
        XCTAssertTrue(waitUntil(experienceTab, exists: true), "The tab bar should come back with the keyboard gone")
    }

    func testReturnEndsTheEntryOfAFieldInsteadOfAddingALine() throws {
        let name = app.textFields["Full Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The Basics tab should have a full name to type into")
        name.tap()
        name.typeText("Maria Rossi\n")

        XCTAssertTrue(waitUntil(app.keyboards.firstMatch, exists: false), "Return should close the keyboard")
        XCTAssertEqual(name.value as? String, "Maria Rossi", "Return should not add a line to the name")
    }

    private func waitUntil(_ element: XCUIElement, exists: Bool, timeout: TimeInterval = 10) -> Bool {
        let condition = expectation(for: NSPredicate(format: "exists == %@", NSNumber(value: exists)), evaluatedWith: element)
        return XCTWaiter().wait(for: [condition], timeout: timeout) == .completed
    }
}
