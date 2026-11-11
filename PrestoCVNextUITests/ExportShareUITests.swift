import XCTest

/// Share, in the bar of the export sheet, opens the system's share sheet with the PDF. The system's share sheet runs in
/// another process, which XCUITest cannot read, so these tests launch with the stand-in a Debug build shows in its
/// place: the PDF's file name and the ways a share sheet ends. A save or a send is confirmed by a line under the pages,
/// and Close then reads Done; a share closed without going through, or gone through to print or copy, says nothing; a
/// share that fails says so. A CV without a name has no PDF, and Share stays off.
final class ExportShareUITests: XCTestCase {

    /// A CV the launch fixture stores before the app starts, in English.
    private struct StoredCV {
        let identity: String
        let title: String
        let person: String
    }

    private let complete = StoredCV(
        identity: "6B1F6C1E-1B8C-4C1B-9D55-1F3B2C8B7A01", title: "Backend Engineer", person: "Mara Ellison")
    private let withoutName = StoredCV(
        identity: "7C2A7D2F-2C9D-4D2C-8E66-2A4C3D9C8B02", title: "Data Analyst", person: "")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Tests

    @MainActor
    func testShareOpensWithThePDFsFileName() throws {
        let app = try launch(complete)
        openSheet(of: complete, in: app)

        let share = app.buttons["export.share"]
        XCTAssertEqual(share.label, "Send or save PDF", "Share says what it does")
        XCTAssertTrue(share.isEnabled, "Share can be tapped once the PDF is made")
        share.tap()

        let fileName = element("share.standIn.fileName", in: app)
        XCTAssertTrue(fileName.waitForExistence(timeout: 30), "Share opens the share sheet")
        XCTAssertEqual(fileName.label, "Mara Ellison – CV.pdf", "The share sheet gets the PDF under its file's name")
    }

    @MainActor
    func testASaveIsConfirmedAndCloseReadsDone() throws {
        let app = try launch(complete)
        openSheet(of: complete, in: app)
        XCTAssertEqual(app.buttons["export.close"].label, "Close", "Before a share, the sheet closes with Close")

        share(answering: "share.standIn.save", in: app)

        let confirmation = element("export.confirmation", in: app)
        XCTAssertTrue(confirmation.waitForExistence(timeout: 30), "A line confirms the save")
        XCTAssertEqual(confirmation.label, "PDF saved", "The line says the PDF was saved")
        XCTAssertEqual(app.buttons["export.close"].label, "Done", "After a save, the sheet closes with Done")
        keepScreenshot("A saved PDF", of: app)

        app.buttons["export.close"].tap()
        XCTAssertTrue(waitUntilGone(app.staticTexts["export.pages"]), "Done closes the sheet")
        XCTAssertTrue(app.textFields["editor.field.title"].exists, "Done takes the person back to the form")
    }

    @MainActor
    func testASendIsConfirmed() throws {
        let app = try launch(complete)
        openSheet(of: complete, in: app)

        share(answering: "share.standIn.send", in: app)

        let confirmation = element("export.confirmation", in: app)
        XCTAssertTrue(confirmation.waitForExistence(timeout: 30), "A line confirms the send")
        XCTAssertEqual(confirmation.label, "PDF sent", "The line says the PDF was sent")
        XCTAssertEqual(app.buttons["export.close"].label, "Done", "After a send, the sheet closes with Done")
    }

    @MainActor
    func testACancelledShareSaysNothingAndCanBeTriedAgain() throws {
        let app = try launch(complete)
        openSheet(of: complete, in: app)

        share(answering: "share.standIn.cancel", in: app)

        XCTAssertFalse(element("export.confirmation", in: app).exists, "A share closed without going through says nothing")
        XCTAssertEqual(app.buttons["export.close"].label, "Close", "The sheet still closes with Close")
        XCTAssertTrue(app.buttons["export.share"].isEnabled, "Share can be tapped again")
        app.buttons["export.share"].tap()
        XCTAssertTrue(
            element("share.standIn.fileName", in: app).waitForExistence(timeout: 30), "Share opens the share sheet again")
    }

