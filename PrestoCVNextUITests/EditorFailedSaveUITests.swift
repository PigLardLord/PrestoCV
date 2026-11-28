import XCTest

/// The editor while the store refuses to write (#402, 5-15c): the person's text stays on screen, the status line and
/// the notice say so, Try Again writes it again, and nothing leaves the editor while the text is not stored, by Back,
/// by the edge swipe or by another row of the list. The launch fixture `-PrestoCVNextFailWrites <count>` makes the first
/// <count> writes fail and the next ones succeed; `-PrestoCVNextAutosavePause <seconds>` lengthens the autosave's
/// pause.
final class EditorFailedSaveUITests: RuntimeIssueFailingTestCase {

    private let foreman = (identity: "8D3A8E3A-3DAE-4E3D-9F77-3B5D4EAD9C03", title: "Site Foreman")
    private let surveyor = (identity: "9E4B9F4B-4EBF-4F4E-8088-4C6E5FBEAD04", title: "Quantity Surveyor")

    // MARK: English words

    private let saved = "Saved on this device"
    private let failed = "The last change could not be saved. Your next change tries again."
    /// What the person types at the end of the title, and the title it makes.
    private let typed = " Lead"
    private let edited = "Site Foreman Lead"

    /// Writes that never run out: more than any test makes.
    private let always = "1000000"
    /// The seconds the autosave waits when a test leaves the editor before the pause: longer than any typing takes.
    private let longPause = "60"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Failing

    @MainActor
    func testAFailedSaveKeepsTheEditsAndTryAgainStoresThem() throws {
        let app = try launch(failingWrites: "1")
        typeTheTitle(in: app)
        let retry = app.buttons["editor.notice.retry"]

        XCTAssertTrue(app.element("editor.notice").waitForExistence(timeout: 30), "The notice says the text is not stored")
        XCTAssertTrue(app.staticTexts["editor.status"].waitUntil(reads: failed), "The status line says why")
        XCTAssertEqual(app.textInput("editor.field.title").value as? String, edited, "The text typed stays in the editor")
        XCTAssertTrue(retry.waitForExistence(timeout: 30), "The notice offers Try Again")
        XCTAssertGreaterThanOrEqual(retry.frame.height, 43.99, "Try Again is at least 44 points tall")

        retry.tap()

        XCTAssertTrue(app.staticTexts["editor.status"].waitUntil(reads: saved), "Try Again stores the text")
        XCTAssertTrue(app.element("editor.notice").waitUntilGone(), "The notice goes once the text is stored")
        XCTAssertEqual(app.textInput("editor.field.title").value as? String, edited, "The text is still there")
        if app.isCompactWidth {
            XCTAssertTrue(app.backButton.waitForExistence(timeout: 30), "Back comes back once the text is stored")
            app.backButton.tap()
        }
        XCTAssertTrue(app.listRow(titled: edited).waitForExistence(timeout: 30), "The list shows the stored title")
    }

    @MainActor
    func testBackWithAStoreThatKeepsFailingKeepsTheEditsInTheEditor() throws {
        let app = try launch(failingWrites: always)
        typeTheTitle(in: app)
        XCTAssertTrue(app.staticTexts["editor.status"].waitUntil(reads: failed), "The status line says the text is not stored")

        if app.isCompactWidth {
            XCTAssertFalse(
                app.backButton.exists, "No Back while the text cannot be stored: the bar holds \(app.barButtonIdentifiers)")
        } else {
            app.listRow(titled: surveyor.title).tap()
        }

        XCTAssertTrue(app.element("editor.notice").exists, "The editor keeps saying why")
        XCTAssertEqual(app.textInput("editor.field.title").value as? String, edited, "The text typed stays in the editor")
        XCTAssertFalse(app.element("shell.detail.empty").exists, "The editor is not replaced")
        XCTAssertTrue(app.listRow(titled: surveyor.title).exists == !app.isCompactWidth, "Only a wide window shows the list")
    }

    @MainActor
    func testBackBeforeThePauseWithAFailingStoreKeepsTheEditorAndTheListOffersItBack() throws {
        // The pause is a minute, so that however long the typing takes, nothing has been written when the editor is left:
        // leaving hands the editor to its write at once. That write fails, so the shell keeps the editor and the list
        // says so, with Open. The editor, once opened, says why.
        let app = try launch(failingWrites: always, autosavePause: longPause)
        typeTheTitle(in: app)

        if app.isCompactWidth {
            app.backButton.tap()
        } else {
            app.listRow(titled: surveyor.title).tap()
        }
        let open = app.element("list.kept.open")
        XCTAssertTrue(open.waitForExistence(timeout: 30), "The list offers the editor whose text was not stored")
        open.tap()

        XCTAssertTrue(app.staticTexts["editor.status"].waitUntil(reads: failed), "The editor says that the text is not stored")
        XCTAssertEqual(app.textInput("editor.field.title").value as? String, edited, "The text typed stays in the editor")
        XCTAssertTrue(app.element("editor.notice").exists, "The notice says what to do")
        XCTAssertFalse(app.backButton.exists, "The list is not shown: the bar holds \(app.barButtonIdentifiers)")
    }

    @MainActor
    func testTheEdgeSwipeWithAStoreThatKeepsFailingKeepsTheEdits() throws {
        let app = try launch(failingWrites: always)
        try XCTSkipUnless(app.isCompactWidth, "Only a narrow window has the edge swipe: a wide one shows the list beside")
        typeTheTitle(in: app)
        XCTAssertTrue(app.staticTexts["editor.status"].waitUntil(reads: failed), "The status line says the text is not stored")

        app.swipeBackFromTheLeftEdge()

        XCTAssertTrue(app.element("editor.notice").exists, "The swipe from the edge does not leave the editor")
        XCTAssertEqual(app.textInput("editor.field.title").value as? String, edited, "The text typed stays in the editor")
        XCTAssertFalse(app.listRow(titled: surveyor.title).isHittable, "The list does not come into view")
    }

    // MARK: Launching

    /// The two CVs stored, the Site Foreman open, in English, with the writes failing as told.
    @MainActor
    private func launch(failingWrites count: String, autosavePause seconds: String? = nil) throws -> XCUIApplication {
        let pause = seconds.map { ["-PrestoCVNextAutosavePause", $0] } ?? []
        let app = try XCUIApplication.seeded(
            [foreman, surveyor].map { ($0.identity, XCUIApplication.storedCV(identity: $0.identity, title: $0.title)) },
            arguments: ["-PrestoCVNextFailWrites", count] + pause)
        app.launch()
        app.openCV(titled: foreman.title)
        return app
    }

    /// Types at the end of the title.
    @MainActor
    private func typeTheTitle(in app: XCUIApplication) {
        app.textInput("editor.field.title").append(typed)
    }
}
