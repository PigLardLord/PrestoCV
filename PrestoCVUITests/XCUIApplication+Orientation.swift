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

    /// Turns the device to landscape and waits for this app's screen to turn with it. Where the app stays upright,
    /// Safari is asked too: a screen where Safari stays upright as well has no landscape for any app (the outer screen of
    /// the iPhone Duo), and the test is skipped; one where only this app stays upright is a defect of the app.
    /// - Returns: Whether the app turned. False means Safari turned and this app did not: the caller fails the test, and
    ///   does nothing else with the app, which is no longer in front.
    /// - Throws: `XCTSkip` where no app turns.
    func turnsToLandscape() throws -> Bool {
        if turn(to: .landscapeLeft) { return true }
        try XCTSkipUnless(Self.safariTurnsToLandscape(), "This screen stays upright for every app, as the outer screen of the iPhone Duo")
        return false
    }

    /// Whether Safari's screen turns to landscape, with the device already turned.
    private static func safariTurnsToLandscape() -> Bool {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()
        defer { safari.terminate() }
        return safari.turn(to: .landscapeLeft)
    }
}
