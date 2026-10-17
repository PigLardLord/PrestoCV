import XCTest

/// An English CV written on an Italian phone: "Automatic" is the CV's own language, English, and both the editor and the
/// export sheet say so; the export sheet offers its PDF with a button that says what it does.
final class ExportLanguageUITests: XCTestCase {

    private var app: XCUIApplication!

    private let summary = "Sales and operations manager with over twenty years of experience in industrial distribution. "
        + "Built and led teams of up to fifteen people and managed key accounts."

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 300
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(it)", "-AppleLocale", "it_IT", "-PrestoCVUITestsEmptyStorage"]
        app.launch()
        let start = app.buttons["Crea il mio primo CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
    }

    func testAnEnglishCVOnAnItalianPhoneIsExportedInEnglish() throws {
        type("Luca Ferrari\n", into: app.textFields["Nome completo"])
        type("luca.ferrari@example.com\n", into: app.textFields["E-mail"])
        let summaryField = app.textViews.firstMatch
        scrollTo(summaryField)
        type(summary, into: summaryField)
        app.toolbars.buttons["Fine"].tap()

        let automatic = element(showing: "Automatica (English)")
        scrollTo(automatic, down: false)
        XCTAssertTrue(automatic.waitForExistence(timeout: 10), "The document language should say that automatic is English")

        let export = app.buttons["Anteprima ed esportazione"]
        XCTAssertTrue(export.waitForExistence(timeout: 10), "The editor should offer to preview and export")
        export.tap()

        XCTAssertTrue(element(showing: "Titoli in inglese").waitForExistence(timeout: 30),
                      "The export sheet should say that the headings are in English")
        let send = app.buttons["Invia o salva il PDF"]
        XCTAssertTrue(send.waitForExistence(timeout: 10), "The export sheet should have a labelled button for the PDF")
        let sheetBar = app.navigationBars["Esporta CV"]
        XCTAssertTrue(sheetBar.exists, "The export sheet should have its title")
        XCTAssertGreaterThan(send.frame.width, sheetBar.frame.width / 2, "The button should span the sheet, not be an icon in its bar")
        XCTAssertTrue(waitUntil(send, isEnabled: true, timeout: 60), "The button should be ready once the PDF is made")
    }

    // MARK: - Helpers

    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 10), "\(field) should be there to type into")
        field.tap()
        field.typeText(text)
    }

    /// Any element whose label or value is `text`
    private func element(showing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR value == %@", text, text)).firstMatch
    }

    private func scrollTo(_ element: XCUIElement, down: Bool = true) {
        var scrolls = 0
        while !(element.exists && element.isHittable) && scrolls < 8 {
            down ? app.swipeUp() : app.swipeDown()
            scrolls += 1
        }
    }

    private func waitUntil(_ element: XCUIElement, isEnabled: Bool, timeout: TimeInterval) -> Bool {
        let condition = expectation(for: NSPredicate(format: "isEnabled == %@", NSNumber(value: isEnabled)), evaluatedWith: element)
        return XCTWaiter().wait(for: [condition], timeout: timeout) == .completed
    }
}
