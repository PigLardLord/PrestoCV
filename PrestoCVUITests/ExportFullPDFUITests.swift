import XCTest

/// The PDF of the export sheet opens full screen: a tap on the preview shows the file that the button shares, and Done
/// goes back to the sheet as it was, with the PDF still there to share.
final class ExportFullPDFUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 300
        XCUIDevice.shared.orientation = .portrait
    }

    func testThePreviewOpensThePDFFullScreenAndDoneGoesBack() throws {
        launch(language: "en", locale: "en_US")
        startACV(named: "Maria Rossi", create: "Create My First CV", nameField: "Full Name", saved: "Saved on this device")
        openTheExportSheet("Preview & export", sendButton: "Send or save PDF")
        let send = app.buttons["Send or save PDF"]
        XCTAssertTrue(waitUntil(send, isEnabled: true, timeout: 60), "The button should be ready once the PDF is made")

        let preview = element(labelled: "Show the full PDF, 1 page")
        XCTAssertTrue(preview.waitForExistence(timeout: 10), "The preview should offer the full PDF, with its page count")
        preview.tap()

        let done = app.barButton("Done")
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The PDF should open full screen, with a way back")
        XCTAssertTrue(fileNameBar.exists, "The viewer should be titled with the name of the PDF")
        done.tap()

        XCTAssertTrue(app.buttons["Cancel"].firstMatch.waitForExistence(timeout: 10), "The sheet should be back under the viewer")
        XCTAssertTrue(waitUntil(send, isEnabled: true, timeout: 5), "The PDF should still be there to share")
        XCTAssertTrue(preview.exists, "The preview should still offer the full PDF")

        preview.tap()
        XCTAssertTrue(app.barButton("Done").waitForExistence(timeout: 10), "The PDF should open again")
        app.barButton("Done").tap()
        XCTAssertTrue(waitUntil(send, isEnabled: true, timeout: 5), "The PDF should still be there to share")
    }

    func testTheOfferToOpenThePDFIsInTheLanguageOfThePhone() throws {
        launch(language: "it", locale: "it_IT")
        startACV(named: "Luca Ferrari", create: "Crea il mio primo CV", nameField: "Nome completo", saved: "Salvato su questo dispositivo")
        openTheExportSheet("Anteprima ed esportazione", sendButton: "Invia o salva il PDF")
        let send = app.buttons["Invia o salva il PDF"]
        XCTAssertTrue(waitUntil(send, isEnabled: true, timeout: 60), "The button should be ready once the PDF is made")

        let preview = element(labelled: "Mostra il PDF completo, 1 pagina")
        XCTAssertTrue(preview.waitForExistence(timeout: 10), "The preview should offer the full PDF in Italian, with its page count")
        preview.tap()

        let done = app.barButton("Fine")
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The PDF should open full screen, with a way back in Italian")
        done.tap()
        XCTAssertTrue(waitUntil(send, isEnabled: true, timeout: 5), "The PDF should still be there to share")
    }

    // MARK: - Helpers

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

    private func openTheExportSheet(_ button: String, sendButton: String) {
        let export = app.barButton(button)
        XCTAssertTrue(export.waitForExistence(timeout: 10), "The editor should offer to preview and export")
        export.tap()
        XCTAssertTrue(app.buttons[sendButton].waitForExistence(timeout: 30), "The export sheet should open")
    }

    /// The bar of the viewer, which the name of the PDF titles
    private var fileNameBar: XCUIElement {
        app.navigationBars.matching(NSPredicate(format: "identifier ENDSWITH %@", ".pdf")).firstMatch
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
