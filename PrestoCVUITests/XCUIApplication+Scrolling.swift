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
    /// tapped, so the steps after it are half as long. An element taller than the room between the bar and the
    /// keyboard comes wholly onto the screen, with its middle, where a tap lands, in that room.
    ///
    /// It stops when the element no longer moves, which is the end of the form, when a step would be too short to
    /// scroll, or after `maxSteps`. The element may then be tapped where it is if it is clear of the bars and the
    /// keyboard, in the lower half too; otherwise the test fails here, before a tap lands elsewhere.
    func scrollTo(
        _ element: XCUIElement, upwards: Bool = false, maxSteps: Int = 40, file: StaticString = #filePath, line: UInt = #line
    ) {
        var step: CGFloat = 0.2
        var previous: (minY: CGFloat?, back: Bool)?
        for _ in 0..<maxSteps {
            let room = TapRoom(in: self)
            let place = element.place
            if let place, room.holds(place, upwards: upwards), element.isHittable { return }
            let back = place.map { room.scrollsBack(towards: $0, upwards: upwards) } ?? upwards
            if let previous {
                if let minY = place?.minY, minY == previous.minY { break }
                if back != previous.back { step /= 2 }
            }
            guard step >= 0.02 else { break }
            previous = (place?.minY, back)
            let upper = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
            let lower = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22 + step))
            let (from, to) = back ? (upper, lower) : (lower, upper)
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        let room = TapRoom(in: self)
        if let place = element.place, room.holds(place, upwards: true), element.isHittable { return }
        let found = element.place.map { "at \($0)" } ?? "not on the screen"
        XCTFail(
            "The element cannot be scrolled to a place where a tap lands on it: it is \(found), and the room is from \(room.top) to \(room.bottom)",
            file: file, line: line
        )
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

private extension XCUIElement {
    /// Where the element is, or nil while it is not on the screen.
    var place: CGRect? {
        guard exists else { return nil }
        let shown = frame
        return shown.isEmpty ? nil : shown
    }
}

/// Where an element can be tapped, read once for each step of a scroll: below the navigation bar while it is shown,
/// above the keyboard while it is up, on the screen, and in the upper half of it.
struct TapRoom {
    /// The bottom of the navigation bar while it is shown, or the top of the screen.
    let top: CGFloat
    /// The top of the keyboard and its strip while it is up, or the bottom of the screen.
    let bottom: CGFloat
    let screen: CGRect

    /// The places, as the top of an element `height` points tall, where a tap lands on it. One that fits between the
    /// bar and the keyboard is wholly there; a taller one is wholly on the screen, with its middle, where a tap lands,
    /// between them. Unless `upwards`, its middle is in the upper half of the screen too, where it can be. Nil for an
    /// element that has no such place, taller than the screen.
    func tops(forHeight height: CGFloat, upwards: Bool) -> ClosedRange<CGFloat>? {
        let fits = height <= bottom - top
        let lowest = fits ? top : max(screen.minY, top - height / 2)
        let highest = fits ? bottom - height : min(screen.maxY - height, bottom - height / 2)
        guard lowest <= highest else { return nil }
        let upperHalf = min(highest, screen.midY - height / 2)
        return (upwards || upperHalf < lowest) ? lowest...highest : lowest...upperHalf
    }

    /// Whether an element at `place` can be tapped where it is.
    func holds(_ place: CGRect, upwards: Bool) -> Bool {
        tops(forHeight: place.height, upwards: upwards)?.contains(place.minY) ?? false
    }

    /// Whether the next step scrolls back towards the top of the form: for an element above the places where it can
    /// be tapped, under the navigation bar or off the screen. One below them comes up; otherwise `upwards` decides.
    func scrollsBack(towards place: CGRect, upwards: Bool) -> Bool {
        guard let tops = tops(forHeight: place.height, upwards: upwards) else { return upwards }
        if place.minY < tops.lowerBound { return true }
        if place.minY > tops.upperBound { return false }
        return upwards
    }
}

extension TapRoom {
    @MainActor init(in app: XCUIApplication) {
        let screen = app.frame
        self.init(top: app.contentTop, bottom: app.keyboardTop ?? screen.maxY, screen: screen)
    }
}
