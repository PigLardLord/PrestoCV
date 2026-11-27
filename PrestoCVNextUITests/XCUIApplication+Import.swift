import UIKit
import XCTest

/// The import screen as a person uses it: the box for the CV's text, the system's paste button and Import, and the
/// drags that bring each into reach where the screen is short of room.
extension XCUIApplication {
    /// The box for the CV's text.
    var importBox: XCUIElement {
        textViews["import.text"]
    }

    /// The system's paste button, which keeps the identifier the app gives it and shows the system's label.
    var importPaste: XCUIElement {
        buttons["import.paste"]
    }

    var importButton: XCUIElement {
        buttons["import.button"]
    }

    /// Puts the text on the system's pasteboard, as another app does, and pastes it with the paste button.
    @MainActor
    func pasteInImport(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        UIPasteboard.general.string = text
        let paste = importPaste
        XCTAssertTrue(paste.waitForExistence(timeout: 30), "The import offers Paste", file: file, line: line)
        paste.tap()
        let pasted = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value BEGINSWITH %@", String(text.prefix(20))), object: importBox)
        XCTAssertEqual(XCTWaiter().wait(for: [pasted], timeout: 30), .completed, "The text is pasted in the box",
                       file: file, line: line)
    }

    /// Drags the import by its margin, left of the column (the box takes a drag that starts on it), to show what is
    /// below or what is above. The column's edge is read from Import, which spans the column: the box's own frame is
    /// null once it is scrolled away above (XCUITest clips a text view's frame to the screen), and the scroll's frame
    /// is no guide, since it lies under the sidebar on an iPad and under the side's safe area on an iPhone on its side.
    @MainActor
    func dragImport(showingBelow below: Bool) {
        let window = windows.firstMatch
        let margin = importButton.frame.minX - 12
        let origin = window.coordinate(withNormalizedOffset: .zero)
        let low = origin.withOffset(CGVector(dx: margin, dy: window.frame.height * 0.7))
        let high = origin.withOffset(CGVector(dx: margin, dy: window.frame.height * 0.35))
        (below ? low : high).press(forDuration: 0.05, thenDragTo: below ? high : low, withVelocity: .slow,
                                   thenHoldForDuration: 0.2)
    }

    /// Scrolls the import in steps until the element can be tapped.
    @MainActor
    func scrollImport(until element: XCUIElement, named name: String, file: StaticString = #filePath,
                      line: UInt = #line) {
        for _ in 0..<12 where !element.canBeTapped(in: self) {
            dragImport(showingBelow: element.place(in: self) != .above)
        }
        XCTAssertTrue(element.canBeTapped(in: self), "\(name) comes into view", file: file, line: line)
    }
}
