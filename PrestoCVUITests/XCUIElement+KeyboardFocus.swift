import XCTest

extension XCUIElement {
    /// Whether the element gets, or loses, the keyboard focus within `timeout`. The focus does not depend on whether
    /// the simulator shows its software keyboard.
    func waitForKeyboardFocus(_ focused: Bool, timeout: TimeInterval = 30) -> Bool {
        let condition = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasKeyboardFocus == %@", NSNumber(value: focused)),
            object: self
        )
        return XCTWaiter().wait(for: [condition], timeout: timeout) == .completed
    }
}

extension XCUIApplication {
    /// Why the software keyboard may not come up when a field has the focus. The tests of the keyboard need it: without
    /// it, the checks that it closes pass for the wrong reason, and the form has nothing to make way for.
    static let noSoftwareKeyboard = "The software keyboard did not come up: a hardware keyboard is connected to the simulator. "
        + "Turn off Simulator > I/O > Keyboard > Connect Hardware Keyboard, or run "
        + "`defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false` before the simulator boots."
}
