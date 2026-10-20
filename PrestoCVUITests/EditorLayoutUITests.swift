import XCTest

/// The editor leaves room for what is typed, at the normal text size and at the largest one.
final class EditorLayoutUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(contentSize: String? = nil) {
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

    /// An address such as maria.rossi@example-hospital.org needs about this much room at the normal text size.
    func testEmailAndPhoneEachGetRoomForALongEntry() throws {
        launch()
        let email = app.textFields["Email"]
        let phone = app.textFields["Phone"]
        var scrolls = 0
        while !(email.isHittable && phone.isHittable) && scrolls < 8 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertGreaterThanOrEqual(email.frame.width, 250, "The email field should not be squeezed into half a row")
        XCTAssertGreaterThanOrEqual(phone.frame.width, 250, "The phone field should not be squeezed into half a row")
    }

    /// At the largest text size the export button used to take a fifth of the screen.
    func testTheExportButtonDoesNotTakeTheScreenAtTheLargestTextSize() throws {
        launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        let export = app.buttons["Preview & export"]
        XCTAssertTrue(export.waitForExistence(timeout: 10), "The editor should offer to preview and export")
        XCTAssertLessThanOrEqual(export.frame.height, app.frame.height * 0.12, "The export button should keep a readable, bounded size")
    }

    /// In landscape the tab bar and the export button below the form used to leave it about one row: on an iPhone
    /// the export button goes up into the navigation bar.
    func testTheExportButtonMovesIntoTheNavigationBarInLandscape() throws {
        launch()
        let export = app.buttons["Preview & export"]
        XCTAssertTrue(export.waitForExistence(timeout: 10), "The editor should offer to preview and export")
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }

        XCUIDevice.shared.orientation = .landscapeLeft
        let barExport = app.navigationBars.buttons["Preview & export"]
        XCTAssertTrue(barExport.waitForExistence(timeout: 10), "In landscape the navigation bar should offer to export")
        let exportButtons = app.buttons.matching(NSPredicate(format: "label == 'Preview & export'"))
        XCTAssertEqual(exportButtons.count, 1, "The export button should not stay below the form as well")

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(waitUntil(barExport, exists: false), "In portrait the export button should leave the navigation bar")
        XCTAssertTrue(export.waitForExistence(timeout: 10), "In portrait the export button should be back below the form")
    }

    /// At the largest text size an address needs several lines, and a field that keeps to one would cut it off.
    func testAFieldGrowsToShowALongEntryAtTheLargestTextSize() throws {
        launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        let email = app.textFields["Email"]
        app.scrollTo(email)
        let heightBefore = email.frame.height
        email.tap()
        email.typeText("ada.lovelace@analytical-engine.example")

        let grown = XCTNSPredicateExpectation(
            predicate: NSPredicate { element, _ in ((element as? XCUIElement)?.frame.height ?? 0) > heightBefore },
            object: email
        )
        XCTWaiter().wait(for: [grown], timeout: 60)
        XCTAssertGreaterThan(email.frame.height, heightBefore, "The email field should grow to show the whole address")
    }

    /// The row of the document language used to run half a screen below its text, at the normal text size, and to
    /// push the personal details under the tab bar.
    func testTheDocumentLanguageRowTakesOnlyTheRoomOfItsText() throws {
        launch()
        assertTheDocumentLanguageIsFollowedByThePersonalDetails(within: 60)
    }

    /// At the large sizes the label may shrink to keep its words whole, and the row still ends below its text.
    func testTheDocumentLanguageRowTakesOnlyTheRoomOfItsTextAtALargeTextSize() throws {
        launch(contentSize: "UICTContentSizeCategoryAccessibilityXL")
        assertTheDocumentLanguageIsFollowedByThePersonalDetails(within: 130)
    }

    /// Besides the menu, the row of the document language holds no more than its label and its margins, and the
    /// heading of the personal details follows it. The label is not in the tree, because the menu says it to
    /// VoiceOver and the row is a single element: what the row holds is measured around the menu as it is drawn.
    private func assertTheDocumentLanguageIsFollowedByThePersonalDetails(within points: CGFloat) {
        let row = app.buttons["Document language"]
        let personal = app.staticTexts["Personal Information"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The editor should ask for the document language")
        XCTAssertTrue(personal.waitForExistence(timeout: 10), "The personal details should follow the CV details")
        let menu = row.buttons.firstMatch
        XCTAssertTrue(menu.exists, "The document language row should show its menu")
        let besidesTheMenu = row.frame.height - menu.frame.height
        XCTAssertLessThanOrEqual(besidesTheMenu, points, "The document language row should take only the room of its text")
        let gap = personal.frame.minY - row.frame.maxY
        XCTAssertLessThanOrEqual(gap, points, "The personal details should follow the document language row")
    }

    private func waitUntil(_ element: XCUIElement, exists: Bool, timeout: TimeInterval = 10) -> Bool {
        let condition = expectation(for: NSPredicate(format: "exists == %@", NSNumber(value: exists)), evaluatedWith: element)
        return XCTWaiter().wait(for: [condition], timeout: timeout) == .completed
    }
}