    @MainActor
    func testAFailedShareSaysSoAndCanBeTriedAgain() throws {
        let app = try launch(complete)
        openSheet(of: complete, in: app)

        share(answering: "share.standIn.fail", in: app)

        let failed = element("export.share.failed", in: app)
        XCTAssertTrue(failed.waitForExistence(timeout: 30), "A line says the share did not go through")
        XCTAssertEqual(failed.label, "The PDF could not be sent or saved. Try again.", "The line says what to do")
        XCTAssertFalse(element("export.confirmation", in: app).exists, "A failed share confirms nothing")
        XCTAssertEqual(app.buttons["export.close"].label, "Close", "The sheet still closes with Close")
        XCTAssertTrue(app.buttons["export.share"].isEnabled, "Share can be tapped again")
        keepScreenshot("A failed share", of: app)

        share(answering: "share.standIn.save", in: app)
        XCTAssertTrue(
            element("export.confirmation", in: app).waitForExistence(timeout: 30), "The next try goes through")
        XCTAssertFalse(failed.exists, "A share that goes through takes the line away")
    }

    @MainActor
    func testAPrintConfirmsNothing() throws {
        let app = try launch(complete)
        openSheet(of: complete, in: app)

        share(answering: "share.standIn.other", in: app)

        XCTAssertFalse(element("export.confirmation", in: app).exists, "A print says nothing of where the PDF went")
        XCTAssertFalse(element("export.share.failed", in: app).exists, "A print or a copy did not fail")
        XCTAssertEqual(app.buttons["export.close"].label, "Close", "The sheet still closes with Close")
    }

    @MainActor
    func testShareIsOffWithoutAName() throws {
        let app = try launch(withoutName)
        open(withoutName, in: app)
        app.buttons["editor.export"].tap()

        XCTAssertTrue(
            element("export.missing.blocker.name", in: app).waitForExistence(timeout: 60), "The sheet asks for the name")
        let share = app.buttons["export.share"]
        XCTAssertTrue(share.exists, "Share stays in the bar")
        XCTAssertFalse(share.isEnabled, "Share is off while there is no PDF to share")
        XCTAssertEqual(
            share.value as? String, "No PDF to send or save. The reason is shown below.", "VoiceOver hears why Share is off")
    }

    // MARK: Launching

    /// A store folder of its own with the CV, in English, sharing through the stand-in.
    @MainActor
    private func launch(_ cv: StoredCV) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage",
            "-PrestoCVNextSeed", try seed(cv), "-PrestoCVNextShareStandIn",
        ]
        app.launch()
        return app
    }

    private func seed(_ cv: StoredCV) throws -> String {
        // The store reads a CV from the file named by its identity; the language is the PDF's
        let file = """
        {"schemaVersion":1,"id":"\(cv.identity)","revision":1,
         "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"\(cv.title)",
         "personal":{"fullName":"\(cv.person)","professionalTitle":"","email":"mara.ellison@example.com",
                     "phone":"+49 30 1234567","location":"","summary":""},
         "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],"interests":[],
         "language":"en"}
        """
        // The fixture takes a JSON map from file name to content, in base 64
        return try JSONEncoder().encode(["\(cv.identity).cv.json": file]).base64EncodedString()
    }

    /// Opens the stored CV from its row and waits for its form.
    @MainActor
    private func open(_ cv: StoredCV, in app: XCUIApplication) {
        let row = app.descendants(matching: .any).matching(identifier: "shell.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", cv.title + ", ")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The list shows \(cv.title)")
        row.tap()
        XCTAssertTrue(app.textFields["editor.field.title"].waitForExistence(timeout: 30), "The form of \(cv.title) opens")
    }

    /// Opens the stored CV, then its export, and waits for the PDF's page count.
    @MainActor
    private func openSheet(of cv: StoredCV, in app: XCUIApplication) {
        open(cv, in: app)
        app.buttons["editor.export"].tap()
        XCTAssertTrue(app.staticTexts["export.pages"].waitForExistence(timeout: 60), "The sheet counts the PDF's pages")
    }

    /// Taps Share, then the stand-in's button `answer`, and waits for the stand-in to close.
    @MainActor
    private func share(answering answer: String, in app: XCUIApplication) {
        app.buttons["export.share"].tap()
        let button = app.buttons[answer]
        XCTAssertTrue(button.waitForExistence(timeout: 30), "Share opens the share sheet")
        button.tap()
        XCTAssertTrue(waitUntilGone(element("share.standIn.fileName", in: app)), "The share sheet closes")
    }

    // MARK: Elements and waiting

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: 30) == .completed
    }

    @MainActor
    private func keepScreenshot(_ name: String, of app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
