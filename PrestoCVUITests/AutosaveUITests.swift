import XCTest

/// The editor saves by itself: nothing typed is lost when the person leaves, when the app goes to the background and
/// iOS ends it, or when a design is chosen, and nothing asks the person to save or to discard.
final class AutosaveUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 300
        // In landscape the first run has room only for its first choice, the AI draft where the device can run it:
        // these steps start a blank CV
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        // A folder of its own that the launches of this test share, as an installation keeps its data between them
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsStorage", UUID().uuidString]
    }

    /// Opens a blank CV from the first run and types a name into it.
    private func typeANameIntoANewCV(_ text: String = "Marta Rinaldi") {
        app.launch()
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
        let name = app.textFields["Full Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The editor should have a full name to type into")
        name.tap()
        XCTAssertTrue(name.waitForKeyboardFocus(true), "Tapping the full name should give it the keyboard focus")
        name.typeText(text)
    }

    /// The row of the list that shows the CV of `person`: a CV without a name of its own is listed under its person.
    private func rows(of person: String) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", person))
    }

    func testWhatIsTypedSurvivesTheAppBeingEndedInTheBackground() throws {
        typeANameIntoANewCV()

        // The home screen comes to the front, as after a press of Home, on every device, the iPhone Duo included
        XCUIApplication(bundleIdentifier: "com.apple.springboard").activate()
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10), "The app should go to the background")
        app.terminate()
        app.launch()

        XCTAssertTrue(rows(of: "Marta Rinaldi").firstMatch.waitForExistence(timeout: 20), "The list should show the CV")
        XCTAssertEqual(rows(of: "Marta Rinaldi").count, 1, "The CV should be stored once")
        XCTAssertEqual(app.alerts.count, 0, "Nothing should ask the person about their changes")
        rows(of: "Marta Rinaldi").firstMatch.tap()
        let name = app.textFields["Full Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The CV should open in the editor")
        XCTAssertEqual(name.value as? String, "Marta Rinaldi", "The editor should show what was typed")
    }

    func testBackLeavesWithoutAQuestionAndTheCVIsInTheList() throws {
        typeANameIntoANewCV()
        XCTAssertTrue(app.savedOnThisDevice.waitForExistence(timeout: 10), "The editor should say that it saved the CV")

        XCTAssertTrue(app.backButton.waitForExistence(timeout: 10), "The editor should go back with the Back button")
        XCTAssertFalse(app.barButton("Save").exists, "There should be no Save button")
        XCTAssertFalse(app.barButton("Cancel").exists, "There should be no Cancel button")
        app.backButton.tap()

        XCTAssertTrue(rows(of: "Marta Rinaldi").firstMatch.waitForExistence(timeout: 10), "The list should show the CV")
        XCTAssertEqual(app.alerts.count, 0, "Leaving should not ask anything")
    }

    func testABlankCVLeftUntouchedLeavesNothing() throws {
        app.launch()
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
        XCTAssertTrue(app.backButton.waitForExistence(timeout: 10), "The editor should go back with the Back button")
        XCTAssertFalse(app.savedOnThisDevice.exists, "Nothing is stored, so nothing is said to be")

        app.backButton.tap()

        XCTAssertTrue(start.waitForExistence(timeout: 10), "With nothing stored, the first-run screen should show again")
    }

    /// Choosing a design used to leave the editor with unsaved changes, and Back asked to discard them.
    func testChoosingADesignAndGoingBackAsksNothing() throws {
        typeANameIntoANewCV()
        app.textFields["Full Name"].typeText("\n")
        let export = app.barButton("Preview & export")
        XCTAssertTrue(export.waitForExistence(timeout: 10), "The editor should offer to preview and export")
        export.tap()
        // On iPad the sheet has more than one element named Fonts
        let fonts = app.buttons["Fonts"].firstMatch
        XCTAssertTrue(fonts.waitForExistence(timeout: 20), "The export sheet should offer the fonts")
        fonts.tap()
        let serif = app.buttons["Serif"].firstMatch
        XCTAssertTrue(serif.waitForExistence(timeout: 10), "The export sheet should offer the Serif font")
        serif.tap()
        app.buttons["Cancel"].firstMatch.tap()

        XCTAssertTrue(app.backButton.waitForExistence(timeout: 10), "The sheet should close")
        app.backButton.tap()

        XCTAssertTrue(rows(of: "Marta Rinaldi").firstMatch.waitForExistence(timeout: 10), "The list should show the CV")
        XCTAssertEqual(app.alerts.count, 0, "Leaving should not ask anything")
    }

    /// On the open iPhone Duo the bar scrolled away with the form: the bar stays, whatever the form shows.
    func testTheBarStaysWhileTheFormScrolls() throws {
        typeANameIntoANewCV()
        app.textFields["Full Name"].typeText("\n")
        let export = app.barButton("Preview & export")
        XCTAssertTrue(export.waitForExistence(timeout: 10), "The editor should offer to preview and export")

        app.swipeUp()
        app.swipeUp()

        XCTAssertTrue(export.isHittable, "The export control should stay in reach")
        XCTAssertTrue(app.backButton.isHittable, "The Back button should stay in reach")
    }
}
