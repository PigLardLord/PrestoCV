import XCTest

extension XCUIApplication {
    /// Scrolls the form, a little at a time, until the element can be tapped and sits in the upper half of the screen,
    /// clear of the tab bar that floats over the lower part, and of the strip of the keyboard toolbar above the
    /// keyboard, which takes the taps in its whole width. `upwards` scrolls back towards the top of the form instead.
    ///
    /// A swipe is too long a step: at large text sizes it carries a row past the strip where it can be tapped. The
    /// drag also stays above the middle of the screen, so that it does not land on the keyboard when that is up.
    /// It stops when the element no longer moves, which is the end of the form, or after `maxSteps`.
    func scrollTo(_ element: XCUIElement, upwards: Bool = false, maxSteps: Int = 40) {
        var steps = 0
        var previousY: CGFloat?
        while !isReady(element, upwards: upwards) && steps < maxSteps {
            let lower = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
            let upper = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
            let (from, to) = upwards ? (upper, lower) : (lower, upper)
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
            steps += 1
            guard element.exists else { continue }
            let y = element.frame.minY
            if y == previousY { break }
            previousY = y
        }
    }

    private func isReady(_ element: XCUIElement, upwards: Bool) -> Bool {
        guard element.exists, element.isHittable else { return false }
        return upwards || element.frame.midY < frame.height * 0.5
    }
}
