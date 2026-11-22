import XCTest

/// A PDF opened in the app while the open CV's text cannot be stored (#404, 5-13e): the shell asks, over the editor,
/// whether to keep editing, and the PDF is let go, or to discard the edits the store does not have and import the PDF.
///
/// Two launch fixtures make the moment. `-PrestoCVNextOtherWindow conflict` makes the first write of a stored CV meet
/// another window's save, so the editor of Backend Engineer cannot store what the person types there.
/// `-PrestoCVNextOpenedFile` hands the window the PDF each time it becomes active, as another app opens it there: at
/// launch, where it opens as a draft that the person leaves for Backend Engineer, and again when the app comes back
/// from the background, over the editor that cannot store.
final class ImportOpenedFileQuestionUITests: RuntimeIssueFailingTestCase {
    private let identity = "6B1F6C1E-1B8C-4C1B-9D55-1F3B2C8B7A01"
    private let storedTitle = "Backend Engineer"
    private let storedName = "Mara Ellison"

    // MARK: English words

    private let question = "Import the PDF?"
    /// Why the text is not stored, in the status line's words, and on the next line what importing does.
    private let message = "Not saved: this CV was changed elsewhere in the app.\n"
        + "Importing the PDF discards your unsaved edits."
    private let discard = "Discard my edits and import"
    private let keepEditing = "Keep editing"
    private let saved = "Saved on this device"
    /// What the person types at the end of the name, and the name it makes.
    private let typed = " Lowe"
    private let editedName = "Mara Ellison Lowe"
    /// The person of the PDF, an invented one of the synthetic corpus (`PrestoCVCore/Tests/ImportFixtures`).
    private let importedName = "Emily Carter"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Tests

    /// Keep editing closes the question and leaves the editor as it was, with its notice and the text the person typed;
    /// nothing of the PDF opens.
    @MainActor
    func testKeepEditingKeepsTheEditor() throws {
        let app = try launch()
        asked(in: app)

        answer(keepEditing, in: app).tap()

        XCTAssertTrue(waitUntilGone(app.staticTexts[question]), "The question closes")
        XCTAssertTrue(element("editor.notice", in: app).exists, "The editor still says its text is not stored")
        let name = fullName(in: app)
        app.scrollForm(until: name, named: "The name field", forward: false)
        XCTAssertEqual(name.value as? String, editedName, "The text the person typed stays in the editor")
        XCTAssertFalse(app.importBox.exists, "The import does not show")
    }

    /// Discard my edits and import drops the edits the store does not have and opens the PDF in the editor; the CV
    /// keeps what was stored.
    @MainActor
    func testDiscardAndImportOpensTheDraft() throws {
        let app = try launch()
        asked(in: app)

        answer(discard, in: app).tap()

        XCTAssertTrue(waitUntilGone(app.staticTexts[question]), "The question closes")
        XCTAssertTrue(waitUntil(fullName(in: app), holds: importedName), "The PDF is read and opens in the editor")
        XCTAssertFalse(element("editor.notice", in: app).exists, "The draft of the PDF has no notice")
        showList(in: app)
        let stored = row(titled: storedTitle, in: app)
        XCTAssertTrue(stored.waitForExistence(timeout: 30), "\(storedTitle) stays in the list")
        XCTAssertFalse(stored.label.contains(editedName), "The discarded edit is not stored: \(stored.label)")
    }

    /// VoiceOver reads the question as it shows: its title; why the text cannot be stored and what importing does, in
    /// one message; and each answer by its words, on a button at least as tall as the smallest tap target.
    @MainActor
    func testQuestionLabelsForVoiceOver() throws {
        let app = try launch()
        asked(in: app)

        XCTAssertTrue(
            app.staticTexts[message].exists, "The message says why the text is not stored, and what importing does")
        for words in [discard, keepEditing] {
            let button = answer(words, in: app)
            XCTAssertTrue(button.exists, "VoiceOver reads the answer as “\(words)”")
            XCTAssertGreaterThanOrEqual(button.frame.height, 43.99, "\(words) is at least 44 points tall")
        }
        keepScreenshot("The question over the editor that cannot store", of: app)
    }

