import XCTest

/// The shell lists the CVs of the store in its sidebar and shows the open CV in its detail. On a compact screen it shows
/// one column at a time, the list first; on a regular one both.
final class ShellUITests: XCTestCase {
    private let title = "Backend Engineer"
    private let identity = "6B1F6C1E-1B8C-4C1B-9D55-1F3B2C8B7A01"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A store folder of its own with one CV in it, put there by the app's launch fixture.
    @MainActor
    private func launchWithOneCV(largestText: Bool = false) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", try seed()]
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    private func seed() throws -> String {
        let cv = """
        {"schemaVersion":1,"id":"\(identity)","revision":1,
         "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"\(title)",
         "personal":{"fullName":"Mara Ellison","professionalTitle":"","location":"","summary":""},
         "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],"interests":[]}
        """
        // The store reads a CV from the file named by its identity
        let files = ["\(identity).cv.json": cv]
        // The fixture takes a JSON map from file name to content, in base 64
        return try JSONEncoder().encode(files).base64EncodedString()
    }

    private func isCompact(_ app: XCUIApplication) -> Bool {
        app.windows.firstMatch.horizontalSizeClass != .regular
    }

    private func row(of app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "shell.row").firstMatch
    }

    @MainActor
    func testTheSidebarShowsTheRowOfTheStoredCV() throws {
        let app = try launchWithOneCV()

        let row = row(of: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        // The row reads its label first, then the person and the time since the last save
        XCTAssertTrue(row.label.hasPrefix(title + ", "), row.label)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "shell.detail.opened").firstMatch.exists)
    }

    /// Tapping the row opens the CV in the detail. On a compact screen the detail replaces the list and Back returns to it
    /// with nothing open; on a regular screen both columns stay.
    @MainActor
    func testTappingTheRowOpensTheCVAndBackReturnsToTheList() throws {
        let app = try launchWithOneCV()
        let row = row(of: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30))

        row.tap()

        let heading = app.staticTexts["shell.detail.title"]
        XCTAssertTrue(heading.waitForExistence(timeout: 30))
        XCTAssertEqual(heading.label, title)
        if isCompact(app) {
            XCTAssertFalse(row.isHittable, "One column at a time")
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(row.waitForExistence(timeout: 30))
            XCTAssertTrue(row.isHittable)
            XCTAssertFalse(heading.exists)

            // The person can open the CV again: going back left nothing selected, so the row is a new selection
            row.tap()
            XCTAssertTrue(heading.waitForExistence(timeout: 30))
            XCTAssertEqual(heading.label, title)
            XCTAssertFalse(row.isHittable, "One column at a time")
        } else {
            XCTAssertTrue(row.isHittable, "Both columns")
            XCTAssertTrue(heading.isHittable)
        }
    }

    /// Before a CV is open the detail says so, where both columns show.
    @MainActor
    func testTheDetailSaysNoCVIsOpenWhereBothColumnsShow() throws {
        let app = try launchWithOneCV()
        XCTAssertTrue(row(of: app).waitForExistence(timeout: 30))
        try XCTSkipIf(isCompact(app), "A compact screen shows one column at a time")

        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "shell.detail.empty").firstMatch.exists)
    }

    /// On a compact screen the list shows first, with no detail beside it.
    @MainActor
    func testTheDetailIsNotShownBesideTheListOnACompactScreen() throws {
        let app = try launchWithOneCV()
        XCTAssertTrue(row(of: app).waitForExistence(timeout: 30))
        try XCTSkipUnless(isCompact(app), "A regular screen shows both columns")

        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "shell.detail.empty").firstMatch.exists)
    }

    /// A store whose only file is corrupt was used, so it is no first run: the list shows, empty, and not the welcome.
    /// (An empty store is a first run, `FirstRunUITests`.)
    @MainActor
    func testAStoreWithOnlyACorruptFileShowsTheEmptyList() throws {
        let app = XCUIApplication()
        let files = ["\(identity).cv.json": "not a CV"]
        app.launchArguments += [
            "-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", try JSONEncoder().encode(files).base64EncodedString(),
        ]
        app.launch()

        let empty = app.descendants(matching: .any).matching(identifier: "shell.sidebar.empty").firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 30))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "shell.row").count, 0)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "firstRun.title").firstMatch.exists)
    }

    /// At the largest accessibility size the row can still be tapped, and it opens the CV.
    @MainActor
    func testTheRowCanBeTappedAtTheLargestTextSize() throws {
        let app = try launchWithOneCV(largestText: true)
        let row = row(of: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        XCTAssertTrue(row.isHittable)

        row.tap()

        XCTAssertTrue(app.staticTexts["shell.detail.title"].waitForExistence(timeout: 30))
    }
}
