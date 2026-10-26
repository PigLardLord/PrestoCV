import XCTest

extension XCUIApplication {
    /// Scrolls the form, a little at a time, until the element can be tapped and sits in the upper half of the screen,
    /// clear of the tab bar that floats over the lower part, of the strip of the keyboard toolbar above the keyboard,
    /// which takes the taps in its whole width, and of the navigation bar while it is shown. `upwards` scrolls back
    /// towards the top of the form instead. `toTheUpperHalf` false takes any place in that room, and stops at the first
    /// one: on a short screen, in landscape, the upper half is a strip of less than one step, and a step carries the
    /// row past it.
    ///
    /// A swipe is too long a step: at large text sizes it carries a row past the strip where it can be tapped. The
    /// drag also stays above the middle of the screen, so that it does not land on the keyboard when that is up.
    /// The place of the element decides the way: one under the navigation bar or above the screen comes down, and while
    /// the keyboard is up one under it comes up, as the first field of a form on a short screen, the outer screen of
    /// the iPhone Duo, which the top of the form leaves under the strip. A field under the navigation bar counts as
    /// hittable, but a tap on it lands on the bar: the iPhone Duo shows the bar again as the form scrolls back, over
    /// the field the scroll brought down. A step that turns back has carried the element past the room where it can be
    /// tapped, so the steps after it are half as long. An element taller than the room between the bar and the
    /// keyboard comes wholly onto the screen, with its middle, where a tap lands, in that room. One whose places there
    /// span less than the shortest step, a fortieth of the screen's height, may not be reached, and fails the test.
    ///
    /// It stops when the element no longer moves, which is the end of the form, when a step would be too short to
    /// scroll, or after `maxSteps`. The element may then be tapped where it is if it is clear of the bars and the
    /// keyboard, in the lower half too; otherwise the test fails here, before a tap lands elsewhere.
    func scrollTo(
        _ element: XCUIElement, upwards: Bool = false, maxSteps: Int = 40, toTheUpperHalf: Bool = true,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        var step: CGFloat = 0.2
        var previous: (minY: CGFloat?, back: Bool)?
        for _ in 0..<maxSteps {
            let room = TapRoom(in: self)
            let place = element.place
            if let place, room.holds(place, upwards: upwards, toTheUpperHalf: toTheUpperHalf), element.isHittable { return }
            let back = place.map { room.scrollsBack(towards: $0, upwards: upwards, toTheUpperHalf: toTheUpperHalf) } ?? upwards
            if let previous {
                if let minY = place?.minY, minY == previous.minY { break }
                if back != previous.back { step /= 2 }
            }
            guard step >= 0.02 else { break }
            previous = (place?.minY, back)
            dragForm(by: step, back: back)
        }
        let room = TapRoom(in: self)
        if let place = element.place, room.holds(place, upwards: true), element.isHittable { return }
        let found = element.place.map { "at \($0)" } ?? "not on the screen"
        XCTFail(
            "The element cannot be scrolled to a place where a tap lands on it: it is \(found), and the room is from \(room.top) to \(room.bottom)",
            file: file, line: line
        )
    }

    /// Drags the form by `step` of the screen's height, towards its top when `back`, otherwise towards its end. The drag
    /// stays above the middle of the screen, so that it does not land on the keyboard when that is up.
    func dragForm(by step: CGFloat, back: Bool) {
        let upper = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
        let lower = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22 + step))
        let (from, to) = back ? (upper, lower) : (lower, upper)
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    /// Calls `visit` with the form at its top, then after each step down to its end. A list is lazy: only the rows near the
    /// screen are in the tree, so what is read at one place is not the whole list, and the count of its fields is not the
    /// count of its rows. A step is 3/10 of the screen's height, less than the room the rows are shown in, so that no row
    /// falls between two stops. The form has ended, at its top and at its end, when a step moves nothing; `maxSteps` bounds
    /// each way. The form is left at its end.
    func walkTheForm(maxSteps: Int = 30, visit: () -> Void) {
        var shown = formPosition
        for _ in 0..<maxSteps {
            dragForm(by: 0.3, back: true)
            let moved = formPosition
            if moved == shown { break }
            shown = moved
        }
        visit()
        for _ in 0..<maxSteps {
            dragForm(by: 0.3, back: false)
            let moved = formPosition
            if moved == shown { break }
            shown = moved
            visit()
        }
    }

    /// Where the form is, read from the first and the last row in the tree: it changes as the form moves.
    private var formPosition: [CGRect] {
        let rows = cells
        let count = rows.count
        guard count > 0 else { return [] }
        return [rows.element(boundBy: 0).frame, rows.element(boundBy: count - 1).frame]
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

    /// The top of a tab bar that floats over the lower part of the screen while it is shown, as on an iPhone. Nil while
    /// no tab bar is shown, as while the keyboard is up in the editor, and when the tabs are at the top, as on an iPad
    /// in a wide window, or in a bar at the side, as on the outer screen of the iPhone Duo.
    var tabBarTop: CGFloat? {
        let bar = tabBars.firstMatch
        guard bar.exists, bar.isHittable else { return nil }
        let top = bar.frame.minY
        return top > frame.midY ? top : nil
    }

    /// The top of the room the screen shows its content in: the bottom of the navigation bar, or the top of the window
    /// while the system hides the bar, as the iPhone Duo does while a form scrolls down. A hidden bar keeps its frame,
    /// but it cannot take a tap.
    var contentTop: CGFloat {
        let bar = navigationBars.firstMatch
        return bar.exists && bar.isHittable ? bar.frame.maxY : frame.minY
    }

    /// Where a tap lands now. A test's own helpers read it here: the room's initializer is isolated to the main actor, as
    /// the app's members are, which the helpers of a test class are not.
    var tapRoom: TapRoom { TapRoom(in: self) }
}

