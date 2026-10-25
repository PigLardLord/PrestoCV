import XCTest

extension XCUIApplication {
    /// Scrolls the form, a little at a time, until the element can be tapped and sits in the upper half of the screen,
    /// clear of the tab bar that floats over the lower part, and of the strip of the keyboard toolbar above the
    /// keyboard, which takes the taps in its whole width. `upwards` scrolls back towards the top of the form instead.
    /// `toTheUpperHalf` false stops at the first place where the element can be tapped: on a short screen, in landscape,
    /// the upper half is a strip of less than one step, and a step carries the row past it.
    ///
    /// A swipe is too long a step: at large text sizes it carries a row past the strip where it can be tapped. The
    /// drag also stays above the middle of the screen, so that it does not land on the keyboard when that is up.
    /// It stops when the element no longer moves, which is the end of the form, or after `maxSteps`. A row that is not drawn
    /// yet has no frame, and does not count as not moving.
    func scrollTo(_ element: XCUIElement, upwards: Bool = false, maxSteps: Int = 40, toTheUpperHalf: Bool = true) {
        var steps = 0
        var previousY: CGFloat?
        while !isReady(element, upwards: upwards, toTheUpperHalf: toTheUpperHalf) && steps < maxSteps {
            let lower = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
            let upper = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
            let (from, to) = upwards ? (upper, lower) : (lower, upper)
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
            steps += 1
            // A row the form has not drawn has no frame (its origin is infinite): that says nothing of the end of the form.
            guard element.exists, element.frame.minY.isFinite else { continue }
            let y = element.frame.minY
            if y == previousY { break }
            previousY = y
        }
    }

    private func isReady(_ element: XCUIElement, upwards: Bool, toTheUpperHalf: Bool) -> Bool {
        guard element.exists, element.isHittable else { return false }
        return upwards || !toTheUpperHalf || element.frame.midY < frame.height * 0.5
    }
}
