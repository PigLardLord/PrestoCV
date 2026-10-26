import XCTest

/// The PDF of the export sheet opens full screen: the button over the preview, or a tap on its pages, shows the file that
/// the sheet shares, and Done goes back to the sheet as it was, with the PDF still there to share.
final class ExportFullPDFUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 300
        XCUIDevice.shared.orientation = .portrait
    }

    func testTheButtonAndATapOnThePagesOpenThePDFFullScreenAndDoneGoesBack() throws {
        launch(language: "en", locale: "en_US")
        startACV(named: "Maria Rossi", create: "Create My First CV", nameField: "Full Name", saved: "Saved on this device")
        openTheExportSheet("Preview & export", sendButton: "Send or save PDF")
        let send = app.buttons["Send or save PDF"]
        XCTAssertTrue(waitUntil(send, isEnabled: true, timeout: 60), "The button should be ready once the PDF is made")

        let offer = app.buttons["Show the full PDF, 1 page"]
        XCTAssertTrue(offer.waitForExistence(timeout: 10), "The preview should offer the full PDF with a button that has its page count")
        XCTAssertTrue(offer.isHittable, "The button should be in reach of a finger, a keyboard or a pointer")
        // A frame comes as a float: 44 points can read 43.99999999999997
        XCTAssertGreaterThan(offer.frame.width, 43.99, "The button should be as wide as a finger needs")
        XCTAssertGreaterThan(offer.frame.height, 43.99, "The button should be as tall as a finger needs")

        // The pages themselves, away from the button over their corner
        tapThePages(besides: offer)
        assertTheViewerIsUp()
        done()
        assertTheSheetIsBackWithItsPDF(send: send, offer: offer)

        // The button
        offer.tap()
        assertTheViewerIsUp()
        done()
        assertTheSheetIsBackWithItsPDF(send: send, offer: offer)

        // And once more, to see that nothing was used up
        tapThePages(besides: offer)
        assertTheViewerIsUp()
        done()
        assertTheSheetIsBackWithItsPDF(send: send, offer: offer)
    }

    func testEveryPageOfALongCVIsInTheFullPDF() throws {
        executionTimeAllowance = 900
        launch(language: "en", locale: "en_US")
        startACV(named: "Maria Rossi", create: "Create My First CV", nameField: "Full Name", saved: "Saved on this device")
        // A summary of some thousand words runs over a page; its last word is one that cannot be split over two lines
        let sentence = "Managed a team of fifteen people across three sites and delivered every project on time and on budget. "
        typeTheSummary(String(repeating: sentence, count: 50) + Self.lastWord)
        openTheExportSheet("Preview & export", sendButton: "Send or save PDF")
        let send = app.buttons["Send or save PDF"]
        XCTAssertTrue(waitUntil(send, isEnabled: true, timeout: 120), "The button should be ready once the PDF is made")

        let offer = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "Show the full PDF, ([2-9]|[1-9][0-9]) pages")).firstMatch
        XCTAssertTrue(offer.waitForExistence(timeout: 10), "The preview should offer the full PDF, with the pages that a long CV takes")
        let sayingTheLastWord = elementsSayingTheLastWord

        offer.tap()
        assertTheViewerIsUp()
        var scrolls = 0
        while elementsSayingTheLastWord <= sayingTheLastWord && scrolls < 4 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertGreaterThan(elementsSayingTheLastWord, sayingTheLastWord, "The viewer should give the text of the last page too")
        done()
        assertTheSheetIsBackWithItsPDF(send: send, offer: offer)
    }

    func testTheOfferToOpenThePDFIsInTheLanguageOfThePhone() throws {
        launch(language: "it", locale: "it_IT")
        startACV(named: "Luca Ferrari", create: "Crea il mio primo CV", nameField: "Nome completo", saved: "Salvato su questo dispositivo")
        openTheExportSheet("Anteprima ed esportazione", sendButton: "Invia o salva il PDF")
        let send = app.buttons["Invia o salva il PDF"]
        XCTAssertTrue(waitUntil(send, isEnabled: true, timeout: 60), "The button should be ready once the PDF is made")

        let offer = app.buttons["Mostra il PDF completo, 1 pagina"]
        XCTAssertTrue(offer.waitForExistence(timeout: 10), "The preview should offer the full PDF in Italian, with its page count")
        offer.tap()

        let fine = app.barButton("Fine")
        XCTAssertTrue(fine.waitForExistence(timeout: 10), "The PDF should open full screen, with a way back in Italian")
        fine.tap()
        XCTAssertTrue(waitUntil(send, isEnabled: true, timeout: 5), "The PDF should still be there to share")
    }

    // MARK: - Helpers

    private static let lastWord = "Zxqvlastword"

    private func launch(language: String, locale: String) {
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-PrestoCVUITestsEmptyStorage"]
        app.launch()
    }

    /// Creates the first CV and gives it a name, which is all the PDF needs, and waits for the editor to say that it is
    /// stored (`saved`, in the language of the phone).
    private func startACV(named name: String, create: String, nameField: String, saved: String) {
        let start = app.buttons[create]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
        let field = app.textFields[nameField]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "The editor should have a full name to type into")
        field.tap()
        field.typeText("\(name)\n")
        XCTAssertTrue(element(labelled: saved).waitForExistence(timeout: 10), "The editor should save by itself")
    }

    /// Types `text` as the summary of the CV, which the editor shows below the name, and puts the keyboard away
    private func typeTheSummary(_ text: String) {
        let summary = app.textViews.firstMatch
        var scrolls = 0
        while !(summary.exists && summary.isHittable) && scrolls < 8 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(summary.isHittable, "The editor should have a summary to type into")
        summary.tap()
        summary.typeText(text)
        let keyboardDone = app.toolbars.buttons["Done"]
        XCTAssertTrue(keyboardDone.waitForExistence(timeout: 10), "The keyboard should have a way to be put away")
        keyboardDone.tap()
    }

    private func openTheExportSheet(_ button: String, sendButton: String) {
        let export = app.barButton(button)
        XCTAssertTrue(export.waitForExistence(timeout: 10), "The editor should offer to preview and export")
        export.tap()
        XCTAssertTrue(app.buttons[sendButton].waitForExistence(timeout: 30), "The export sheet should open")
    }

    /// A tap on the pages in the preview, away from the button over their corner
    private func tapThePages(besides offer: XCUIElement) {
        offer.coordinate(withNormalizedOffset: CGVector(dx: -1.5, dy: -2.5)).tap()
    }

    private func assertTheViewerIsUp(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.barButton("Done").waitForExistence(timeout: 10), "The PDF should open full screen, with a way back", file: file, line: line)
        XCTAssertTrue(fileNameBar.exists, "The viewer should be titled with the name of the PDF", file: file, line: line)
        XCTAssertTrue(pagesOfTheViewer.waitForExistence(timeout: 10), "The viewer should give the text of its pages to VoiceOver", file: file, line: line)
    }

    /// Done in the viewer, which is gone when the button is
    private func done(file: StaticString = #filePath, line: UInt = #line) {
        let button = app.barButton("Done")
        button.tap()
        XCTAssertTrue(button.waitForNonExistence(timeout: 10), "The viewer should go away", file: file, line: line)
    }

    private func assertTheSheetIsBackWithItsPDF(send: XCUIElement, offer: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 10), "The sheet should be back under the viewer", file: file, line: line)
        XCTAssertTrue(waitUntil(send, isEnabled: true, timeout: 10), "The PDF should still be there to share", file: file, line: line)
        XCTAssertTrue(offer.waitForExistence(timeout: 10), "The preview should still offer the full PDF", file: file, line: line)
        XCTAssertTrue(pagesOfTheViewer.waitForNonExistence(timeout: 10), "The pages of the viewer should be gone with it", file: file, line: line)
    }

    /// The bar of the viewer, which the name of the PDF titles
    private var fileNameBar: XCUIElement {
        app.navigationBars.matching(NSPredicate(format: "identifier ENDSWITH %@", ".pdf")).firstMatch
    }

    /// The text of the pages of a PDF as PDFKit gives it to assistive technology: it starts with the name of the CV, which
    /// no other text view of the app does
    private var pagesOfThePDF: XCUIElementQuery {
        app.textViews.matching(NSPredicate(format: "value BEGINSWITH %@", "Maria Rossi"))
    }

    /// The text of the pages in the viewer. The pages in the preview under it are listed too, because XCUITest lists what
    /// VoiceOver is kept from (FullPDFViewTests checks that the preview hides them): the viewer's are the second.
    private var pagesOfTheViewer: XCUIElement {
        pagesOfThePDF.element(boundBy: 1)
    }

    /// How many elements say the last word of the summary: the summary in the editor, and the pages of the PDF where
    /// they give their text
    private var elementsSayingTheLastWord: Int {
        app.textViews.matching(NSPredicate(format: "value CONTAINS %@", Self.lastWord)).count
            + app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", Self.lastWord)).count
    }

    /// Any element whose label is `text`
    private func element(labelled text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    private func waitUntil(_ element: XCUIElement, isEnabled: Bool, timeout: TimeInterval) -> Bool {
        let condition = expectation(for: NSPredicate(format: "isEnabled == %@", NSNumber(value: isEnabled)), evaluatedWith: element)
        return XCTWaiter().wait(for: [condition], timeout: timeout) == .completed
    }
}
