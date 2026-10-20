import XCTest

/// The keyboard of the editor can be closed from a text view, and the tab bar gives the form its space while it is up.
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
        XCTAssertTrue(summary.waitForKeyboardFocus(true), "Typing should give the text view the keyboard focus")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), XCUIApplication.noSoftwareKeyboard)

        let done = app.toolbars.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The keyboard should offer a Done button")
        done.tap()

        XCTAssertTrue(summary.waitForKeyboardFocus(false), "Done should take the keyboard focus from the text view")
        XCTAssertTrue(waitUntil(app.keyboards.firstMatch, exists: false), "Done should close the keyboard")
        XCTAssertEqual(summary.value as? String, "Ten years of emergency care.", "Closing the keyboard keeps what was typed")
    }

    func testTheTabBarMakesWayWhileTypingAndTheExportControlStaysInTheNavigationBar() throws {
        let export = app.barButton("Preview & export")
        let experienceTab = app.buttons["Experience"].firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 10), "The bar should offer to preview and export")
        XCTAssertTrue(experienceTab.exists, "The editor should show its tabs")

        app.textFields["Full Name"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), XCUIApplication.noSoftwareKeyboard)
        XCTAssertTrue(waitUntil(experienceTab, exists: false), "The tab bar should make way for the keyboard")
        XCTAssertTrue(export.exists, "The export control should stay in the bar while typing")

        app.toolbars.buttons["Done"].tap()
        XCTAssertTrue(waitUntil(experienceTab, exists: true), "The tab bar should come back with the keyboard gone")
        XCTAssertTrue(export.exists, "The export control should still be in the bar")
    }

    func testReturnEndsTheEntryOfAFieldInsteadOfAddingALine() throws {
        let name = app.textFields["Full Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The Basics tab should have a full name to type into")
        name.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), XCUIApplication.noSoftwareKeyboard)
        name.typeText("Maria Rossi\n")

        XCTAssertTrue(name.waitForKeyboardFocus(false), "Return should end the entry of the name")
        XCTAssertTrue(waitUntil(app.keyboards.firstMatch, exists: false), "Return should close the keyboard")
        XCTAssertEqual(name.value as? String, "Maria Rossi", "Return should not add a line to the name")
    }

    /// A row added at the end of the form, and each field of it, comes up above the keyboard and above the Done button
    /// over it, so that what is typed goes into a field the person sees. Without the bar below the form, a new row used to
    /// stop under the Done button and a field below it under the keyboard.
    func testTheFieldsOfRowsAddedLowInTheFormStayAboveTheKeyboard() throws {
        let experienceTab = app.buttons["Experience"].firstMatch
        XCTAssertTrue(experienceTab.waitForExistence(timeout: 10), "The editor should show its tabs")
        experienceTab.tap()

        let addSkill = app.buttons["Add Skill"]
        app.scrollTo(addSkill)
        addSkill.tap()
        let skill = app.textFields["Skill"].firstMatch
        XCTAssertTrue(skill.waitForExistence(timeout: 10), "Add Skill should add a row")
        assertAboveTheKeyboard(skill, "The new skill")
        skill.typeText("Triage")

        app.toolbars.buttons["Done"].tap()
        let addEducation = app.buttons["Add Education"]
        app.scrollTo(addEducation)
        addEducation.tap()
        let degree = app.textFields["Degree"].firstMatch
        XCTAssertTrue(degree.waitForExistence(timeout: 10), "Add Education should add a row")
        assertAboveTheKeyboard(degree, "The degree of the new education")
        degree.typeText("BSc Nursing")

        let school = app.textFields["School"].firstMatch
        school.tap()
        assertAboveTheKeyboard(school, "The school of the new education")
        school.typeText("Sapienza University of Rome")
        XCTAssertEqual(school.value as? String, "Sapienza University of Rome", "Everything typed should arrive in the school")
    }

    /// Waits until `field` has the keyboard focus and is above the keyboard and above the Done button over it.
    private func assertAboveTheKeyboard(_ field: XCUIElement, _ name: String) {
        XCTAssertTrue(field.waitForKeyboardFocus(true), "\(name) should get the keyboard focus")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10), XCUIApplication.noSoftwareKeyboard)
        let done = app.toolbars.buttons["Done"]
        let bar = app.navigationBars.firstMatch
        let clear = NSPredicate { _, _ in
            let top = done.exists ? min(keyboard.frame.minY, done.frame.minY) : keyboard.frame.minY
            return field.exists && field.frame.maxY <= top && field.frame.minY >= bar.frame.maxY
        }
        let waited = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: clear, object: nil)], timeout: 5)
        XCTAssertEqual(waited, .completed, "\(name) should be in view above the keyboard and its Done button")
    }

    private func waitUntil(_ element: XCUIElement, exists: Bool, timeout: TimeInterval = 10) -> Bool {
        let condition = expectation(for: NSPredicate(format: "exists == %@", NSNumber(value: exists)), evaluatedWith: element)
        return XCTWaiter().wait(for: [condition], timeout: timeout) == .completed
    }
}
