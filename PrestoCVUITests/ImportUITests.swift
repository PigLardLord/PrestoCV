import UIKit
import XCTest

/// Bringing a CV the person already has: pasted text, or a PDF, read into a new CV that opens in the editor (#275).
final class ImportUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 300
        app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage",
        ]
        app.launch()
    }

    /// A fixture of the synthetic corpus, from the test bundle.
    private func fixture(_ name: String, _ type: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: type), "\(name).\(type) is in the test bundle")
        return try Data(contentsOf: url)
    }

    /// Opens the import from the first run.
    private func openTheImport() {
        let start = app.buttons["Paste or import a CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first run should offer to paste or import a CV")
        app.scrollTo(start)
        start.tap()
        XCTAssertTrue(app.staticTexts["Bring the CV you already have"].waitForExistence(timeout: 10), "The import screen should open")
    }

    /// The system's paste button of the import screen.
    private var pasteButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == 'Paste'")).firstMatch
    }

    func testAPastedCVOpensStructuredInTheEditorWithWhatToCheck() throws {
        UIPasteboard.general.string = String(decoding: try fixture("chat", "txt"), as: UTF8.self)
        openTheImport()

        XCTAssertTrue(pasteButton.waitForExistence(timeout: 10), "The import screen should offer the system's paste button")
        pasteButton.tap()
        let importText = app.buttons["Import this text"]
        XCTAssertTrue(importText.waitForExistence(timeout: 10))
        add(app.keptScreenshot(named: "Import - pasted text"))
        app.scrollTo(importText)
        importText.tap()

        let name = app.textFields["Full Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The imported CV should open in the editor")
        XCTAssertEqual(name.value as? String, "Jonas Becker")
        XCTAssertEqual(app.textFields["Professional Title"].value as? String, "Pflegefachmann")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Imported from your text'")).firstMatch.exists,
                      "The editor should say the CV was imported and is to be checked")
        add(app.keptScreenshot(named: "Import - editor"))

        let review = app.buttons["What to check"]
        XCTAssertTrue(review.exists, "A language given in words is to check")
        review.tap()
        XCTAssertTrue(app.staticTexts["Englisch — gute Kenntnisse"].waitForExistence(timeout: 10), "The review should list the language to add")
        add(app.keptScreenshot(named: "Import - what to check"))
        app.buttons["Done"].tap()

        // The tab, wherever the device puts the tabs: a tab bar on an iPhone, the bar at the top of an iPad
        app.buttons["Experience"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "value == 'Klinikum Beispiel'")).firstMatch.waitForExistence(timeout: 10),
                      "The first job's employer should be read")
        add(app.keptScreenshot(named: "Import - experience"))
    }

    /// A long pasted CV scrolls inside the box it is pasted in, and the import stays under the box, on the screen. Before,
    /// the box grew with the text and took the import far below it, where a swipe on the text, which moved the text and
    /// not the screen, could not bring it.
    func testALongPastedCVLeavesTheImportOnTheScreen() throws {
        UIPasteboard.general.string = String(decoding: try fixture("chat", "txt"), as: UTF8.self)
        openTheImport()
        XCTAssertTrue(pasteButton.waitForExistence(timeout: 10))
        pasteButton.tap()
        let importText = app.buttons["Import this text"]
        XCTAssertTrue(importText.waitForExistence(timeout: 10))

        XCTAssertLessThanOrEqual(importText.frame.maxY, app.frame.maxY, "The import should stay on the screen, however long the text")
        XCTAssertTrue(importText.isHittable, "The import should take a tap where it is")
    }

    func testAPastedPDFOpensInTheEditor() throws {
        UIPasteboard.general.setData(try fixture("linkedin", "pdf"), forPasteboardType: "com.adobe.pdf")
        openTheImport()

        XCTAssertTrue(pasteButton.waitForExistence(timeout: 10))
        pasteButton.tap()

        let name = app.textFields["Full Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 20), "The PDF should be read and open in the editor")
        XCTAssertEqual(name.value as? String, "Emily Carter")
        XCTAssertEqual(app.textFields["Email"].value as? String, "emily.carter@example.com")
        add(app.keptScreenshot(named: "Import - PDF in the editor"))
    }

    /// The imported CV is stored as it is: Back at once leaves it in the list, and lands on the list, not on the import.
    func testAnImportedCVIsInTheListAfterBack() throws {
        UIPasteboard.general.string = String(decoding: try fixture("chat", "txt"), as: UTF8.self)
        openTheImport()
        XCTAssertTrue(pasteButton.waitForExistence(timeout: 10))
        pasteButton.tap()
        let importText = app.buttons["Import this text"]
        XCTAssertTrue(importText.waitForExistence(timeout: 10))
        app.scrollTo(importText)
        importText.tap()
        XCTAssertTrue(app.textFields["Full Name"].waitForExistence(timeout: 10), "The imported CV should open in the editor")

        XCTAssertTrue(app.backButton.waitForExistence(timeout: 10), "The editor should go back with the Back button")
        app.backButton.tap()

        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Jonas Becker")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The list should show the imported CV")
        XCTAssertFalse(app.staticTexts["Bring the CV you already have"].exists, "Back should land on the list, not on the import")
        XCTAssertEqual(app.alerts.count, 0, "Leaving should not ask anything")
    }

    func testTheNewCVScreenOffersTheImport() throws {
        app.openTheNewCVScreen()

        let card = app.buttons["newcv.import"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The New CV screen should offer to paste or import a CV")
        app.scrollTo(card)
        card.tap()
        XCTAssertTrue(app.staticTexts["Bring the CV you already have"].waitForExistence(timeout: 10))
    }
}
