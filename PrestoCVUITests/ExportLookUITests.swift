import XCTest

/// Each CV keeps the design, font and colors chosen for it: the export sheet of a CV starts from its own choice,
/// whatever another CV was exported with since.
final class ExportLookUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 420
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage"]
        app.launch()
    }

    func testEachCVReopensWithTheLookChosenForIt() throws {
        // CV A: Serif and Creative
        let first = "Maria Rossi"
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
        typeAName(first)
        openTheExportSheet()
        choose(tab: "Fonts", item: "Serif")
        choose(tab: "Colors", item: "Creative")
        XCTAssertTrue(waitUntilTheSheetHasItsPDF(), "The PDF should be made with the choice")
        closeTheExportSheet()
        leaveTheEditor()

        // CV B is new, and starts with the defaults: A's choice is not on it
        let second = "Anna Bianchi"
        let add = app.barButton("Add")
        XCTAssertTrue(add.waitForExistence(timeout: 10), "The list should offer to add a CV")
        add.tap()
        let blank = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Empty CV'")).firstMatch
        XCTAssertTrue(blank.waitForExistence(timeout: 10), "The New CV screen should offer a blank CV")
        app.scrollTo(blank)
        blank.tap()
        typeAName(second)
        openTheExportSheet()
        assertSelected(tab: "Fonts", item: "Classic", message: "A new CV should start with the classic font")
        assertNotSelected(tab: "Fonts", item: "Serif", message: "A new CV should not take the font of another CV")
        assertNotSelected(tab: "Colors", item: "Creative", message: "A new CV should not take the colors of another CV")
        closeTheExportSheet()
        leaveTheEditor()

        // CV A again: its choice is selected
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", first)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The list should show the first CV")
        row.tap()
        XCTAssertTrue(app.textFields["Full Name"].waitForExistence(timeout: 10), "The first CV should open in the editor")
        openTheExportSheet()
        assertSelected(tab: "Fonts", item: "Serif", message: "The first CV should reopen with the font chosen for it")
        assertSelected(tab: "Colors", item: "Creative", message: "The first CV should reopen with the colors chosen for it")
        closeTheExportSheet()
    }

    // MARK: - Helpers

    /// Types the name of the person into the editor that is open, and waits for the CV to be stored.
    private func typeAName(_ text: String) {
        let name = app.textFields["Full Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The editor should have a full name to type into")
        name.tap()
        name.typeText("\(text)\n")
        XCTAssertTrue(app.savedOnThisDevice.waitForExistence(timeout: 10), "The editor should save by itself")
    }

    private func openTheExportSheet() {
        let export = app.barButton("Preview & export")
        XCTAssertTrue(export.waitForExistence(timeout: 10), "The editor should offer to preview and export")
        export.tap()
        XCTAssertTrue(app.buttons["Send or save PDF"].waitForExistence(timeout: 30), "The export sheet should open")
    }

    private func closeTheExportSheet() {
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.backButton.waitForExistence(timeout: 10), "The sheet should close")
    }

    private func leaveTheEditor() {
        app.backButton.tap()
    }

    /// The item of a tab of the sheet; on iPad the sheet has more than one element named like a tab
    private func item(_ name: String) -> XCUIElement {
        app.buttons[name].firstMatch
    }

    private func choose(tab: String, item name: String) {
        let tabButton = app.buttons[tab].firstMatch
        XCTAssertTrue(tabButton.waitForExistence(timeout: 20), "The export sheet should offer \(tab)")
        tabButton.tap()
        let option = item(name)
        XCTAssertTrue(option.waitForExistence(timeout: 10), "The \(tab) should offer \(name)")
        scrollToShow(option, named: name)
        option.tap()
    }

    /// The items of a tab sit in a row that scrolls sideways: the fourth color is beyond the edge of an iPhone. An item
    /// beyond the edge has a frame but no point to tap, so its place is read from the frame.
    private func scrollToShow(_ option: XCUIElement, named name: String) {
        let row = app.scrollViews.containing(NSPredicate(format: "label == %@", name)).firstMatch
        let visibleEdge = app.frame.maxX - 24
        var swipes = 0
        while option.frame.midX > visibleEdge && swipes < 5 {
            row.swipeLeft()
            swipes += 1
        }
        XCTAssertLessThanOrEqual(option.frame.midX, visibleEdge, "\(name) should be in view after scrolling the row")
    }

    private func assertSelected(tab: String, item name: String, message: String) {
        XCTAssertTrue(isSelected(tab: tab, item: name, selected: true), message)
    }

    private func assertNotSelected(tab: String, item name: String, message: String) {
        XCTAssertTrue(isSelected(tab: tab, item: name, selected: false), message)
    }

    /// Opens the tab and waits for the item to be selected, or not: the sheet selects its CV's choice once the designs
    /// are loaded.
    private func isSelected(tab: String, item name: String, selected: Bool) -> Bool {
        let tabButton = app.buttons[tab].firstMatch
        guard tabButton.waitForExistence(timeout: 20) else { return false }
        tabButton.tap()
        let option = item(name)
        guard option.waitForExistence(timeout: 10) else { return false }
        let condition = expectation(for: NSPredicate(format: "isSelected == %@", NSNumber(value: selected)), evaluatedWith: option)
        return XCTWaiter().wait(for: [condition], timeout: 15) == .completed
    }

    /// The PDF is made once the preview has settled: its button is enabled then.
    private func waitUntilTheSheetHasItsPDF() -> Bool {
        let send = app.buttons["Send or save PDF"]
        let condition = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: send)
        return XCTWaiter().wait(for: [condition], timeout: 60) == .completed
    }
}
