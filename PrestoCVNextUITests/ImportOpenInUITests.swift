import XCTest

/// A PDF opened in the app from another app (#404, 5-13d): the import shows in place of what was open and reads it, as
/// the person's own way to the import does, and a CV that was open is stored with what the person typed. The PDF is the
/// synthetic corpus's (`PrestoCVCore/Tests/ImportFixtures`), an invented person's CV with its text.
///
/// A UI test cannot open a file in the app from Files or Mail, which run in other processes: a Debug build launched with
/// `-PrestoCVNextOpenedFile` is handed the PDF of its bundle each time its window becomes active, as the system hands it
/// a file another app opened there. That the app takes PDFs, as a copy, is checked on its Info.plist by the source checks.
final class ImportOpenInUITests: RuntimeIssueFailingTestCase {
    private let identity = "6C2E4A10-3B5D-4F7E-9A81-C2D3E4F50617"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The tests that run next start upright, also after a test that turned the device stopped on a failure.
    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: Launching

    /// Launches with the PDF handed to the window, on one stored CV, or on an empty store: a first run.
    @MainActor
    private func launch(seeded: Bool, holdingTheRead: Bool) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage",
            "-PrestoCVNextOpenedFile", "linkedin",
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
        app.launch()
        return app
    }

    // MARK: Elements and waiting

    private func fullName(in app: XCUIApplication) -> XCUIElement {
        app.textFields["editor.field.fullName"]
    }

    private func rows(of app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "shell.row")
    }

    private func isCompact(_ app: XCUIApplication) -> Bool {
        app.windows.firstMatch.horizontalSizeClass != .regular
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

    // MARK: Tests

    /// A PDF opened beside the list is read at once and opens in the editor as the CV it holds.
    @MainActor
    func testOpenedPDFIsReadAndOpensTheEditor() throws {
        let app = try launch(seeded: true, holdingTheRead: false)

        let name = fullName(in: app)
        XCTAssertTrue(name.waitForExistence(timeout: 30), "The PDF is read and opens in the editor")
        XCTAssertEqual(name.value as? String, "Emily Carter")
        XCTAssertFalse(app.importBox.exists, "The editor takes the import's place")
    }

    /// A PDF opened over a CV being edited leaves it, stored with what the person typed, and opens in its place.
    @MainActor
    func testOpenedPDFOverAnEditorKeepsTheEditedText() throws {
        let app = try launch(seeded: true, holdingTheRead: false)
        let name = fullName(in: app)
        XCTAssertTrue(waitUntil(name, holds: "Emily Carter"), "The PDF opened at launch is in the editor")
        app.scrollForm(until: name, named: "The name field")
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        name.typeText(" Lowe")
        XCTAssertTrue(waitUntil(app.staticTexts["editor.status"], reads: "Saved on this device"),
                      app.staticTexts["editor.status"].label)

        // Back from the background, the window is handed the PDF again, as when another app opens it there
        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(waitUntil(name, holds: "Emily Carter"), "The PDF opens in a new editor, in place of the edited CV")
        if isCompact(app) {
            app.backButton.tap()
        }
        let edited = rows(of: app).matching(NSPredicate(format: "label CONTAINS 'Emily Carter Lowe'")).firstMatch
        XCTAssertTrue(edited.waitForExistence(timeout: 30), "The CV that was open is stored with what was typed")
    }

    /// A PDF opened on the first run shows the import in place of the ways to start, reading it, with its Cancel.
    @MainActor
    func testOpenedPDFOnTheFirstRun() throws {
        let app = try launch(seeded: false, holdingTheRead: true)

        let cancel = app.buttons["import.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 30), "The PDF is read at once, with Cancel")
        XCTAssertTrue(app.importBox.exists, "The import shows")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "firstRun.title").firstMatch.exists,
                       "The import takes the place of the ways to start")
    }
}
