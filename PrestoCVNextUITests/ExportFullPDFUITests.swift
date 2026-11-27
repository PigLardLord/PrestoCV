import XCTest

/// The PDF of the export on the whole screen. The sheet's corner button, or a tap on its pages, shows it under the name
/// of its file; there the PDF's text is read, as VoiceOver and XCUITest see it, and Done takes the person back to the
/// sheet with its PDF. The sheet's own pages are for the eye only, so this is where the test reads what the PDF holds.
final class ExportFullPDFUITests: RuntimeIssueFailingTestCase {

    /// A CV the launch fixture stores before the app starts, in English.
    private struct StoredCV {
        let identity: String
        let title: String
        let person: String
        let email: String
        let phone: String
        let jobs: [Job]
    }

    /// A job as the store's file keeps it.
    private struct Job: Encodable {
        struct Month: Encodable {
            let year: Int
            let month: Int
        }
        let role: String
        let company: String
        let location: String
        let description: String
        let start: Month
        let end: Month
        let current: Bool
    }

    private let complete = StoredCV(
        identity: "6B1F6C1E-1B8C-4C1B-9D55-1F3B2C8B7A01", title: "Backend Engineer", person: "Mara Ellison",
        email: "mara.ellison@example.com", phone: "+49 30 1234567", jobs: [])

    /// A word that only the end of the last job says, short enough that no line break splits it.
    private static let lastWord = "Zqxv"

    /// A CV of sixteen jobs that takes more than one page; the editor shows no job, so only the PDF says the last word.
    private var long: StoredCV {
        let duty = "Planned the routes of forty lorries a day across three depots, kept the drivers' hours within the "
            + "rules and cut the empty runs by a fifth. "
        let jobs = (0..<16).map { index in
            Job(
                role: "Transport Planner", company: "Harbour Freight \(index + 1)", location: "Hamburg",
                description: String(repeating: duty, count: 5) + (index == 15 ? Self.lastWord : "Done."),
                start: Job.Month(year: 1990 + 2 * index, month: 1), end: Job.Month(year: 1991 + 2 * index, month: 12),
                current: false)
        }
        return StoredCV(
            identity: "0C7D2E4A-5B6F-4A1C-8E9D-3F2A1B0C9D8E", title: "Logistics Lead", person: "Ines Corr",
            email: "ines.corr@example.com", phone: "+49 30 7654321", jobs: jobs)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Tests

    @MainActor
    func testCornerButtonShowsThePDFOnTheWholeScreen() throws {
        let app = try launch(complete)
        openSheet(of: complete, in: app)

        let corner = app.buttons["Show the full PDF, 1 page"]
        XCTAssertTrue(corner.isHittable, "The corner button can be tapped, and VoiceOver reads it with the page count")
        XCTAssertGreaterThan(corner.frame.width, 43.99, "The corner button is wide enough to tap")
        XCTAssertGreaterThan(corner.frame.height, 43.99, "The corner button is tall enough to tap")
        corner.tap()

        let done = app.buttons["export.full.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 30), "The PDF shows on the whole screen")
        XCTAssertTrue(app.staticTexts["Mara Ellison – CV.pdf"].exists, "The screen's title is the file's name")
        XCTAssertTrue(text(containing: complete.person, in: app).waitForExistence(timeout: 30), "The PDF holds the name")
        XCTAssertTrue(text(containing: complete.email, in: app).exists, "The PDF holds the email")
        keepScreenshot("The PDF on the whole screen", of: app)

        done.tap()
        XCTAssertTrue(waitUntilGone(done), "Done takes the whole screen away")
        XCTAssertTrue(app.staticTexts["export.pages"].exists, "The sheet shows again, with its PDF")
    }

    @MainActor
    func testTapOnThePagesShowsThePDFOnTheWholeScreen() throws {
        let app = try launch(complete)
        openSheet(of: complete, in: app)

        // The pages are for the eye only, so XCUITest does not see them: tap where they are, above the page count and
        // away from the corner button in their lower trailing corner.
        let pages = app.staticTexts["export.pages"]
        let sheetTop = app.buttons["export.close"].frame.maxY
        let pagesTop = pages.frame.minY
        let point = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: app.frame.midX - 40, dy: sheetTop + (pagesTop - sheetTop) * 0.3))
        point.tap()

        XCTAssertTrue(app.buttons["export.full.done"].waitForExistence(timeout: 30), "A tap on the pages shows the PDF")
    }

