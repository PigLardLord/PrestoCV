import XCTest

/// Waiting on an element's state, with the one timeout every UI test uses.
extension XCUIElement {

    /// Whether the element's `property` equals `value` within thirty seconds.
    @MainActor
    private func waitUntil(_ property: String, is value: String) -> Bool {
        let holds = XCTNSPredicateExpectation(predicate: NSPredicate(format: "\(property) == %@", value), object: self)
        return XCTWaiter().wait(for: [holds], timeout: 30) == .completed
    }

    @MainActor
    func waitUntil(reads label: String) -> Bool { waitUntil("label", is: label) }

    @MainActor
    func waitUntil(holds value: String) -> Bool { waitUntil("value", is: value) }

    @MainActor
    func waitUntilGone() -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: self)
        return XCTWaiter().wait(for: [gone], timeout: 30) == .completed
    }

    /// Whether the element takes the keyboard focus within thirty seconds. The focus does not depend on whether the
    /// simulator shows its software keyboard.
    @MainActor
    func waitUntilFocused() -> Bool {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: self)
        return XCTWaiter().wait(for: [focused], timeout: 30) == .completed
    }
}

extension XCUIElement {
    /// Puts the cursor after the text of the field and types: a tap near its end, past the last word, and low in the
    /// field, on its last line where the field wraps. A tap at the middle of a field of two lines lands at the end of
    /// the first.
    @MainActor
    func append(_ text: String) {
        coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        typeText(text)
    }
}
