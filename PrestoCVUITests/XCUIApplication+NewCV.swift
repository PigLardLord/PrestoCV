import XCTest

extension XCUIApplication {
    /// The line under the title of the editor that says the CV is stored.
    var savedOnThisDevice: XCUIElement {
        descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Saved on this device")).firstMatch
    }

    /// The bars that hold the buttons of a screen: the navigation bar, or the vertical bar of the iPhone Duo, where the
    /// system moves them.
    var bars: XCUIElementQuery {
        let types = [XCUIElement.ElementType.navigationBar, .toolbar].map { NSNumber(value: $0.rawValue) }
        return descendants(matching: .any).matching(NSPredicate(format: "elementType IN %@", types))
    }

    /// The button of a bar named `label`, wherever the system puts it.
    func barButton(_ label: String) -> XCUIElement {
        bars.buttons[label].firstMatch
    }

    /// The Back button of the bar.
    var backButton: XCUIElement {
        barButton("BackButton")
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
        XCTAssertTrue(savedOnThisDevice.waitForExistence(timeout: 10), "The editor should save by itself")
        XCTAssertTrue(backButton.waitForExistence(timeout: 10), "The editor should go back to the list")
        backButton.tap()
        let add = barButton("Add")
        XCTAssertTrue(add.waitForExistence(timeout: 10), "The list should offer to add a CV")
        add.tap()
    }
}
