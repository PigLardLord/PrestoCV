import UIKit
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
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage"]
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
        XCTAssertTrue(box(in: app).waitForExistence(timeout: 30), "The import opens")
        return app
    }

    // MARK: Elements

    private func box(in app: XCUIApplication) -> XCUIElement {
        app.textViews["import.text"]
    }

    private func importButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons["import.button"]
    }

    /// The system's paste button, which keeps the identifier the app gives it and shows the system's label
    private func pasteButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons["import.paste"]
    }

    @MainActor
    private func paste(_ text: String, in app: XCUIApplication) {
        UIPasteboard.general.string = text
        let paste = pasteButton(in: app)
        XCTAssertTrue(paste.waitForExistence(timeout: 30))
        paste.tap()
        let pasted = expectation(for: NSPredicate(format: "value BEGINSWITH %@", String(text.prefix(20))), evaluatedWith: box(in: app))
        XCTAssertEqual(XCTWaiter().wait(for: [pasted], timeout: 30), .completed, "The text is pasted in the box")
    }

    /// Drags the import by its margin beside the box (the box takes a drag that starts on it), to show what is below
    /// or what is above.
    @MainActor
    private func drag(_ app: XCUIApplication, showingBelow below: Bool) {
        let window = app.windows.firstMatch
        let margin = box(in: app).frame.minX - 12
        let low = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: margin, dy: window.frame.height * 0.7))
        let high = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: margin, dy: window.frame.height * 0.35))
        (below ? low : high).press(forDuration: 0.05, thenDragTo: below ? high : low, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    /// Scrolls the import in steps until the element can be tapped.
    @MainActor
    private func scroll(_ app: XCUIApplication, until element: XCUIElement, named name: String) {
        for _ in 0..<12 where !element.canBeTapped(in: app) {
            drag(app, showingBelow: element.place(in: app) != .above)
        }
        XCTAssertTrue(element.canBeTapped(in: app), "\(name) comes into view")
    }

    /// Scrolls until a tap target's height of the box lies between a tap target under the bars at the top and seven
    /// tenths of the window, and taps the middle of that part: a tap 24 pt under the bar (iPhone on its side), or near
    /// the bottom edge, reaches the box but gives it no focus.
    @MainActor
    private func focusBox(in app: XCUIApplication, _ way: String) {
        let box = box(in: app)
        let window = app.windows.firstMatch.frame
        let top = (app.navigationBars.allElementsBoundByIndex.map(\.frame.maxY).max() ?? window.minY) + 44
        let band = CGRect(x: window.minX, y: top, width: window.width, height: window.minY + window.height * 0.7 - top)
        for _ in 0..<12 where box.frame.intersection(band).height < 44 {
            drag(app, showingBelow: box.frame.midY > band.maxY)
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
        let box = box(in: app)
        XCTAssertFalse(importButton(in: app).isEnabled, "An empty box has nothing to import")

        box.tap()
        box.typeText("2019 2024 +44")
        XCTAssertFalse(importButton(in: app).isEnabled, "Digits and signs are no CV")
        box.typeText(" Leeds")
        XCTAssertTrue(importButton(in: app).isEnabled, "A letter can start a CV")
    }

    /// The path of the first run: paste, Import, and the draft opens in the editor in place of the import.
    @MainActor
    func testPastedCVOpensInTheEditor() throws {
        let app = try openImport()
        paste(cv, in: app)
        importButton(in: app).tap()

        let name = app.textFields["editor.field.fullName"]
        XCTAssertTrue(name.waitForExistence(timeout: 30), "The draft opens in the editor")
        XCTAssertEqual(name.value as? String, "Ada Lovelace")
        XCTAssertFalse(box(in: app).exists, "The editor takes the import's place")
    }

    /// A text longer than a CV is the one problem a paste can bring: the alert says why, OK closes it, and the text
    /// stays in the box with the keyboard focus, ready for another try.
    @MainActor
    func testABadTextShowsItsMessageAndKeepsTheText() throws {
        let app = try openImport()
        let text = String(repeating: "Analyst at Example Engines\n", count: 4_000)
        paste(text, in: app)
        importButton(in: app).tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 30))
        XCTAssertEqual(alert.label, "Nothing to Import")
        XCTAssertTrue(alert.staticTexts["This text is longer than a CV. Paste only the CV."].exists)
        alert.buttons["OK"].tap()

        XCTAssertTrue(alert.waitForNonExistence(timeout: 30))
        let box = box(in: app)
        XCTAssertEqual((box.value as? String)?.count, text.count, "The text stays")
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: box)
        XCTAssertEqual(XCTWaiter().wait(for: [focused], timeout: 30), .completed, "The box has the keyboard focus again")
    }

    /// Cancel stops the read and leaves the text; Back on a compact screen stops it too, and the first run shows again.
    @MainActor
    func testCancelWhileReading() throws {
        let app = try openImport(holdingTheRead: true)
        paste("Leeds", in: app)
        importButton(in: app).tap()

        let cancel = app.buttons["import.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 30), "The read offers Cancel")
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Reading your CV'")).firstMatch.exists)
        XCTAssertFalse(box(in: app).canBeTapped(in: app), "The layer covers the text")
        XCTAssertGreaterThan(cancel.frame.height, 43.99)
        cancel.tap()

        XCTAssertTrue(cancel.waitForNonExistence(timeout: 30))
        XCTAssertEqual(box(in: app).value as? String, "Leeds")
        XCTAssertTrue(importButton(in: app).isEnabled)
        guard isCompact(app) else { return }
        importButton(in: app).tap()
        XCTAssertTrue(cancel.waitForExistence(timeout: 30))
        app.backButton.tap()
        XCTAssertTrue(app.buttons["start.import"].waitForExistence(timeout: 30), "Back leads to the ways to start")
        XCTAssertFalse(cancel.exists)
    }

    /// A long CV scrolls inside the box, which keeps its height and place, and Import stays in reach under it.
    @MainActor
    func testLongTextScrollsInsideItsBox() throws {
        let app = try openImport()
        let box = box(in: app)
        let before = box.frame
        paste((1...150).map { "Line \($0) of a long CV" }.joined(separator: "\n"), in: app)

        XCTAssertEqual(box.frame.height, before.height, accuracy: 1, "The box keeps its height")
        XCTAssertEqual(box.frame.minY, before.minY, accuracy: 1, "The page does not move")
        XCTAssertTrue(importButton(in: app).canBeTapped(in: app), "Import stays in reach")
    }

    /// At the largest text size, upright and on its side, paste, Import and the keyboard's Done can be reached, and
    /// each is at least as tall as the smallest tap target.
    @MainActor
    func testImportAtTheLargestTextSize() throws {
        let app = try openImport(largestText: true)
        paste(cv, in: app)
        checkReach(in: app, "upright")
        guard try app.turnsToLandscape() else { return XCTFail("The import turns with the device") }
        checkReach(in: app, "on its side")
    }

    @MainActor
    private func checkReach(in app: XCUIApplication, _ way: String) {
        for (element, name) in [(pasteButton(in: app), "Paste"), (importButton(in: app), "Import")] {
            scroll(app, until: element, named: "\(name), \(way)")
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

        XCTAssertEqual(box(in: app).label, "Your CV as text")
        XCTAssertFalse(app.staticTexts["Paste or type your CV here"].exists, "The placeholder is for the eye")
        XCTAssertEqual(pasteButton(in: app).label, "Paste")
        XCTAssertEqual(importButton(in: app).label, "Import")
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
        paste(cv, in: app)
        importButton(in: app).tap()
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
        XCTAssertFalse(box(in: app).exists, "Back leads to the list, not to the import")
    }
}
