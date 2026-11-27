import XCTest

/// The import of a pasted CV: the first run and "+" lead to it, Import waits for a letter, a read can be cancelled, a
/// problem shows in an alert that keeps the text, and a good read opens the draft in the editor, which Back stores in
/// the list. The texts come through the system's pasteboard and paste button, as from another app.
final class ImportPasteUITests: RuntimeIssueFailingTestCase {
    private let identity = "4B1D2C3E-5F60-4718-89A0-B1C2D3E4F506"

    /// A short CV, as a person copies it from a document
    private let cv = """
        Ada Lovelace
        ada@example.com

        Experience
        Analyst, Example Engines, 2019 – 2024
        Wrote the first programs for the engine.
        """

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The tests that run next start upright, also after a test that turned the device stopped on a failure.
    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: Launching

    /// Launches on an empty store, or on one stored CV, and opens the import from the first run, or from "+".
    @MainActor
    private func openImport(seeded: Bool = false, holdingTheRead: Bool = false,
                            largestText: Bool = false) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage", "-PrestoCVNextReadyDesigns",
        ]
        if seeded {
            let cv = """
            {"schemaVersion":1,"id":"\(identity)","revision":1,
             "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"Site Electrician",
             "personal":{"fullName":"Tomas Verlaine","professionalTitle":"","location":"","summary":""},
             "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],"interests":[]}
            """
            app.launchArguments += ["-PrestoCVNextSeed", try JSONEncoder().encode(["\(identity).cv.json": cv]).base64EncodedString()]
        }
        if holdingTheRead {
            app.launchArguments += ["-PrestoCVNextHoldImport"]
        }
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        if seeded {
            let add = app.buttons["shell.add"]
            XCTAssertTrue(add.waitForExistence(timeout: 30))
            add.tap()
        }
        let start = app.buttons["start.import"]
        XCTAssertTrue(start.waitForExistence(timeout: 30))
        start.tap()
        XCTAssertTrue(app.importBox.waitForExistence(timeout: 30), "The import opens")
        return app
    }

    // MARK: Elements

    /// Scrolls until a tap target's height of the box lies between a tap target under the bars at the top and seven
    /// tenths of the window, and taps the middle of that part: a tap 24 pt under the bar (iPhone on its side), or near
    /// the bottom edge, reaches the box but gives it no focus.
    @MainActor
    private func focusBox(in app: XCUIApplication, _ way: String) {
        let box = app.importBox
        let window = app.windows.firstMatch.frame
        let top = (app.navigationBars.allElementsBoundByIndex.map(\.frame.maxY).max() ?? window.minY) + 44
        let band = CGRect(x: window.minX, y: top, width: window.width, height: window.minY + window.height * 0.7 - top)
        for _ in 0..<12 where box.frame.intersection(band).height < 44 {
            // A null frame is a box scrolled away above: XCUITest clips a text view's frame to the screen
            app.dragImport(showingBelow: !box.frame.isNull && box.frame.midY > band.maxY)
        }
        let part = box.frame.intersection(band)
        XCTAssertGreaterThanOrEqual(part.height, 44, "The box, \(way), comes into view")
        box.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: (part.midY - box.frame.minY) / box.frame.height)).tap()
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: box)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 30), .completed, "The box takes the focus, \(way)")
    }

    private func isCompact(_ app: XCUIApplication) -> Bool {
        app.windows.firstMatch.horizontalSizeClass != .regular
    }

    // MARK: Tests

    @MainActor
    func testImportIsOffUntilThereIsALetter() throws {
        let app = try openImport()
        let box = app.importBox
        XCTAssertFalse(app.importButton.isEnabled, "An empty box has nothing to import")

        box.tap()
        box.typeText("2019 2024 +44")
        XCTAssertFalse(app.importButton.isEnabled, "Digits and signs are no CV")
        box.typeText(" Leeds")
        XCTAssertTrue(app.importButton.isEnabled, "A letter can start a CV")
    }

    /// The path of the first run: paste, Import, and the draft opens in the editor in place of the import.
    @MainActor
    func testPastedCVOpensInTheEditor() throws {
        let app = try openImport()
        app.pasteInImport(cv)
        app.importButton.tap()

        let name = app.textFields["editor.field.fullName"]
        XCTAssertTrue(name.waitForExistence(timeout: 30), "The draft opens in the editor")
        XCTAssertEqual(name.value as? String, "Ada Lovelace")
        XCTAssertFalse(app.importBox.exists, "The editor takes the import's place")
    }

    /// A text longer than a CV is the one problem a paste can bring: the alert says why, OK closes it, and the text
    /// stays in the box with the keyboard focus, ready for another try.
    @MainActor
    func testABadTextShowsItsMessageAndKeepsTheText() throws {
        let app = try openImport()
        let text = String(repeating: "Analyst at Example Engines\n", count: 4_000)
        app.pasteInImport(text)
        app.importButton.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 30))
        XCTAssertEqual(alert.label, "Nothing to Import")
        XCTAssertTrue(alert.staticTexts["This is longer than a CV. Paste only the CV, or choose a smaller PDF."].exists)
        alert.buttons["OK"].tap()

        XCTAssertTrue(alert.waitForNonExistence(timeout: 30))
        let box = app.importBox
        XCTAssertEqual((box.value as? String)?.count, text.count, "The text stays")
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: box)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 30), .completed, "The box has the keyboard focus again")
    }

    /// Cancel stops the read and leaves the text; Back on a compact screen stops it too, and the first run shows again.
    @MainActor
    func testCancelWhileReading() throws {
        let app = try openImport(holdingTheRead: true)
        app.pasteInImport("Leeds")
        app.importButton.tap()

        let cancel = app.buttons["import.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 30), "The read offers Cancel")
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Reading your CV'")).firstMatch.exists)
        XCTAssertFalse(app.importBox.canBeTapped(in: app), "The layer covers the text")
        XCTAssertGreaterThan(cancel.frame.height, 43.99)
        cancel.tap()

        XCTAssertTrue(cancel.waitForNonExistence(timeout: 30))
        XCTAssertEqual(app.importBox.value as? String, "Leeds")
        XCTAssertTrue(app.importButton.isEnabled)
        guard isCompact(app) else { return }
        app.importButton.tap()
        XCTAssertTrue(cancel.waitForExistence(timeout: 30))
        app.backButton.tap()
        XCTAssertTrue(app.buttons["start.import"].waitForExistence(timeout: 30), "Back leads to the ways to start")
        XCTAssertFalse(cancel.exists)
    }

    /// A long CV scrolls inside the box, which keeps its height and place, and Import stays in reach under it.
    @MainActor
    func testLongTextScrollsInsideItsBox() throws {
        let app = try openImport()
        let box = app.importBox
        let before = box.frame
        app.pasteInImport((1...150).map { "Line \($0) of a long CV" }.joined(separator: "\n"))

        XCTAssertEqual(box.frame.height, before.height, accuracy: 1, "The box keeps its height")
        XCTAssertEqual(box.frame.minY, before.minY, accuracy: 1, "The page does not move")
        XCTAssertTrue(app.importButton.canBeTapped(in: app), "Import stays in reach")
    }

    /// At the largest text size, upright and on its side, paste, Import and the keyboard's Done can be reached, and
    /// each is at least as tall as the smallest tap target.
    @MainActor
    func testImportAtTheLargestTextSize() throws {
        let app = try openImport(largestText: true)
        app.pasteInImport(cv)
        checkReach(in: app, "upright")
        guard try app.turnsToLandscape() else { return XCTFail("The import turns with the device") }
        checkReach(in: app, "on its side")
    }

    @MainActor
    private func checkReach(in app: XCUIApplication, _ way: String) {
        for (element, name) in [(app.importPaste, "Paste"), (app.importButton, "Import")] {
            app.scrollImport(until: element, named: "\(name), \(way)")
            XCTAssertGreaterThan(element.frame.height, 43.99, "\(name), \(way)")
        }
        focusBox(in: app, way)
        let done = app.buttons["keyboard.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 30), "Done, \(way)")
        XCTAssertTrue(done.canBeTapped(in: app), "Done, \(way)")
        XCTAssertGreaterThan(done.frame.height, 43.99, "Done, \(way)")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 30), "Done, \(way)")
    }

    /// The box is named for VoiceOver, the placeholder is for the eye only, and VoiceOver reads the screen in the order
    /// it shows: title, box, paste, Import.
    @MainActor
    func testImportLabelsForVoiceOver() throws {
        let app = try openImport()

        XCTAssertEqual(app.importBox.label, "Your CV as text")
        XCTAssertFalse(app.staticTexts["Paste or type your CV here"].exists, "The placeholder is for the eye")
        XCTAssertEqual(app.importPaste.label, "Paste")
        XCTAssertEqual(app.importButton.label, "Import")
        let read = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier IN %@", ["import.title", "import.text", "import.paste", "import.button"]))
            .allElementsBoundByIndex.map(\.identifier)
        let order = read.reduce(into: [String]()) { order, id in if !order.contains(id) { order.append(id) } }
        XCTAssertEqual(order, ["import.title", "import.text", "import.paste", "import.button"])
    }

    /// From "+" beside a stored CV: the imported draft opens, and once left it is stored, and Back leads to the list,
    /// not to the import.
    @MainActor
    func testImportedCVIsInTheListAfterBack() throws {
        let app = try openImport(seeded: true)
        app.pasteInImport(cv)
        app.importButton.tap()
        XCTAssertTrue(app.textFields["editor.field.fullName"].waitForExistence(timeout: 30), "The draft opens")

        let rows = app.descendants(matching: .any).matching(identifier: "shell.row")
        if isCompact(app) {
            app.backButton.tap()
        } else {
            rows.matching(NSPredicate(format: "label BEGINSWITH 'Site Electrician'")).firstMatch.tap()
        }
        let imported = rows.matching(NSPredicate(format: "label CONTAINS 'Ada Lovelace'")).firstMatch
        XCTAssertTrue(imported.waitForExistence(timeout: 30), "The draft is stored once left")
        XCTAssertEqual(rows.count, 2)
        XCTAssertFalse(app.importBox.exists, "Back leads to the list, not to the import")
    }
}
