import XCTest

extension XCUIApplication {
    /// Turns the device and waits until the screen has turned with it.
    /// - Returns: Whether the screen turned: the outer screen of the iPhone Duo stays in portrait.
    func turn(to orientation: UIDeviceOrientation) -> Bool {
        XCUIDevice.shared.orientation = orientation
        let window = windows.firstMatch
        let turned = NSPredicate { _, _ in (window.frame.width > window.frame.height) == orientation.isLandscape }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: turned, object: nil)], timeout: 10) == .completed
    }
}
