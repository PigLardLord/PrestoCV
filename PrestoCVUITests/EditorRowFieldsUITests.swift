import XCTest

/// The single-value fields of the rows grow with their text, and Return ends the entry instead of adding a line.
final class EditorRowFieldsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
    }

    private func launchAndCreateACV(contentSize: String? = nil) {
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage"]
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
    }

    private func launchAndAddAnExperience(contentSize: String? = nil) {
        launchAndCreateACV(contentSize: contentSize)
        app.buttons["Experience"].firstMatch.tap()

        let addExperience = app.buttons["Add Experience"]
        app.scrollTo(addExperience)
        addExperience.tap()
    }

    /// Closes the keyboard that the first field of a new row opens, with the Done button above it.
    private func closeTheKeyboard() {
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 10), "The new row should open the keyboard. " + XCUIApplication.noSoftwareKeyboard)
        app.toolbars.buttons["Done"].tap()
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: keyboard)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 10), .completed, "Done should close the keyboard")
    }

    /// A new row used to wait for a tap on its first field before anything could be typed into it.
    func testANewRowTakesTheKeyboardFocusOnItsFirstField() throws {
        launchAndAddAnExperience()
        let title = app.textFields["Job Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "A new experience should have a job title to type into")
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: title)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 10), .completed, "The job title of a new experience should take the focus")

        app.typeText("Ward Nurse")
        XCTAssertEqual(title.value as? String, "Ward Nurse", "What is typed right after adding the row should go into it")
    }

    func testReturnEndsTheEntryOfARowFieldInsteadOfAddingALine() throws {
        launchAndAddAnExperience()
        let title = app.textFields["Job Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "A new experience should have a job title to type into")
        title.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), XCUIApplication.noSoftwareKeyboard)
        title.typeText("Ward Nurse\n")

        XCTAssertTrue(title.waitForKeyboardFocus(false), "Return should end the entry of the job title")
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter().wait(for: [closed], timeout: 10), .completed, "Return should close the keyboard")
        XCTAssertEqual(title.value as? String, "Ward Nurse", "Return should not add a line to the job title")
    }

    /// Side by side, a long place and a long period would cut each other off at the largest text sizes.
    func testLocationAndPeriodAreStackedAtTheLargestTextSize() throws {
        launchAndAddAnExperience(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        // The form scrolls to the new row while its keyboard comes up: the places are read with the form still
        closeTheKeyboard()
        let location = app.textFields["Location"]
        let period = app.textFields["Period"]
        app.scrollTo(location)
        XCTAssertTrue(location.exists, "A new experience should have a location to type into")
        XCTAssertTrue(period.exists, "A new experience should have a period to type into")
        XCTAssertGreaterThanOrEqual(period.frame.minY, location.frame.maxY, "The period should sit below the location, not beside it")
    }

    /// VoiceOver reads the label of a field, not its placeholder: a field without a label is announced as "text field".
    func testTheCertificationYearFieldHasALabel() throws {
        launchAndCreateACV()
        app.buttons["Details"].firstMatch.tap()

        let addCertification = app.buttons["Add Certification"]
        app.scrollTo(addCertification)
        addCertification.tap()
        let year = app.textFields["Year"]
        XCTAssertTrue(year.waitForExistence(timeout: 10), "A new certification should have a year to type into")
        XCTAssertEqual(year.label, "Year", "The year field should be announced by its name")
    }

    /// A year that is not set used to show "0", and typing a year after it gave "02020".
    func testANewCertificationHasAnEmptyYearThatTakesTheYearAsTyped() throws {
        launchAndCreateACV()
        app.buttons["Details"].firstMatch.tap()

        let addCertification = app.buttons["Add Certification"]
        app.scrollTo(addCertification)
        addCertification.tap()
        let year = app.textFields["Year"]
        XCTAssertTrue(year.waitForExistence(timeout: 10), "A new certification should have a year to type into")
        XCTAssertEqual(year.value as? String, "Year", "An empty year should show its placeholder, not 0")

        year.tap()
        year.typeText("2020")
        XCTAssertEqual(year.value as? String, "2020", "The year should read as typed")
    }
}
