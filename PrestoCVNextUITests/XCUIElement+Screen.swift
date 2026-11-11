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
        navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(page.waitForNonExistence(timeout: 30), "Back closes the page", file: file, line: line)
    }

    /// Scrolls the open form in steps shorter than the screen, so that no field is passed over, until the element can
    /// be tapped: on while it lies below, back while above, towards the middle while a bar or the keyboard covers it.
    /// One the form has not built is looked for `forward`, or back. The drag stays in the form, away from the list
    /// beside it.
    @MainActor
    func scrollForm(until element: XCUIElement, named name: String, forward: Bool = true,
                    file: StaticString = #filePath, line: UInt = #line) {
        let form = openForm
        let low = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let high = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
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
            // Held at the end, so the form does not glide on
            (on ? low : high).press(forDuration: 0.05, thenDragTo: on ? high : low, withVelocity: .slow,
                                    thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(element.canBeTapped(in: self), "\(name) comes into view", file: file, line: line)
    }
}
