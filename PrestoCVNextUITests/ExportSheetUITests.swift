import XCTest

/// Export opens a sheet over the open CV with its PDF, as the person will send it, and the number of its pages. A CV
/// without a name makes no PDF, and the sheet says why; a CV without an email or a phone makes its PDF, and the sheet
/// says what a recruiter will miss. Close takes the person back to the form. The sheet's pages are for the eye only, so
/// XCUITest sees nothing of them: the page count says a PDF was made, PDFPagesTests checks the pages show it, and the
/// screenshots keep how it looks.
final class ExportSheetUITests: XCTestCase {

    /// A CV the launch fixture stores before the app starts, in English.
    private struct StoredCV {
        let identity: String
        let title: String
        let person: String
        /// The contact details, nil for a field the CV leaves empty.
        let email: String?
        let phone: String?
    }

    private let complete = StoredCV(
        identity: "6B1F6C1E-1B8C-4C1B-9D55-1F3B2C8B7A01", title: "Backend Engineer", person: "Mara Ellison",
        email: "mara.ellison@example.com", phone: "+49 30 1234567")
    private let withoutName = StoredCV(
        identity: "7C2A7D2F-2C9D-4D2C-8E66-2A4C3D9C8B02", title: "Data Analyst", person: "",
        email: "orla.penhaligon@example.com", phone: "+49 30 7654321")
    private let withoutEmail = StoredCV(
        identity: "8D3B8E30-3DAE-4E3D-9F77-3B5D4EAD9C03", title: "Site Manager", person: "Tobias Renn",
        email: nil, phone: "+49 30 2345678")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Tests

    @MainActor
    func testSheetShowsThePDFOfTheCV() throws {
        let app = try launch(complete, largestText: false)
        open(complete, in: app)
        app.buttons["editor.export"].tap()

        let pages = app.staticTexts["export.pages"]
        XCTAssertTrue(pages.waitForExistence(timeout: 60), "The sheet counts the pages of the PDF")
        XCTAssertEqual(pages.label, "1 page")
        XCTAssertFalse(element("export.missing.warning.email", in: app).exists, "The CV holds an email")
        XCTAssertFalse(element("export.missing.warning.phone", in: app).exists, "The CV holds a phone")
        keepScreenshot("The PDF of a complete CV", of: app)

        let close = app.buttons["export.close"]
        close.tap()
        XCTAssertTrue(waitUntilGone(close), "Close takes the sheet away")
        XCTAssertTrue(app.textFields["editor.field.title"].exists, "The form of the CV shows again")
    }

    @MainActor
    func testNoNameShowsWhyAndMakesNoPDF() throws {
        let app = try launch(withoutName, largestText: false)
        open(withoutName, in: app)
        app.buttons["editor.export"].tap()

        XCTAssertTrue(
            element("export.missing.blocker.name", in: app).waitForExistence(timeout: 60), "The sheet asks for the name")
        XCTAssertFalse(app.staticTexts["export.pages"].exists, "No pages are counted without a PDF")
        keepScreenshot("A CV without a name", of: app)
    }

    @MainActor
    func testMissingEmailOnlyWarns() throws {
        let app = try launch(withoutEmail, largestText: false)
        open(withoutEmail, in: app)
        app.buttons["editor.export"].tap()

        XCTAssertTrue(app.staticTexts["export.pages"].waitForExistence(timeout: 60), "The PDF is made without an email")
        XCTAssertTrue(element("export.missing.warning.email", in: app).exists, "The sheet says the email is missing")
        XCTAssertFalse(element("export.missing.blocker.email", in: app).exists, "A missing email does not stop the PDF")
        keepScreenshot("A CV without an email", of: app)
    }

    @MainActor
    func testSheetAtTheLargestTextSize() throws {
        let app = try launch(withoutEmail, largestText: true)
        open(withoutEmail, in: app)
        app.buttons["editor.export"].tap()

        XCTAssertTrue(app.staticTexts["export.pages"].waitForExistence(timeout: 60), "The sheet counts the pages")
        XCTAssertTrue(app.buttons["export.close"].isHittable, "Close can be tapped at the largest text size")
        keepScreenshot("The sheet at the largest text size", of: app)
    }

    // MARK: Launching

    /// A store folder of its own with the CV, in English.
    @MainActor
    private func launch(_ cv: StoredCV, largestText: Bool) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage",
            "-PrestoCVNextSeed", try seed(cv),
        ]
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    private func seed(_ cv: StoredCV) throws -> String {
        let email = cv.email.map { "\"\($0)\"" } ?? "null"
        let phone = cv.phone.map { "\"\($0)\"" } ?? "null"
        // The store reads a CV from the file named by its identity; the language is the PDF's
        let file = """
        {"schemaVersion":1,"id":"\(cv.identity)","revision":1,
         "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"\(cv.title)",
         "personal":{"fullName":"\(cv.person)","professionalTitle":"","email":\(email),"phone":\(phone),
                     "location":"","summary":""},
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
