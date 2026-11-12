import XCTest

/// Where an element lies against the window of its app, read from its frame.
enum ScreenPlace: Equatable {
    /// Not in the tree, or with no frame yet: a form builds only the rows near the screen.
    case missing
    case above
    case below
    /// Off a side of the window: a column the screen does not show.
    case beside
    case inside
}

extension XCUIElement {
    /// Where the middle of this element lies against the window of `app`.
    @MainActor
    func place(in app: XCUIApplication) -> ScreenPlace {
        guard exists else { return .missing }
        let frame = self.frame
        let window = app.windows.firstMatch.frame
        guard !frame.isNull, !frame.isInfinite, !frame.isEmpty, !window.isEmpty else { return .missing }
        if frame.midY < window.minY { return .above }
        if frame.midY > window.maxY { return .below }
        if frame.midX < window.minX || frame.midX > window.maxX { return .beside }
        return .inside
    }

    /// Whether a tap would reach this element now. Asked of an element whose frame lies off the screen, XCTest's own
    /// `isHittable` can find no point to try and stops the test ("Activation point invalid"): a row a form keeps past
    /// its edge once the screen turns. So it is asked only of an element whose middle is on the screen.
    @MainActor
    func canBeTapped(in app: XCUIApplication) -> Bool {
        place(in: app) == .inside && isHittable
    }
}

extension XCUIApplication {
    /// Scrolls the open form in steps shorter than the screen, so that no field is passed over, until the element can
    /// be tapped: on while it lies below, back while above, towards the middle while a bar or the keyboard covers it.
    /// One the form has not built is looked for `forward`, or back. The drag stays in the form, away from the list
    /// beside it.
    @MainActor
    func scrollForm(until element: XCUIElement, named name: String, forward: Bool = true,
                    file: StaticString = #filePath, line: UInt = #line) {
        let form = openForm
        for _ in 0..<15 {
            let place = element.place(in: self)
            if place == .inside, element.isHittable { break }
            let on: Bool
            switch place {
            case .below: on = true
            case .above: on = false
            case .inside: on = element.frame.midY > form.frame.midY
            case .missing, .beside: on = forward
            }
            dragForm(on: on)
        }
        XCTAssertTrue(element.canBeTapped(in: self), "\(name) comes into view", file: file, line: line)
    }

    /// Scrolls the open form in the same steps, on or back, until `shown` holds: for a place that "can be tapped" does
    /// not say, such as a whole field lying on the form.
    @MainActor
    func scrollForm(until shown: () -> Bool, named name: String, forward: Bool = true,
                    file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<15 {
            if shown() { break }
            dragForm(on: forward)
        }
        XCTAssertTrue(shown(), "\(name) comes into view", file: file, line: line)
    }

    /// The form whose rows the scrolls move.
    @MainActor
    private var openForm: XCUIElement {
        descendants(matching: .any).matching(identifier: "shell.detail.opened").firstMatch
    }

    /// One step of a scroll: a drag over three tenths of the form's height, up to go on, down to go back.
    @MainActor
    private func dragForm(on: Bool) {
        let form = openForm
        let low = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let high = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        // Held at the end, so the form does not glide on
        (on ? low : high).press(forDuration: 0.05, thenDragTo: on ? high : low, withVelocity: .slow,
                                thenHoldForDuration: 0.2)
    }
}
