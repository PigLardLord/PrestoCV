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
        place(within: app.windows.firstMatch.frame)
    }

    /// Where the middle of this element lies against `room`, a part of the screen such as the room a form leaves for a
    /// tap (`XCUIApplication.tapRoom(in:)`).
    @MainActor
    func place(within room: CGRect) -> ScreenPlace {
        guard exists else { return .missing }
        let frame = self.frame
        guard !frame.isNull, !frame.isInfinite, !frame.isEmpty, !room.isNull, !room.isEmpty else { return .missing }
        if frame.midY < room.minY { return .above }
        if frame.midY > room.maxY { return .below }
        if frame.midX < room.minX || frame.midX > room.maxX { return .beside }
        return .inside
    }

    /// Whether a tap would reach this element now. Asked of an element whose frame lies off the screen, XCTest's own
    /// `isHittable` can find no point to try and stops the test ("Activation point invalid"): a row a form keeps past
    /// its edge once the screen turns. So it is asked only of an element whose middle is on the screen.
    ///
    /// It sees neither the keyboard nor the Done button over it: `isHittable` says yes for a field that lies under
    /// them, and a tap there does not reach the field. A field of the form is brought where a tap reaches it by
    /// `scrollForm`, which keeps to the room the form leaves for a tap.
    @MainActor
    func canBeTapped(in app: XCUIApplication) -> Bool {
        place(in: app) == .inside && isHittable
    }
}

extension XCUIApplication {
    /// The page of a row, while one is open: on a narrow screen a job, a study, a language, a certification and a
    /// profile open on a page of their own.
    @MainActor
    var entryPage: XCUIElement {
        descendants(matching: .any).matching(identifier: "editor.entry.page").firstMatch
    }

    /// The form on the screen: the page of a row while one is open, else the CV's form.
    @MainActor
    var openForm: XCUIElement {
        entryPage.exists ? entryPage : descendants(matching: .any).matching(identifier: "shell.detail.opened").firstMatch
    }

    /// Whether the rows of `section` open on a page of their own here: a job, a study, a language, a certification and a
    /// profile do on a narrow screen. A skill and an interest stay in the form.
    @MainActor
    func opensOnAPage(_ section: String) -> Bool {
        ["experiences", "education", "languages", "certifications", "profiles"].contains(section)
            && windows.firstMatch.horizontalSizeClass == .compact
    }

    /// Closes a confirmation dialog without its action: by its Cancel where it has one, else by a tap outside it. On an
    /// iPhone a dialog asked from a button shows as a popover from that button, with no Cancel. The tap goes to the
    /// middle of the larger room above or below the popover, so the popover never covers it wherever its button sits.
    /// `question` is a text of the dialog, which stands for the popover when the tree does not show one.
    @MainActor
    func cancelDialog(showing question: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let cancel = buttons["Cancel"]
        if cancel.exists {
            cancel.tap()
            return
        }
        let outside = otherElements["PopoverDismissRegion"]
        XCTAssertTrue(outside.waitForExistence(timeout: 5), "The dialog closes with a tap outside it", file: file,
                      line: line)
        let popover = popovers.firstMatch
        let dialog = popover.exists ? popover.frame : question.frame
        let region = outside.frame
        let above = dialog.minY - region.minY
        let below = region.maxY - dialog.maxY
        XCTAssertGreaterThan(max(above, below), 44, "The dialog leaves room for a tap", file: file, line: line)
        let y = above > below ? region.minY + above / 2 : dialog.maxY + below / 2
        outside.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: region.width / 2, dy: y - region.minY)).tap()
    }

    /// Goes back from the page of a row to the CV's form, by the back button of the bar.
    @MainActor
    func leaveEntryPage(file: StaticString = #filePath, line: UInt = #line) {
        let page = entryPage
        backButton.tap()
        XCTAssertTrue(page.waitForNonExistence(timeout: 30), "Back closes the page", file: file, line: line)
    }

    /// The part of `area` where a tap lands on what lies in it: below the bar at its top, and above the keyboard and
    /// the Done button over the keyboard. XCTest's `isHittable` sees neither: on an iPhone with the keyboard up, a field
    /// whose middle lay under the Done button's strip read hittable, and a tap on it gave it no focus. With the keyboard
    /// up, the form's own frame ends at the bottom of that button, so the room ends at the button's top. Null where no
    /// room is left.
    @MainActor
    func tapRoom(in area: XCUIElement) -> CGRect {
        let window = windows.firstMatch.frame
        let whole = area.exists ? window.intersection(area.frame) : window
        guard !whole.isNull, !whole.isEmpty else { return .null }
        var top = whole.minY
        var bottom = whole.maxY
        for bar in navigationBars.allElementsBoundByIndex where bar.exists {
            let frame = bar.frame
            // A bar over the area: not the bar of a column beside it, nor one off the screen
            guard frame.minX < whole.midX, frame.maxX > whole.midX, frame.midY > window.minY, frame.midY < whole.midY,
                  bar.isHittable
            else { continue }
            top = max(top, frame.maxY)
        }
        let keyboard = keyboards.firstMatch
        if keyboard.exists, !keyboard.frame.isEmpty {
            bottom = min(bottom, keyboard.frame.minY)
        }
        let done = buttons.matching(identifier: "keyboard.done").firstMatch
        if done.exists, done.frame.midY > whole.midY {
            bottom = min(bottom, done.frame.minY)
        }
        guard bottom > top else { return .null }
        return CGRect(x: whole.minX, y: top, width: whole.width, height: bottom - top)
    }

    /// Scrolls the open form in steps shorter than the screen, so that no field is passed over, until the middle of
    /// the element lies in the room the form leaves for a tap (`tapRoom(in:)`) and a tap would reach it: on while it
    /// lies below the room, back while above, towards the middle of the room while something else covers it. One the
    /// form has not built is looked for `forward`, or back. The drag stays in the form, away from the list beside it.
    @MainActor
    func scrollForm(until element: XCUIElement, named name: String, forward: Bool = true,
                    file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<15 {
            let room = tapRoom(in: openForm)
            let place = element.place(within: room)
            if place == .inside, element.isHittable { break }
            let on: Bool
            switch place {
            case .below: on = true
            case .above: on = false
            case .inside: on = element.frame.midY > room.midY
            case .missing, .beside: on = forward
            }
            dragForm(on: on)
        }
        let room = tapRoom(in: openForm)
        let place = element.place(within: room)
        XCTAssertTrue(place == .inside && element.isHittable,
                      "\(name) comes into view: \(Self.describe(place, against: room))", file: file, line: line)
    }

    /// Where an element lies against the room for a tap, in words for a failure.
    private static func describe(_ place: ScreenPlace, against room: CGRect) -> String {
        // A null rectangle's edges are infinite, which no Int holds
        guard !room.isNull, !room.isEmpty else { return "the form leaves no room for a tap" }
        let span = "the room for a tap, from \(Int(room.minY)) to \(Int(room.maxY))"
        switch place {
        case .missing: return "it is not in the tree, or has no frame (\(span))"
        case .above: return "its middle lies above \(span)"
        case .below: return "its middle lies below \(span)"
        case .beside: return "its middle lies beside \(span)"
        case .inside: return "its middle lies in \(span), and a tap there does not reach it"
        }
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
