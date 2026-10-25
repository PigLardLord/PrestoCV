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
        assertTyped("Sapienza University of Rome", in: school, "the school")
    }

    /// Each row added to the Experience tab takes the focus in its first field and comes up above the keyboard that
    /// opens for it, and above the Done button over the keyboard; so does a field of the row tapped next. What is typed
    /// then goes into a field the person sees. A row added from an Add button low on the screen, where the keyboard comes
    /// up, used to stop with its first field at the keyboard's top edge, under the Done button.
    func testRowsAddedLowOnTheScreenComeUpAboveTheKeyboard() throws {
        let experienceTab = app.buttons["Experience"].firstMatch
        XCTAssertTrue(experienceTab.waitForExistence(timeout: 10), "The editor should show its tabs")
        experienceTab.tap()

        addRow("Add Experience", focusing: "Job Title", typing: "Ward Nurse")
        fill(app.textFields["Company"].firstMatch, named: "The company", with: "Policlinico Gemelli")
        addRow("Add Skill", focusing: "Skill", typing: "Triage")
        addRow("Add Skill", focusing: "Skill", typing: "Wound care")
        addRow("Add Education", focusing: "Degree", typing: "BSc Nursing")
        fill(app.textFields["School"].firstMatch, named: "The school", with: "Sapienza University of Rome")
    }

    /// Closes the keyboard, brings `button` as low on the screen as the form lets it, taps it, and types `text` into the
    /// field that then takes the focus by itself: the `label` of the new row.
    private func addRow(_ button: String, focusing label: String, typing text: String) {
        closeTheKeyboard()
        let add = app.buttons[button]
        bringLowOnTheScreen(add, named: button)
        // The new row is the last of its section
        let fields = app.textFields.matching(NSPredicate(format: "label == %@", label))
        let rowsBefore = fields.count
        add.tap()
        let newField = fields.element(boundBy: rowsBefore)
        XCTAssertTrue(newField.waitForExistence(timeout: 10), "\(button) should add a row with a \(label)")
        assertAboveTheKeyboard(newField, "The \(label) of the row added with \(button)")
        newField.typeText(text)
        assertTyped(text, in: newField, "the \(label) of the new row")
    }

    /// Closes the keyboard with its Done button, if it is up.
    private func closeTheKeyboard() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        app.toolbars.buttons["Done"].tap()
        XCTAssertTrue(waitUntil(keyboard, exists: false), "Done should close the keyboard")
    }

    /// Scrolls the form in short steps until `element` is in the lower part of the screen, where the keyboard comes up,
    /// or the form goes no further.
    private func bringLowOnTheScreen(_ element: XCUIElement, named name: String) {
        app.scrollTo(element)
        let low = app.frame.height * 0.72
        // A drag in the upper part of the screen, which carries the form down
        let grip = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        var steps = 0
        var previousY: CGFloat?
        while low - element.frame.midY > 8 && element.frame.midY != previousY && steps < 30 {
            previousY = element.frame.midY
            let distance = min(60, low - element.frame.midY)
            grip.press(forDuration: 0.05, thenDragTo: grip.withOffset(CGVector(dx: 0, dy: distance)), withVelocity: .slow, thenHoldForDuration: 0.2)
            steps += 1
        }
        XCTAssertTrue(element.isHittable, "\(name) should take a tap")
    }

    /// Scrolls to `field`, taps it and types `text` into it, once it is above the keyboard.
    private func fill(_ field: XCUIElement, named name: String, with text: String) {
        app.scrollTo(field)
        field.tap()
        assertAboveTheKeyboard(field, name)
        field.typeText(text)
        assertTyped(text, in: field, name)
    }

    /// Waits until everything typed has arrived in `field`. `typeText` returns while the app is still taking in the last
    /// keystrokes, so a read right after it can see the first letters only ("Tria" of "Triage").
    private func assertTyped(_ text: String, in field: XCUIElement, _ name: String) {
        let arrived = NSPredicate { _, _ in field.value as? String == text }
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: arrived, object: nil)], timeout: 10)
        XCTAssertEqual(field.value as? String, text, "Everything typed should arrive in \(name)")
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
