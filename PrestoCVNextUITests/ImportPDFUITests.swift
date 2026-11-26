import UIKit
import XCTest

/// The import of a PDF (#404, 5-13c): a PDF copied in Files is pasted with the system's paste button and opens in the
/// editor, a PDF with no text says it may be a scan, "Choose a PDF" opens the system's picker of files, and the text in
/// the box stays through all of it. The PDFs are the synthetic corpus's (`PrestoCVCore/Tests/ImportFixtures`): an
/// invented person's CV with its text, and a page with no text.
///
/// A UI test cannot pick a file in the system's picker, which runs in another process: it only opens and cancels it.
/// Reading a picked file is covered by `ImportFileTests` and the file adapter's tests. XCUITest shows neither the
/// header trait nor a hint, so the PDF's title is found by its words and its place.
final class ImportPDFUITests: RuntimeIssueFailingTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The tests that run next start upright, also after a test that turned the device stopped on a failure.
    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: Pasting a PDF

    /// A PDF pasted opens in the editor as the CV it holds, in place of the import.
    @MainActor
    func testPastedPDFOpensInTheEditor() throws {
        let app = openImport()
        try pastePDF("en-emily/linkedin", in: app)

        let name = app.textFields["editor.field.fullName"]
        XCTAssertTrue(name.waitForExistence(timeout: 30), "The PDF is read and opens in the editor")
        XCTAssertEqual(name.value as? String, "Emily Carter")
        XCTAssertFalse(app.importBox.exists, "The editor takes the import's place")
    }

    /// A PDF with no text shows why in the alert, and OK leads back to the screen with the text of the box as it was.
    @MainActor
    func testPDFWithoutTextShowsTheScanMessage() throws {
        let app = openImport()
        app.pasteInImport("Leeds")
        try pastePDF("scan/scan", in: app)

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 30))
        XCTAssertEqual(alert.label, "Nothing to Import")
        XCTAssertTrue(alert.staticTexts[
            "This PDF has no text to read. It may be a scan or a photo. Paste the text of your CV instead."].exists)
        alert.buttons["OK"].tap()

        XCTAssertTrue(alert.waitForNonExistence(timeout: 30))
        XCTAssertEqual(app.importBox.value as? String, "Leeds", "The text stays")
    }

    /// A PDF pasted while the box holds text is read in its place, and the text stays: Cancel leaves the box as it was.
    @MainActor
    func testPastedPDFKeepsTheTypedText() throws {
        let app = openImport(holdingTheRead: true)
        app.pasteInImport("Leeds")
        try pastePDF("en-emily/linkedin", in: app)

        let cancel = app.buttons["import.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 30), "The PDF is read at once, with Cancel")
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 30))
        XCTAssertEqual(app.importBox.value as? String, "Leeds", "The text stays")
        XCTAssertFalse(app.alerts.firstMatch.exists, "A cancelled read is no problem")
    }

    // MARK: Choosing a PDF

    /// "Choose a PDF" opens the system's picker of files, and its Cancel leads back to the screen as it was: the same
    /// text, no read and no alert.
    @MainActor
    func testChoosePDFOpensTheFilesPicker() throws {
        let app = openImport()
        app.pasteInImport("Leeds")
        let choose = app.importPDFButton
        app.scrollImport(until: choose, named: "Choose a PDF")
        choose.tap()

        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 30), "The picker of files opens")
        XCTAssertFalse(choose.canBeTapped(in: app), "The picker covers the screen")
        cancel.tap()

        XCTAssertTrue(cancel.waitForNonExistence(timeout: 30), "Cancel closes the picker")
        XCTAssertTrue(choose.canBeTapped(in: app), "The screen is back")
        XCTAssertEqual(app.importBox.value as? String, "Leeds", "The text stays")
        XCTAssertFalse(app.buttons["import.cancel"].exists, "Nothing is read")
        XCTAssertFalse(app.alerts.firstMatch.exists, "Cancel is no problem")
    }

    // MARK: Reach and VoiceOver

    /// At the largest text size, upright and on its side, "Choose a PDF" can be reached and is at least as tall as the
    /// smallest tap target.
    @MainActor
    func testPDFButtonIsReachableAtTheLargestTextSize() throws {
        let app = openImport(largestText: true)
        checkReach(in: app, "upright")
        guard try app.turnsToLandscape() else { return XCTFail("The import turns with the device") }
        checkReach(in: app, "on its side")
    }

    @MainActor
    private func checkReach(in app: XCUIApplication, _ way: String) {
        let choose = app.importPDFButton
        app.scrollImport(until: choose, named: "Choose a PDF, \(way)")
        XCTAssertGreaterThan(choose.frame.height, 43.99, "Choose a PDF, \(way)")
    }

    /// The PDF has its own title, its description and its button, read in that order after the paste button and before
    /// Import.
    @MainActor
    func testPDFSectionLabelsForVoiceOver() throws {
        let app = openImport()

        XCTAssertEqual(app.staticTexts["import.pdf.title"].label, "Or a PDF")
        XCTAssertEqual(app.staticTexts["import.pdf.description"].label,
                       "A PDF that contains text, such as one saved from a word processor. "
                       + "A scan or a photo has no text to read.")
        XCTAssertEqual(app.importPDFButton.label, "Choose a PDF")
        let identifiers = ["import.paste", "import.pdf.title", "import.pdf.description", "import.pdf.button",
                           "import.button"]
        let read = app.descendants(matching: .any).matching(NSPredicate(format: "identifier IN %@", identifiers))
            .allElementsBoundByIndex.map(\.identifier)
        let order = read.reduce(into: [String]()) { order, id in if !order.contains(id) { order.append(id) } }
        XCTAssertEqual(order, identifiers)
    }

    // MARK: Helpers

    /// Launches on an empty store and opens the import from the first run.
    @MainActor
    private func openImport(holdingTheRead: Bool = false, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage", "-PrestoCVNextReadyDesigns",
        ]
        if holdingTheRead {
            app.launchArguments += ["-PrestoCVNextHoldImport"]
        }
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        let start = app.buttons["start.import"]
        XCTAssertTrue(start.waitForExistence(timeout: 30), "The first run offers the import")
        start.tap()
        XCTAssertTrue(app.importBox.waitForExistence(timeout: 30), "The import opens")
        return app
    }

    /// Puts a PDF of the corpus on the system's pasteboard, as Files copies one, and pastes it with the paste button.
    @MainActor
    private func pastePDF(_ name: String, in app: XCUIApplication) throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: (name as NSString).lastPathComponent,
                                                           withExtension: "pdf"), "\(name).pdf is in the test bundle")
        UIPasteboard.general.setData(try Data(contentsOf: url), forPasteboardType: "com.adobe.pdf")
        let paste = app.importPaste
        app.scrollImport(until: paste, named: "Paste")
        paste.tap()
    }
}

private extension XCUIApplication {
    /// The button that opens the system's picker of files for a PDF.
    var importPDFButton: XCUIElement {
        buttons["import.pdf.button"]
    }
}
