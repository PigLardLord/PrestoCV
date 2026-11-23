import XCTest

/// The first launch after an upgrade imports the released app's CVs. A sheet over the list names what each CV left out;
/// Confirm removes the old copies, Not now keeps them and the sheet comes back at the next launch, unless the person
/// asked not to be reminded. While the old copy stays, the list marks the CV as incomplete. Old CVs the import could not bring in are told in a notice over the list, never as an empty
/// list, and their files stay for the next launch.
final class LegacyImportReportUITests: RuntimeIssueFailingTestCase {

    /// A launch folder of the test's own, kept across its relaunches.
    private let storage = "legacy-" + UUID().uuidString
    private let identity = "5A000000-0000-4000-8000-000000000001"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Launching

    /// The released app's CV, which loses its look and its email address in the import.
    private var backend: String {
        #"{"id":"\#(identity)","createdAt":"2026-10-01T00:00:00Z","updatedAt":"2026-10-02T00:00:00Z","name":"Backend","#
            + #""personalInfo":{"name":"Ines Calloway","email":"not an address"},"look":{"palette":"ocean"}}"#
    }

    /// Launches on the test's folder; `legacy` is a released app's file to put there first.
    @MainActor
    private func launch(legacy: String? = nil, largestText: Bool = false) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextStorage", storage]
        if let legacy {
            // The fixture takes a JSON map from file name to content, in base 64
            let files = try JSONEncoder().encode(["cv_\(identity).json": legacy]).base64EncodedString()
            app.launchArguments += ["-PrestoCVNextLegacySeed", files]
        }
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    /// Quits and opens the app again on the same folder, without seeding it.
    @MainActor
    private func relaunch(_ app: XCUIApplication) throws -> XCUIApplication {
        app.terminate()
        return try launch()
    }

    // MARK: Elements

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func listRow(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "shell.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Backend, ")).firstMatch
    }

    /// The words of the list's mark on a CV the import left details out of.
    private let incomplete = "Some details left out"

    /// Waits until the list's row of the imported CV shows the mark, or does not.
    @MainActor
    private func waitUntilRow(in app: XCUIApplication, isMarked marked: Bool) -> Bool {
        let format = marked ? "label CONTAINS %@" : "NOT (label CONTAINS %@)"
        let shown = expectation(for: NSPredicate(format: format, incomplete), evaluatedWith: listRow(in: app))
        return XCTWaiter().wait(for: [shown], timeout: 30) == .completed
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: 30) == .completed
    }

    /// The list shows the imported CV and no sheet covers it.
    @MainActor
    private func assertListWithoutSheet(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(listRow(in: app).waitForExistence(timeout: 30), "The imported CV is listed", file: file, line: line)
        XCTAssertFalse(app.buttons["legacyImport.notNow"].waitForExistence(timeout: 5), "No sheet", file: file, line: line)
    }

    /// Flips the switch by the switch itself: a tap on its words does not.
    @MainActor
    private func flip(_ toggle: XCUIElement) {
        let was = toggle.value as? String ?? ""
        let knob = toggle.switches.firstMatch
        if knob.exists {
            knob.tap()
        } else {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        }
        let flipped = expectation(for: NSPredicate(format: "value != %@", was), evaluatedWith: toggle)
        XCTAssertEqual(XCTWaiter().wait(for: [flipped], timeout: 30), .completed, "The switch flips")
    }

    // MARK: The sheet

    /// The sheet names each detail left out; Not now keeps the old copy, so the sheet is back at the next launch, until
    /// Confirm removes it.
    @MainActor
    func testTheSheetComesBackUntilConfirmed() throws {
        var app = try launch(legacy: backend)
        let row = element("legacyImport.row", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The sheet shows over the list")
        XCTAssertEqual(row.label, "Backend, left out Design and Email")

        app.buttons["legacyImport.notNow"].tap()
        XCTAssertTrue(waitUntilGone(row), "Not now closes the sheet")
        XCTAssertTrue(listRow(in: app).exists, "The imported CV is listed")
        XCTAssertTrue(waitUntilRow(in: app, isMarked: true), "The list marks the CV while its old copy stays")

        app = try relaunch(app)
        let confirm = app.buttons["legacyImport.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 30), "The old copy stayed, so the sheet is back")
        confirm.tap()
        XCTAssertTrue(waitUntilGone(confirm), "Confirm closes the sheet once the old copy is removed")
        XCTAssertTrue(waitUntilRow(in: app, isMarked: false), "Confirm takes the mark away")

        app = try relaunch(app)
        assertListWithoutSheet(app)
        XCTAssertTrue(waitUntilRow(in: app, isMarked: false), "No mark once the old copy is gone")
    }

    /// With "Don't remind me again", Not now keeps the old copy and the sheet does not come back.
    @MainActor
    func testDontRemindMeAgain() throws {
        let app = try launch(legacy: backend)
        let check = element("legacyImport.remindNoMore", in: app)
        XCTAssertTrue(check.waitForExistence(timeout: 30))

        flip(check)
        app.buttons["legacyImport.notNow"].tap()
        XCTAssertTrue(waitUntilGone(check))

        let again = try relaunch(app)
        assertListWithoutSheet(again)
        XCTAssertTrue(waitUntilRow(in: again, isMarked: true), "The old copy stays, so the list still marks the CV")
    }

    /// Pulling the sheet down closes it as Not now does: it never removes the old copy.
    @MainActor
    func testPullingTheSheetDownDoesNotConfirm() throws {
        let app = try launch(legacy: backend)
        let row = element("legacyImport.row", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30))

        row.swipeDown(velocity: .fast)
        XCTAssertTrue(waitUntilGone(row), "The sheet closes")

        XCTAssertTrue(element("legacyImport.row", in: try relaunch(app)).waitForExistence(timeout: 30), "The sheet is back")
    }

    /// At the largest accessibility text size Confirm is the last item of the sheet: it scrolls into reach.
    @MainActor
    func testConfirmCanBeTappedAtTheLargestTextSize() throws {
        let app = try launch(legacy: backend, largestText: true)
        let confirm = app.buttons["legacyImport.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 30))

        for _ in 0..<5 where !confirm.canBeTapped(in: app) {
            app.swipeUp()
        }
        XCTAssertTrue(confirm.canBeTapped(in: app), "Confirm scrolls into reach")
        confirm.tap()
        XCTAssertTrue(waitUntilGone(confirm))
    }

    // MARK: CVs not imported

    /// A damaged old file leaves the store empty: the list tells it, never as if the CVs were gone, and the file stays for
    /// the next launch.
    @MainActor
    func testADamagedFileIsToldNotHidden() throws {
        var app = try launch(legacy: "not a CV")
        let notice = element("legacyImport.notice", in: app)
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The list tells what was not imported")
        XCTAssertTrue(notice.staticTexts["1 CV could not be imported."].exists)
        XCTAssertTrue(notice.staticTexts["1 file is damaged and stays on this device."].exists)
        XCTAssertFalse(app.buttons["legacyImport.notNow"].exists, "Nothing was imported with changes: no sheet")

        app.buttons["legacyImport.notice.hide"].tap()
        XCTAssertTrue(waitUntilGone(notice), "Hide takes the notice away")

        app = try relaunch(app)
        XCTAssertTrue(element("legacyImport.notice", in: app).waitForExistence(timeout: 30), "The file is read again")
    }
}