    @MainActor
    func testEveryPageOfALongCVIsOnTheWholeScreen() throws {
        let cv = long
        let app = try launch(cv)
        openSheet(of: cv, in: app)

        let corner = app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "Show the full PDF, ([2-9]|[1-9][0-9]) pages")
        ).firstMatch
        XCTAssertTrue(corner.exists, "The corner button counts the pages that a long CV takes")
        corner.tap()

        XCTAssertTrue(app.buttons["export.full.done"].waitForExistence(timeout: 30), "The PDF shows on the whole screen")
        XCTAssertTrue(text(containing: cv.person, in: app).waitForExistence(timeout: 30), "The first page shows")
        // PDFKit gives the text of the whole document as one text view, laid out over every page: its bottom edge is the
        // end of the last page. Swipe until it is on screen, so that the test shows the person can reach it.
        let document = text(containing: Self.lastWord, in: app)
        XCTAssertTrue(document.exists, "The whole screen gives the text of the last page too")
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThan(document.frame.maxY, screen.maxY, "The last page of a long CV starts below the screen")
        var swipes = 0
        while document.frame.maxY > screen.maxY && swipes < 40 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertLessThanOrEqual(document.frame.maxY, screen.maxY, "Swipes bring the end of the last page on screen")
        keepScreenshot("The last page of a long CV", of: app)
    }

    @MainActor
    func testTheCornerButtonIsInThePhonesLanguage() throws {
        let app = try launch(complete, language: "de", locale: "de_DE")
        openSheet(of: complete, in: app)

        let corner = app.buttons["Gesamtes PDF anzeigen, 1 Seite"]
        XCTAssertTrue(corner.exists, "The corner button speaks the phone's language, with the page count")
        corner.tap()

        let done = app.buttons["export.full.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 30), "The PDF shows on the whole screen")
        XCTAssertEqual(done.label, "Fertig", "Done speaks the phone's language")
        XCTAssertTrue(app.staticTexts["Mara Ellison – CV.pdf"].exists, "The file's name follows the CV's language")
    }

    // MARK: Launching

    /// A store folder of its own with the CV, on a phone in English unless a test says otherwise.
    @MainActor
    private func launch(_ cv: StoredCV, language: String = "en", locale: String = "en_US") throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-PrestoCVNextEmptyStorage", "-PrestoCVNextReadyDesigns",
            "-PrestoCVNextSeed", try seed(cv),
        ]
        app.launch()
        return app
    }

    private func seed(_ cv: StoredCV) throws -> String {
        let jobs = String(decoding: try JSONEncoder().encode(cv.jobs), as: UTF8.self)
        // The store reads a CV from the file named by its identity; the language is the PDF's
        let file = """
        {"schemaVersion":1,"id":"\(cv.identity)","revision":1,
         "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"\(cv.title)",
         "personal":{"fullName":"\(cv.person)","professionalTitle":"","email":"\(cv.email)","phone":"\(cv.phone)",
                     "location":"","summary":""},
         "experiences":\(jobs),"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],
         "interests":[],"language":"en"}
        """
        // The fixture takes a JSON map from file name to content, in base 64
        return try JSONEncoder().encode(["\(cv.identity).cv.json": file]).base64EncodedString()
    }

    /// Opens the stored CV from its row, then its export, and waits for the PDF's page count.
    @MainActor
    private func openSheet(of cv: StoredCV, in app: XCUIApplication) {
        let row = app.descendants(matching: .any).matching(identifier: "shell.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", cv.title + ", ")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The list shows \(cv.title)")
        row.tap()
        XCTAssertTrue(app.textFields["editor.field.title"].waitForExistence(timeout: 30), "The form of \(cv.title) opens")
        app.buttons["editor.export"].tap()
        XCTAssertTrue(app.staticTexts["export.pages"].waitForExistence(timeout: 60), "The sheet counts the PDF's pages")
    }

    // MARK: Elements and waiting

    /// The text view of the PDF that holds the text: PDFKit shows the whole document's text as the value of one text
    /// view, whose frame is the document laid out over all its pages.
    private func text(containing value: String, in app: XCUIApplication) -> XCUIElement {
        app.textViews.matching(NSPredicate(format: "value CONTAINS[c] %@", value)).firstMatch
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
