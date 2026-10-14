import XCTest

/// Moving from one text field of the editor to the next must keep the app responsive.
///
/// On iOS 27 the fields of the editor took the focus from each other in a loop: the main thread ran at 100% CPU
/// as soon as a second field was tapped, and the tap never returned. The fields name their label, so a test finds them by it.
final class EditorFocusUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage"]
        app.launch()
    }

    func testTappingTheNextFieldAfterTypingKeepsTheEditorResponsive() throws {
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()

        let fields: [(label: String, text: String)] = [
            ("Full Name", "Maria Rossi"),
            ("Professional Title", "Senior Nurse"),
            ("Location", "Rome, Italy"),
            ("Email", "maria@example.com"),
            ("Phone", "+39 06 1234567"),
            ("Portfolio URL", "https://maria.example"),
        ]
        for field in fields {
            let element = app.textFields[field.label]
            try focus(element, named: field.label)
            element.typeText(field.text)
        }

        for field in fields {
            let element = app.textFields[field.label]
            XCTAssertEqual(element.value as? String, field.text, "\(field.label) should keep what was typed")
        }
    }

    func testTappingFromFieldToFieldInTurnKeepsTheEditorResponsive() throws {
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()

        // The keyboard changes between these fields (text, e-mail, phone, URL): the case that took the focus in a loop
        let labels = ["Full Name", "Professional Title", "Location", "Email", "Phone", "Portfolio URL"]
        for round in 0..<3 {
            for (index, label) in labels.enumerated() {
                // From the second round on, the first field is back at the top of the form
                try focus(app.textFields[label], named: label, upwards: round > 0 && index == 0)
            }
        }
    }

    /// Scrolls the field into view if needed and taps it; the field has the keyboard focus a moment later.
    /// A tap that the simulator drops is repeated once. A hang is not: the editor never answers, whatever is tapped.
    private func focus(_ element: XCUIElement, named label: String, upwards: Bool = false) throws {
        app.scrollTo(element, upwards: upwards)
        XCTAssertTrue(element.waitForExistence(timeout: 20), "\(label) should be on the screen")
        let started = Date()
        element.tap()
        if !hasKeyboardFocus(element, within: 6) {
            element.tap()
            XCTAssertTrue(hasKeyboardFocus(element, within: 15), "\(label) should take the keyboard focus")
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 40, "Moving to \(label) took far too long: the editor is spinning")
    }

    private func hasKeyboardFocus(_ element: XCUIElement, within seconds: TimeInterval) -> Bool {
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: element)
        return XCTWaiter().wait(for: [focused], timeout: seconds) == .completed
    }
}
