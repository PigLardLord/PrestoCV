import XCTest

extension XCUIApplication {
    /// Turns the device and waits until this app's screen has turned with it.
    /// - Returns: Whether the screen turned: the outer screen of the iPhone Duo stays upright.
    @MainActor
    func turn(to orientation: UIDeviceOrientation) -> Bool {
        let window = windows.firstMatch
        let before = window.frame
        let turned = (before.width > before.height) == orientation.isLandscape
            ? before.size
            : CGSize(width: before.height, height: before.width)
        XCUIDevice.shared.orientation = orientation
        // While the screen turns, the window's frame is the box around it half turned: near a square, and off the
        // origin. Its width passes its height midway, so the turn is over only when the frame is the screen it was,
        // on its side, at the origin. A row read before then has a place that is gone a moment later.
        let deadline = Date.now.addingTimeInterval(10)
        repeat {
            let frame = window.frame
            if abs(frame.minX) < 0.5, abs(frame.minY) < 0.5,
               abs(frame.width - turned.width) < 0.5, abs(frame.height - turned.height) < 0.5 {
                return true
            }
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "A tenth of a second")], timeout: 0.1)
        } while Date.now < deadline
        return false
    }

    /// Turns the device to landscape and waits for this app's screen to turn with it. Where the app stays upright,
    /// Safari is asked too: a screen where Safari stays upright as well has no landscape for any app (the outer screen
    /// of the iPhone Duo), and the test is skipped; one where only this app stays upright is a defect of the app.
    /// - Returns: Whether the app turned. False means Safari turned and this app did not: the caller fails the test, and
    ///   does nothing else with the app, which is no longer in front.
    /// - Throws: `XCTSkip` where no app turns. Call it outside an `XCTAssert`, which would record the skip as a failure.
    @MainActor
    func turnsToLandscape() throws -> Bool {
        if turn(to: .landscapeLeft) { return true }
        try XCTSkipUnless(Self.safariTurnsToLandscape(),
                          "This screen stays upright for every app, as the outer screen of the iPhone Duo")
        return false
    }

    /// Whether Safari's screen turns to landscape. The device is turned back upright first, so that Safari's own turn
    /// is the one read.
    @MainActor
    private static func safariTurnsToLandscape() -> Bool {
        XCUIDevice.shared.orientation = .portrait
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()
        defer { safari.terminate() }
        return safari.turn(to: .landscapeLeft)
    }
}
