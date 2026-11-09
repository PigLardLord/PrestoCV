import XCTest

/// The list column shows the stored CVs, most recently saved first, each with its label, the person and role, and the time
/// since its last save. A row is renamed, duplicated or deleted from its menu, a swipe or the actions of VoiceOver; files
/// the store could not open are counted in a notice that names no file.
final class CVListUITests: XCTestCase {

    /// A CV the launch fixture stores before the app starts.
    private struct StoredCV {
        let identity: String
        let title: String
        var person = ""
        var role = ""
        /// When it was last saved, as the store writes it.
        let saved: String
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Launching

    /// A store folder of its own with the given CVs, and files that are not CVs under the given identities.
    @MainActor
    private func launch(_ cvs: [StoredCV], corrupt: [String] = [], largestText: Bool = false) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", try seed(cvs, corrupt: corrupt),
        ]
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    private func seed(_ cvs: [StoredCV], corrupt: [String]) throws -> String {
        var files: [String: String] = [:]
        for cv in cvs {
            files["\(cv.identity).cv.json"] = """
            {"schemaVersion":1,"id":"\(cv.identity)","revision":1,
             "createdAt":"2026-01-01T00:00:00Z","updatedAt":"\(cv.saved)","title":"\(cv.title)",
             "personal":{"fullName":"\(cv.person)","professionalTitle":"\(cv.role)","location":"","summary":""},
             "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],"interests":[]}
            """
        }
        for identity in corrupt {
            files["\(identity).cv.json"] = "not a CV"
        }
        // The fixture takes a JSON map from file name to content, in base 64
        return try JSONEncoder().encode(files).base64EncodedString()
    }

    private let siteManager = StoredCV(
        identity: "2B000000-0000-4000-8000-000000000002", title: "Site Manager",
        person: "Ines Calloway", role: "Works Supervisor", saved: "2026-03-05T00:00:00Z")
    private let costEstimator = StoredCV(
        identity: "1A000000-0000-4000-8000-000000000001", title: "Cost Estimator",
        person: "Ines Calloway", role: "Quantity Surveyor", saved: "2026-01-05T00:00:00Z")
    private let projectPlanner = StoredCV(
        identity: "3C000000-0000-4000-8000-000000000003", title: "Project Planner",
        person: "Ines Calloway", role: "Scheduler", saved: "2026-02-05T00:00:00Z")

    // MARK: Elements

