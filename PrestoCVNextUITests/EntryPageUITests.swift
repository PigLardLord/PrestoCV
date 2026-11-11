import XCTest

/// The page of a row on a narrow screen. A new job opens on a page titled for it, with the cursor in its first field
/// and the save status at the top; back shows it in the form as a line that names it, and a new job goes first. With
/// two or more rows the section says how to move one. The page deletes its row once the person confirms, and closes.
/// A language's line shows its level, and its context menu names it. The menu of the back button goes from a page
/// straight to the list. On a wide screen the rows stay in the form, so these tests are skipped there.
final class EntryPageUITests: XCTestCase {

    private let identity = "3F6B9D2A-7C41-4E8B-A5D0-6E2C8B1F9A47"
    private let title = "Crane Operator"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Launching

    /// A store folder of its own with one CV whose sections are empty, in English, opened. Skips the test unless the
    /// rows open on a page here.
    @MainActor
    private func launchAndOpen() throws -> XCUIApplication {
        let app = XCUIApplication()
        // The store reads a CV from the file named by its identity; the fixture takes a JSON map from file name to
        // content, in base 64
        let cv = """
        {"schemaVersion":1,"id":"\(identity)","revision":1,
         "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"\(title)",
         "personal":{"fullName":"Tobias Renn","professionalTitle":"","location":"","summary":""},
         "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],"interests":[]}
        """
        let seed = try JSONEncoder().encode(["\(identity).cv.json": cv]).base64EncodedString()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", seed,
        ]
        app.launch()
        try XCTSkipUnless(app.opensOnAPage("experiences"), "A wide screen keeps the rows in the form")
        let row = app.descendants(matching: .any).matching(identifier: "shell.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", title + ", ")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The list shows \(title)")
        row.tap()
        XCTAssertTrue(app.textFields["editor.field.title"].waitForExistence(timeout: 30), "The form of \(title) opens")
        return app
    }

    // MARK: Rows

    /// Adds a row to the section from the CV's form and waits for its page and the keyboard of its first field.
    @MainActor
    private func addRow(to section: String, in app: XCUIApplication) {
        let add = app.buttons["editor.add.\(section)"]
        app.scrollForm(until: add, named: "The add button of \(section)")
        add.tap()
        XCTAssertTrue(app.entryPage.waitForExistence(timeout: 30), "A new row of \(section) opens its page")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 30), "A new row of \(section) takes the keyboard")
    }

    /// Adds a row, types in its first field, puts the keyboard away, and goes back to the CV's form.
    @MainActor
    private func addRow(to section: String, typing text: String, in app: XCUIApplication) {
        addRow(to: section, in: app)
        app.typeText(text)
        putKeyboardAway(in: app)
        app.leaveEntryPage()
    }

    /// The lines of the section's rows in the form, from the top.
    @MainActor
    private func rows(of section: String, in app: XCUIApplication) -> [XCUIElement] {
        app.buttons.matching(identifier: "editor.entry.\(section)").allElementsBoundByIndex
            .sorted { $0.frame.minY < $1.frame.minY }
    }

    @MainActor
    private func putKeyboardAway(in app: XCUIApplication) {
        app.buttons["keyboard.done"].tap()
        XCTAssertTrue(waitUntilGone(app.keyboards.firstMatch), "Done puts the keyboard away")
    }

    /// The Delete of the dialog: the page's own Delete button, or the menu's, may stay in the tree.
    @MainActor
    private func confirmDelete(in app: XCUIApplication) {
        let delete = app.buttons.matching(NSPredicate(format: "label == %@", "Delete")).allElementsBoundByIndex
            .last { $0.canBeTapped(in: app) }
        XCTAssertNotNil(delete, "The dialog offers Delete")
        delete?.tap()
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: 30) == .completed
    }

    // MARK: Adding

    /// A new job opens on its page: the bar says Job, the cursor is in its role, and the save status stands at the top
    /// of the page. Back shows the job in the form as a line that names it.
    @MainActor
    func testAddedJobOpensItsPage() throws {
        let app = try launchAndOpen()
        addRow(to: "experiences", in: app)

        XCTAssertTrue(app.navigationBars.staticTexts["Job"].waitForExistence(timeout: 30), "The bar says Job")
        app.typeText("Foreman")
        let role = app.textFields["editor.field.experienceRole"]
        XCTAssertEqual(role.value as? String, "Foreman", "The role has the cursor")
        // The CV's form, under the page, has a status of its own
        let status = app.entryPage.descendants(matching: .any).matching(identifier: "editor.status").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 30), "The page shows the save status")
        XCTAssertLessThan(status.frame.midY, role.frame.minY, "The save status comes before the fields")
        putKeyboardAway(in: app)

        app.leaveEntryPage()
        let job = app.buttons["editor.entry.experiences"]
        app.scrollForm(until: job, named: "The row of the job", forward: false)
        XCTAssertTrue(job.label.contains("Foreman"), "\(job.label) names the job")
    }

    /// A new job goes first. With one row the section says nothing about moving; with two it says how.
    @MainActor
    func testMoveHintShowsWithTwoRows() throws {
        let app = try launchAndOpen()
        let hint = app.staticTexts["editor.rows.hint.experiences"]

        addRow(to: "experiences", typing: "Foreman", in: app)
        app.scrollForm(until: app.buttons["editor.add.experiences"], named: "The add button of the jobs")
        XCTAssertFalse(hint.exists, "One row needs no hint")

        addRow(to: "experiences", typing: "Rigger", in: app)
        app.scrollForm(until: hint, named: "The hint of the jobs")
        XCTAssertEqual(hint.label, "Touch and hold an entry to move it.")
        let labels = rows(of: "experiences", in: app).map(\.label)
        XCTAssertEqual(labels.count, 2, "\(labels)")
        XCTAssertTrue(labels.first?.contains("Rigger") ?? false, "The new job goes first: \(labels)")
    }

    // MARK: Removing

    /// The page's Delete names what goes; the row goes only once the person confirms, and the page closes. Cancel keeps
    /// the page open.
    @MainActor
    func testDeleteFromThePage() throws {
        let app = try launchAndOpen()
        addRow(to: "experiences", typing: "Foreman", in: app)
        let job = app.buttons["editor.entry.experiences"]
        app.scrollForm(until: job, named: "The row of the job", forward: false)
        job.tap()
        XCTAssertTrue(app.entryPage.waitForExistence(timeout: 30), "A tap on the row opens its page")
        XCTAssertEqual(app.textFields["editor.field.experienceRole"].value as? String, "Foreman")

        let delete = app.buttons["editor.entry.delete"]
        app.scrollForm(until: delete, named: "The Delete of the page")
        XCTAssertEqual(delete.label, "Delete job")
        let question = app.staticTexts["Delete “Foreman”?"]
        delete.tap()
        XCTAssertTrue(question.waitForExistence(timeout: 30), "The dialog names the job")
        XCTAssertTrue(app.staticTexts["This cannot be undone."].exists)
        // The dialog is a popover from the page's Delete, with no Cancel: a tap outside it cancels
        app.cancelDialog(showing: question)
        XCTAssertTrue(waitUntilGone(question))
        XCTAssertTrue(app.entryPage.exists, "Cancel keeps the page")

        delete.tap()
        XCTAssertTrue(question.waitForExistence(timeout: 30))
        confirmDelete(in: app)
        XCTAssertTrue(waitUntilGone(app.entryPage), "The page closes once the row goes")
        XCTAssertTrue(waitUntilGone(job), "The row goes once the person confirms")
    }

    // MARK: The line of a row

    /// A language's line shows its level beside its name. Its context menu, which stands in for its VoiceOver actions,
    /// names it, offers no move for a single row, and deletes it once the person confirms.
    @MainActor
    func testLanguageLineShowsItsLevelAndItsMenu() throws {
        let app = try launchAndOpen()
        addRow(to: "languages", in: app)
        XCTAssertTrue(app.navigationBars.staticTexts["Language"].waitForExistence(timeout: 30), "The bar says Language")
        app.typeText("German")
        putKeyboardAway(in: app)
        let menu = app.buttons.matching(identifier: "editor.field.languageProficiency").firstMatch
        app.scrollForm(until: menu, named: "The menu Proficiency")
        menu.tap()
        let level = "B2 – Upper intermediate"
        XCTAssertTrue(app.buttons[level].waitForExistence(timeout: 30), "The menu offers \(level)")
        app.buttons[level].tap()
        app.leaveEntryPage()

        let language = app.buttons["editor.entry.languages"]
        app.scrollForm(until: language, named: "The row of the language", forward: false)
        XCTAssertTrue(language.label.contains("German"), "\(language.label) names the language")
        XCTAssertTrue(language.label.contains(level), "\(language.label) shows the level")

        language.press(forDuration: 1.2)
        let remove = app.buttons["Delete German"]
        XCTAssertTrue(remove.waitForExistence(timeout: 30), "The menu names the row")
        XCTAssertFalse(app.buttons["Move German Up"].exists, "A single row cannot move")
        XCTAssertFalse(app.buttons["Move German Down"].exists, "A single row cannot move")
        remove.tap()
        XCTAssertTrue(app.staticTexts["Delete “German”?"].waitForExistence(timeout: 30), "The dialog names the row")
        confirmDelete(in: app)
        XCTAssertTrue(waitUntilGone(language), "The row goes once the person confirms")
        XCTAssertFalse(app.entryPage.exists, "Deleting from the form opens no page")
    }

    // MARK: Going back

    /// The menu of the back button goes from a row's page straight to the list: the CV closes, and its row opens it
    /// again.
    @MainActor
    func testBackToTheListFromAPage() throws {
        let app = try launchAndOpen()
        addRow(to: "experiences", in: app)
        putKeyboardAway(in: app)

        app.navigationBars.buttons.firstMatch.press(forDuration: 1.2)
        let list = app.buttons.matching(NSPredicate(format: "label == %@", "My CVs")).firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 30), "The menu of the back button offers the list")
        list.tap()

        let row = app.descendants(matching: .any).matching(identifier: "shell.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", title + ", ")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The list shows \(title)")
        let form = app.descendants(matching: .any).matching(identifier: "shell.detail.opened").firstMatch
        XCTAssertTrue(waitUntilGone(form), "No CV is open")
        row.tap()
        let opened = app.textFields["editor.field.title"]
        XCTAssertTrue(opened.waitForExistence(timeout: 30), "The row opens \(title) again")
    }
}