private extension XCUIElement {
    /// Where the element is, or nil while it is not on the screen. A row the form has not drawn has no frame, or one with an
    /// infinite origin: that says nothing of where the form ends, so it is not a place.
    var place: CGRect? {
        guard exists else { return nil }
        let shown = frame
        guard !shown.isEmpty, !shown.isInfinite, shown.minY.isFinite, shown.maxY.isFinite else { return nil }
        return shown
    }
}

/// Where an element can be tapped, read once for each step of a scroll: below the navigation bar while it is shown,
/// above the keyboard while it is up and above a tab bar over the lower part, on the screen, and in the upper half of it
/// unless the scroll is told not to ask for that.
struct TapRoom {
    /// The bottom of the navigation bar while it is shown, or the top of the screen.
    let top: CGFloat
    /// The top of the keyboard and its strip while it is up, or of a tab bar over the lower part, whichever is higher;
    /// or the bottom of the screen.
    let bottom: CGFloat
    let screen: CGRect

    /// The places, as the top of an element `height` points tall, where a tap lands on it. One that fits between the
    /// bar and the keyboard is wholly there; a taller one is wholly on the screen, with its middle, where a tap lands,
    /// between them. Unless `upwards` or not `toTheUpperHalf`, its middle is in the upper half of the screen too, where it
    /// can be. Nil for an element that has no such place, taller than the screen.
    func tops(forHeight height: CGFloat, upwards: Bool, toTheUpperHalf: Bool = true) -> ClosedRange<CGFloat>? {
        let fits = height <= bottom - top
        let lowest = fits ? top : max(screen.minY, top - height / 2)
        let highest = fits ? bottom - height : min(screen.maxY - height, bottom - height / 2)
        guard lowest <= highest else { return nil }
        let upperHalf = min(highest, screen.midY - height / 2)
        return (upwards || !toTheUpperHalf || upperHalf < lowest) ? lowest...highest : lowest...upperHalf
    }

    /// Whether an element at `place` can be tapped where it is.
    func holds(_ place: CGRect, upwards: Bool, toTheUpperHalf: Bool = true) -> Bool {
        tops(forHeight: place.height, upwards: upwards, toTheUpperHalf: toTheUpperHalf)?.contains(place.minY) ?? false
    }

    /// Whether the next step scrolls back towards the top of the form: for an element above the places where it can
    /// be tapped, under the navigation bar or off the screen. One below them comes up; otherwise `upwards` decides.
    func scrollsBack(towards place: CGRect, upwards: Bool, toTheUpperHalf: Bool = true) -> Bool {
        guard let tops = tops(forHeight: place.height, upwards: upwards, toTheUpperHalf: toTheUpperHalf) else { return upwards }
        if place.minY < tops.lowerBound { return true }
        if place.minY > tops.upperBound { return false }
        return upwards
    }

    /// Where a swipe along a row starts, in the coordinates of the screen. It is in the row's upper part, clear of the
    /// text, and in the room where a touch lands: not under the navigation bar, which a row scrolled up leaves over
    /// its upper part, nor on the keyboard's strip. It is at nine tenths of the row's width, and inside the content:
    /// 8 points left of `contentRight`, the right edge of what the row shows, when that is left of those nine tenths,
    /// as on the outer screen of the iPhone Duo. It is never left of three tenths. A row that is not on the screen has
    /// no place to swipe: the point falls at the edge of the room.
    func swipeStart(in row: CGRect, contentRight: CGFloat?) -> CGPoint {
        let usual = row.minX + row.width * 0.9
        let inside = contentRight.map { min(usual, $0 - 8) } ?? usual
        let x = max(row.minX + row.width * 0.3, inside)
        let lowest = max(top + 8, row.minY + 4)
        let highest = max(lowest, min(bottom - 8, row.maxY - 4))
        return CGPoint(x: x, y: min(max(row.minY + row.height * 0.12, lowest), highest))
    }

    /// Where a tap closes a popover, in the coordinates of the screen: outside `covered`, the popover's frame, which sits
    /// beside its row, so that it is not always in the same place. The middle of the largest band of the screen above,
    /// below, left or right of it. Low on the screen, as before, without a popover to avoid on the screen or when it
    /// leaves no band.
    func pointOutside(_ covered: CGRect?) -> CGPoint {
        let low = CGPoint(x: screen.midX, y: screen.minY + screen.height * 0.95)
        guard let covered else { return low }
        let hidden = covered.intersection(screen)
        guard !hidden.isNull else { return low }
        // A band is there only where the popover leaves room: a rectangle's width and height are never negative
        var bands: [CGRect] = []
        if hidden.minY > screen.minY {
            bands.append(CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: hidden.minY - screen.minY))
        }
        if hidden.maxY < screen.maxY {
            bands.append(CGRect(x: screen.minX, y: hidden.maxY, width: screen.width, height: screen.maxY - hidden.maxY))
        }
        if hidden.minX > screen.minX {
            bands.append(CGRect(x: screen.minX, y: screen.minY, width: hidden.minX - screen.minX, height: screen.height))
        }
        if hidden.maxX < screen.maxX {
            bands.append(CGRect(x: hidden.maxX, y: screen.minY, width: screen.maxX - hidden.maxX, height: screen.height))
        }
        guard let largest = bands.max(by: { $0.width * $0.height < $1.width * $1.height }) else { return low }
        return CGPoint(x: largest.midX, y: largest.midY)
    }
}

extension TapRoom {
    @MainActor init(in app: XCUIApplication) {
        let screen = app.frame
        let covers = [app.keyboardTop, app.tabBarTop].compactMap { $0 }
        self.init(top: app.contentTop, bottom: covers.min() ?? screen.maxY, screen: screen)
    }
}