    private func rows(of app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "shell.row")
    }

    /// The row whose label starts with the title: a row reads its label, then the person and role, then the time since
    /// its last save.
    private func row(titled title: String, in app: XCUIApplication) -> XCUIElement {
        rows(of: app).matching(NSPredicate(format: "label BEGINSWITH %@", title + ", ")).firstMatch
    }

    /// The label of each row, in the order the list shows them.
    @MainActor
    private func titles(of app: XCUIApplication) -> [String] {
        rows(of: app).allElementsBoundByIndex.map { row in
            String(row.label.prefix { $0 != "," })
        }
    }

    private func isCompact(_ app: XCUIApplication) -> Bool {
        app.windows.firstMatch.horizontalSizeClass != .regular
    }

    /// The menu of the row, opened by a long press, as the person opens it.
    @MainActor
    private func openMenu(of row: XCUIElement, in app: XCUIApplication) -> XCUIElement {
        row.press(forDuration: 1.2)
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 30))
        return delete
    }

    /// Swipes up until the element can be tapped: at the largest text sizes the list is longer than the screen.
    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var swipes = 0
        while !element.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
    }

    // MARK: Rows

    @MainActor
    func testListShowsRowsInOrder() throws {
        let app = try launch([costEstimator, siteManager, projectPlanner])
        XCTAssertTrue(row(titled: "Site Manager", in: app).waitForExistence(timeout: 30))

        XCTAssertEqual(titles(of: app), ["Site Manager", "Project Planner", "Cost Estimator"], "Most recently saved first")
        for cv in [siteManager, projectPlanner, costEstimator] {
            let label = row(titled: cv.title, in: app).label
            XCTAssertTrue(label.hasPrefix("\(cv.title), Ines Calloway · \(cv.role), Saved "), label)
            XCTAssertTrue(label.hasSuffix(" ago"), label)
        }
    }

    /// Titles that differ only by case are told apart by a number, given in the order of the CVs' identities, so the
    /// same CV keeps its number when the list is read again.
    @MainActor
    func testAlikeTitlesAreNumbered() throws {
        let app = try launch([
            StoredCV(identity: "1D000000-0000-4000-8000-000000000001", title: "Site Manager", saved: "2026-01-10T00:00:00Z"),
            StoredCV(identity: "2D000000-0000-4000-8000-000000000002", title: "site manager", saved: "2026-03-10T00:00:00Z"),
            StoredCV(identity: "3D000000-0000-4000-8000-000000000003", title: "SITE MANAGER", saved: "2026-02-10T00:00:00Z"),
        ])
        XCTAssertTrue(row(titled: "Site Manager", in: app).waitForExistence(timeout: 30))
        let expected = ["site manager (2)", "SITE MANAGER (3)", "Site Manager"]
        XCTAssertEqual(titles(of: app), expected)

        // Back from the background, the list is read again
        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(row(titled: "Site Manager", in: app).waitForExistence(timeout: 30))
        XCTAssertEqual(titles(of: app), expected)
    }

    // MARK: Rename, duplicate, delete

    /// The rename starts from the stored title, and the row shows the new one.
    @MainActor
    func testRenameShowsTheNewTitle() throws {
        let app = try launch([siteManager])
        let row = row(titled: "Site Manager", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30))

        _ = openMenu(of: row, in: app)
        app.buttons["Rename"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 30))
        let field = alert.textFields.firstMatch
        XCTAssertEqual(field.value as? String, "Site Manager")
        if !app.keyboards.firstMatch.waitForExistence(timeout: 5) {
            field.tap()
        }
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20) + "Works Planner")
        alert.buttons["Rename"].tap()

        XCTAssertTrue(self.row(titled: "Works Planner", in: app).waitForExistence(timeout: 30))
        XCTAssertFalse(self.row(titled: "Site Manager", in: app).exists)
    }

    /// The copy is a new row whose title says what it copies.
    @MainActor
    func testDuplicateAddsARow() throws {
        let app = try launch([siteManager])
        let row = row(titled: "Site Manager", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30))

        _ = openMenu(of: row, in: app)
        app.buttons["Duplicate"].tap()

        XCTAssertTrue(self.row(titled: "Copy of Site Manager", in: app).waitForExistence(timeout: 30))
        XCTAssertTrue(self.row(titled: "Site Manager", in: app).exists)
        XCTAssertEqual(rows(of: app).count, 2)
    }

    /// A swipe offers delete; the app asks first, naming the CV, and then the row leaves. The other CV stays.
    @MainActor
    func testDeleteAsksAndRemoves() throws {
        let app = try launch([siteManager, costEstimator])
        let row = row(titled: "Site Manager", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30))

        row.swipeLeft()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 30))
        delete.tap()

        XCTAssertTrue(app.staticTexts["Delete “Site Manager”?"].waitForExistence(timeout: 30))
        XCTAssertTrue(row.exists, "Nothing is deleted before the person confirms")
        app.buttons["Delete CV"].tap()

        XCTAssertTrue(row.waitForNonExistence(timeout: 30))
        XCTAssertTrue(self.row(titled: "Cost Estimator", in: app).exists)
    }

    /// Deleting the CV that is open closes it: the detail says no CV is open.
    @MainActor
    func testDeleteTheSelectedClearsTheDetail() throws {
        let app = try launch([siteManager, costEstimator])
        let row = row(titled: "Site Manager", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        try XCTSkipIf(isCompact(app), "A compact screen shows the list or the detail, not both")
        row.tap()
        XCTAssertTrue(app.staticTexts["shell.detail.title"].waitForExistence(timeout: 30))

        openMenu(of: row, in: app).tap()
        let confirm = app.buttons["Delete CV"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 30))
        confirm.tap()

        XCTAssertTrue(row.waitForNonExistence(timeout: 30))
        let empty = app.descendants(matching: .any).matching(identifier: "shell.detail.empty").firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["shell.detail.title"].exists)
    }

    // MARK: Files the store could not open

    /// The notice counts the files and names none of them; the other CVs show, and the notice can be hidden.
    @MainActor
    func testUnreadableNoticeShowsCountAndDismisses() throws {
        let app = try launch(
            [siteManager], corrupt: ["4E000000-0000-4000-8000-000000000001", "4E000000-0000-4000-8000-000000000002"])
        let notice = app.descendants(matching: .any).matching(identifier: "list.notice").firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 30))

        XCTAssertEqual(app.staticTexts["list.notice.count"].label, "2 CVs could not be opened.")
        for text in notice.staticTexts.allElementsBoundByIndex {
            XCTAssertFalse(text.label.contains(".json") || text.label.contains("/"), "A notice names no file: \(text.label)")
        }
        XCTAssertTrue(row(titled: "Site Manager", in: app).exists)

        notice.buttons["Hide"].tap()

        XCTAssertTrue(notice.waitForNonExistence(timeout: 30))
        XCTAssertTrue(row(titled: "Site Manager", in: app).exists)
    }

    // MARK: Accessibility

    /// Every action of a row is in its menu, not only behind a swipe. The actions of VoiceOver are the same list as the
    /// menu's (`CVListViewModel.rowActions`), which a UI test cannot invoke: XCUITest has no call for a custom action.
    @MainActor
    func testRowActionsByAccessibilityActions() throws {
        let app = try launch([siteManager])
        let row = row(titled: "Site Manager", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30))

        _ = openMenu(of: row, in: app)

        for action in ["Duplicate", "Rename", "Delete"] {
            XCTAssertTrue(app.buttons[action].exists, "\(action) is in the menu")
        }
    }

    /// At the largest accessibility size the notice and its button, the row, its menu and the rename stay usable.
    @MainActor
    func testListAtTheLargestTextSize() throws {
        let app = try launch([siteManager], corrupt: ["4E000000-0000-4000-8000-000000000003"], largestText: true)
        let notice = app.descendants(matching: .any).matching(identifier: "list.notice").firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 30))
        let hide = notice.buttons["Hide"]
        scrollTo(hide, in: app)
        XCTAssertTrue(hide.isHittable)
        XCTAssertTrue(app.staticTexts["list.notice.count"].exists)

        let row = row(titled: "Site Manager", in: app)
        scrollTo(row, in: app)
        XCTAssertTrue(row.isHittable)
        _ = openMenu(of: row, in: app)
        app.buttons["Rename"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 30))
        XCTAssertTrue(alert.textFields.firstMatch.exists)
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 30))

        scrollTo(row, in: app)
        row.tap()
        XCTAssertTrue(app.staticTexts["shell.detail.title"].waitForExistence(timeout: 30))
    }
}
