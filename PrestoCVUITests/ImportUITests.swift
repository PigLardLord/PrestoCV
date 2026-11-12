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

    /// A long pasted CV scrolls inside the box it is pasted in, which keeps its height, and the import under the box can
    /// be scrolled to. Before, the box grew with the text and took the import far below it, where a swipe on the text,
    /// which moved the text and not the screen, could not bring it.
    func testALongPastedCVScrollsInsideItsBox() throws {
        UIPasteboard.general.string = String(decoding: try fixture("chat", "txt"), as: UTF8.self)
        openTheImport()
        let box = app.textViews["import.text"]
        XCTAssertTrue(box.waitForExistence(timeout: 10), "The import screen should have a box to paste in")
        let emptyHeight = box.frame.height
        XCTAssertTrue(pasteButton.waitForExistence(timeout: 10))
        pasteButton.tap()
        let pasted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS 'Jonas Becker'"), object: box)
        XCTAssertEqual(XCTWaiter.wait(for: [pasted], timeout: 10), .completed, "The CV should be pasted in the box")

        XCTAssertEqual(box.frame.height, emptyHeight, accuracy: 1, "The box should keep its height, and the CV scroll inside it")
        app.scrollTo(app.buttons["Import this text"])
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

    /// A CV with sections the CV has no field for: the notice names them, the review shows their text under their headings,
    /// and the notice stays with the CV, when it is opened again, until the person dismisses it (#452).
    func testSectionsNotImportedAreNamedAndTheNoticeStaysUntilDismissed() throws {
        UIPasteboard.general.string = """
        # Tobias Renn
        **Mobile Developer · Swift and Kotlin**
        Leipzig, Germany · tobias.renn@example.com · +49 170 0000202
        EU citizen · available from March 2026

        ## Experience
        **Senior Developer** | Kestrel Cloud | Hamburg | 08/2019 – today
        - Built the offline sync of the field app

        ## OWN VENTURES
        **Tidepool Notes** | 2021 – today
        - A note app for divers
        **Harbor Timer** | 2018 – 2020
        - A tide timer for sailors

        ## STUDIES AND CERTIFICATES
        2010 – 2014: BSc Computer Science, University of Lucca
        """
        openTheImport()
        XCTAssertTrue(pasteButton.waitForExistence(timeout: 10))
        pasteButton.tap()
        let importText = app.buttons["Import this text"]
        XCTAssertTrue(importText.waitForExistence(timeout: 10))
        app.scrollTo(importText)
        importText.tap()
        XCTAssertTrue(app.textFields["Full Name"].waitForExistence(timeout: 10), "The imported CV should open in the editor")

        let notice = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Imported from your text'")).firstMatch
        XCTAssertTrue(notice.exists, "The editor should say the CV was imported")
        XCTAssertTrue(notice.label.contains("Sections not imported: OWN VENTURES, STUDIES AND CERTIFICATES."),
                      "The notice should name the sections left out: \(notice.label)")
        add(app.keptScreenshot(named: "Import - sections not imported"))

        app.buttons["What to check"].tap()
        let sectionHeader = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH[c] 'Not imported from' AND label CONTAINS[c] 'OWN VENTURES'")).firstMatch
        XCTAssertTrue(sectionHeader.waitForExistence(timeout: 10), "The review should show the text of a section under its heading")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ==[c] 'Not imported from the top of the CV'")).firstMatch.exists,
                      "The review should show the lines left out of the top of the CV apart")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'A note app for divers'")).firstMatch.exists,
                      "The review should show the section's own text")
        add(app.keptScreenshot(named: "Import - text not imported by section"))
        app.buttons["Done"].tap()

        // Opened again from the list, the CV still has its notice
        XCTAssertTrue(app.backButton.waitForExistence(timeout: 10))
        app.backButton.tap()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Tobias Renn")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The list should show the imported CV")
        row.tap()
        XCTAssertTrue(app.textFields["Full Name"].waitForExistence(timeout: 10))
        XCTAssertTrue(notice.waitForExistence(timeout: 10), "The notice should stay with the CV when it is opened again")

        // Dismissing asks first; Cancel keeps the notice
        let dismiss = app.buttons["editor.notice.dismiss"]
        XCTAssertTrue(dismiss.exists, "The import's notice should offer to dismiss it")
        dismiss.tap()
        let question = app.alerts["Dismiss the notice?"]
        XCTAssertTrue(question.waitForExistence(timeout: 10), "Dismissing should ask first, as the text not imported goes with it")
        add(app.keptScreenshot(named: "Import - dismiss the notice"))
        question.buttons["Cancel"].tap()
        XCTAssertTrue(notice.exists, "Cancel should keep the notice")

        dismiss.tap()
        XCTAssertTrue(question.waitForExistence(timeout: 10))
        question.buttons["Dismiss"].tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: notice)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 10), .completed, "Dismiss should take the notice away")

        // Opened again, the CV has no notice any more
        app.backButton.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.textFields["Full Name"].waitForExistence(timeout: 10))
        XCTAssertFalse(notice.exists, "A dismissed notice should not come back")
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