    // MARK: Helpers

    /// Leaves the draft of the PDF opened at launch for Backend Engineer, types at the end of its name, which another
    /// window's save keeps from being stored, and comes back from the background, which hands the window the PDF again:
    /// the question shows over the editor.
    @MainActor
    private func asked(in app: XCUIApplication) {
        let name = fullName(in: app)
        XCTAssertTrue(waitUntil(name, holds: importedName), "The PDF opened at launch is in the editor")
        showList(in: app)
        let row = row(titled: storedTitle, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The list shows \(storedTitle)")
        row.tap()
        XCTAssertTrue(waitUntil(name, holds: storedName), "\(storedTitle) opens in the editor")
        XCTAssertTrue(waitUntil(app.staticTexts["editor.status"], reads: saved), "The CV opens stored")
        app.scrollForm(until: name, named: "The name field")
        // Near the end of the field, past the last word, so that the text goes at its end
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        name.typeText(typed)
        XCTAssertTrue(element("editor.notice", in: app).waitForExistence(timeout: 30), "The text cannot be stored")
        let done = app.buttons["keyboard.done"]
        if done.exists { done.tap() }

        // Back from the background, the window is handed the PDF again, as when another app opens it there
        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(app.staticTexts[question].waitForExistence(timeout: 30), "The question shows over the editor")
        XCTAssertTrue(answer(discard, in: app).exists, "It offers to discard the edits and import")
        XCTAssertTrue(answer(keepEditing, in: app).exists, "It offers to keep editing")
    }

    /// Launches on Backend Engineer, stored, with the other window's save before its first write and the PDF handed to
    /// the window.
    @MainActor
    private func launch() throws -> XCUIApplication {
        let cv = """
            {"schemaVersion":1,"id":"\(identity)","revision":1,\
            "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"\(storedTitle)",\
            "personal":{"fullName":"\(storedName)","professionalTitle":"","location":"","summary":""},\
            "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],\
            "interests":[]}
            """
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage",
            "-PrestoCVNextSeed", try JSONEncoder().encode(["\(identity).cv.json": cv]).base64EncodedString(),
            "-PrestoCVNextOtherWindow", "conflict",
            "-PrestoCVNextOpenedFile", "linkedin",
        ]
        app.launch()
        return app
    }

    /// An answer of the question, by the words VoiceOver reads, as the person finds it.
    private func answer(_ words: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", words)).firstMatch
    }

    private func fullName(in app: XCUIApplication) -> XCUIElement {
        app.textFields["editor.field.fullName"]
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func row(titled title: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "shell.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", title + ", ")).firstMatch
    }

    /// The list, from the editor: a compact screen goes back to it, a regular one shows it beside the editor.
    @MainActor
    private func showList(in app: XCUIApplication) {
        guard app.windows.firstMatch.horizontalSizeClass != .regular else { return }
        let back = app.backButton
        XCTAssertTrue(back.waitForExistence(timeout: 30), "Back shows: the bar holds \(app.barButtonIdentifiers)")
        back.tap()
    }

    @MainActor
    private func waitUntil(_ element: XCUIElement, holds value: String) -> Bool {
        let holds = expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: element)
        return XCTWaiter().wait(for: [holds], timeout: 30) == .completed
    }

    @MainActor
    private func waitUntil(_ element: XCUIElement, reads label: String) -> Bool {
        let reads = expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
        return XCTWaiter().wait(for: [reads], timeout: 30) == .completed
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: 30) == .completed
    }

    /// Keeps a picture of the screen with the result, for the review of where the question stands.
    @MainActor
    private func keepScreenshot(_ name: String, of app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
