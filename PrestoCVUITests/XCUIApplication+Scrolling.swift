import XCTest

extension XCUIApplication {
    /// Scrolls the form, a little at a time, until the element can be tapped and sits in the upper half of the screen,
    /// clear of the tab bar that floats over the lower part, of the strip of the keyboard toolbar above the keyboard,
    /// which takes the taps in its whole width, and of the navigation bar while it is shown. `upwards` scrolls back
    /// towards the top of the form instead.
    ///
    /// A swipe is too long a step: at large text sizes it carries a row past the strip where it can be tapped. The
    /// drag also stays above the middle of the screen, so that it does not land on the keyboard when that is up.
    /// The place of the element decides the way: one under the navigation bar or above the screen comes down, and while
    /// the keyboard is up one under it comes up, as the first field of a form on a short screen, the outer screen of
    /// the iPhone Duo, which the top of the form leaves under the strip. A field under the navigation bar counts as
    /// hittable, but a tap on it lands on the bar: the iPhone Duo shows the bar again as the form scrolls back, over
    /// the field the scroll brought down. A step that turns back has carried the element past the room where it can be
    /// tapped, so the steps after it are half as long. It stops when the element no longer moves, which is the end of
    /// the form, when a step would be too short to scroll, or after `maxSteps`.
    func scrollTo(_ element: XCUIElement, upwards: Bool = false, maxSteps: Int = 40) {
        var step: CGFloat = 0.2
        var previous: (minY: CGFloat?, back: Bool)?
        for _ in 0..<maxSteps {
            let room = TapRoom(in: self)
            let frame = element.exists ? element.frame : .zero
            let place = frame.isEmpty ? nil : frame
            if let place, room.holds(place, upwards: upwards), element.isHittable { return }
            let back = place.map { room.scrollsBack(towards: $0, upwards: upwards) } ?? upwards
            if let previous {
                if let minY = place?.minY, minY == previous.minY { return }
                if back != previous.back { step /= 2 }
            }
            guard step >= 0.02 else { return }
            previous = (place?.minY, back)
            let upper = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
            let lower = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22 + step))
            let (from, to) = back ? (upper, lower) : (lower, upper)
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
    }

    /// The top of what the keyboard covers while it is up: the strip of its toolbar, which takes the taps in its whole
    /// width, or the keyboard itself. Nil while the keyboard is down. The Done of the strip sits on the keyboard; a
    /// Done of the screen's bar, which the iPhone Duo puts in a toolbar too, sits far above it.
    var keyboardTop: CGFloat? {
        let keyboard = keyboards.firstMatch
        guard keyboard.exists else { return nil }
        let top = keyboard.frame.minY
        let strip = toolbars.buttons.matching(identifier: "Done").allElementsBoundByIndex
            .map(\.frame)
            .filter { top - $0.maxY < 44 }
        return strip.map(\.minY).min().map { min($0, top) } ?? top
    }

    /// The top of the room the screen shows its content in: the bottom of the navigation bar, or the top of the window
    /// while the system hides the bar, as the iPhone Duo does while a form scrolls down. A hidden bar keeps its frame,
    /// but it cannot take a tap.
    var contentTop: CGFloat {
        let bar = navigationBars.firstMatch
        return bar.exists && bar.isHittable ? bar.frame.maxY : frame.minY
    }
}

/// Where an element can be tapped, read once for each step of a scroll: below the navigation bar while it is shown,
/// above the keyboard while it is up, and in the upper half of the screen.
private struct TapRoom {
    let top: CGFloat
    let keyboardTop: CGFloat?
    let height: CGFloat

    @MainActor init(in app: XCUIApplication) {
        top = app.contentTop
        keyboardTop = app.keyboardTop
        height = app.frame.height
    }

    /// Whether an element at `place` can be tapped where it is. Scrolling back, it may sit in the lower half.
    func holds(_ place: CGRect, upwards: Bool) -> Bool {
        guard place.minY >= top else { return false }
        if let keyboardTop, place.maxY > keyboardTop { return false }
        return upwards || place.midY < height * 0.5
    }

    /// Whether the next step scrolls back towards the top of the form: for an element above the room, under the
    /// navigation bar or off the screen. One under the keyboard comes up; otherwise `upwards` decides.
    func scrollsBack(towards place: CGRect, upwards: Bool) -> Bool {
        if place.minY < top { return true }
        if let keyboardTop, place.maxY > keyboardTop { return false }
        return upwards
    }
}
