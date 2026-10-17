import XCTest

extension XCUIApplication {
    /// The confirmation that the editor shows for a moment after a save.
    var savedConfirmation: XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Saved on this device")).firstMatch
    }

    /// Saves a first CV and opens the "New CV" screen from the "+" of the list.
    func openTheNewCVScreen() {
        let start = buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
        let name = textFields["Full Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The editor should have a full name to type into")
        name.tap()
        name.typeText("Maria Rossi\n")
        buttons["Save"].tap()
        XCTAssertTrue(savedConfirmation.waitForExistence(timeout: 10), "Saving should confirm")
        let done = navigationBars.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "A saved CV should be left with Done")
        done.tap()
        let add = navigationBars.buttons["Add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10), "The list should offer to add a CV")
        add.tap()
    }
}
