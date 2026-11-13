import XCTest

/// The editor while its text cannot be stored because another window changed or deleted the CV (#402, 5-11d): the
/// notice above the form says what to do and offers the ways out, the system Back is hidden until the person answered
/// it, and nothing typed is lost. The launch fixture `-PrestoCVNextOtherWindow` makes the first write of the open CV
/// meet the other window's change.
///
/// VoiceOver's announcement of a new status cannot be observed from a UI test; `testConflictReload` checks that the
/// status line the announcement reads changes instead.
final class EditorConflictUITests: XCTestCase {
    /// A CV the launch fixture stores before the app starts.
    private struct StoredCV {
        let identity: String
        let title: String
        let person: String
        /// When it was last saved, as the store writes it.
        let saved: String
    }

    private let backendEngineer = StoredCV(
        identity: "6B1F6C1E-1B8C-4C1B-9D55-1F3B2C8B7A01", title: "Backend Engineer", person: "Mara Ellison",
        saved: "2026-01-02T00:00:00Z")
    private let dataAnalyst = StoredCV(
        identity: "7C2A7D2F-2C9D-4D2C-8E66-2A4C3D9C8B02", title: "Data Analyst", person: "Orla Penhaligon",
        saved: "2026-01-01T00:00:00Z")

    // MARK: English words

    private let saved = "Saved on this device"
    private let changedElsewhere = "Not saved: this CV was changed elsewhere in the app."
    private let deletedElsewhere = "Not saved: this CV was deleted elsewhere in the app."
    /// What the person types at the end of the title, and the title it makes.
    private let typed = " Lead"
    private let edited = "Backend Engineer Lead"
    /// The copy of the edited CV, as the list names it.
    private let copyTitle = "Copy of Backend Engineer Lead"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: Conflict

    @MainActor
    func testConflictReload() throws {
        let app = try launch(otherWindow: "conflict")
        try blocked(by: changedElsewhere, in: app)
        let reload = app.buttons["editor.notice.reload"]
        assertTall(reload, named: "Reload")
        assertTall(app.buttons["editor.notice.saveAsCopy"], named: "Save as a copy")
        keepScreenshot("The notice of a conflict", of: app)

        reload.tap()

        XCTAssertTrue(waitUntil(status(of: app), reads: saved), "The stored version is saved and shown")
        XCTAssertTrue(waitUntilGone(element("editor.notice", in: app)), "The notice goes once the text is the stored one")
        XCTAssertEqual(
            textInput("editor.field.title", in: app).value as? String, backendEngineer.title,
            "Reload shows the stored title, without the change typed here")
    }

    @MainActor
    func testConflictSaveAsCopy() throws {
        let app = try launch(otherWindow: "conflict")
        try blocked(by: changedElsewhere, in: app)

        app.buttons["editor.notice.saveAsCopy"].tap()

        XCTAssertTrue(waitUntil(status(of: app), reads: saved), "The copy is saved")
        XCTAssertTrue(waitUntilGone(element("editor.notice", in: app)), "The notice goes once the copy is saved")
        XCTAssertEqual(
            textInput("editor.field.title", in: app).value as? String, copyTitle, "The editor now holds the copy")
        XCTAssertTrue(
            waitUntil(app.staticTexts["shell.detail.title"], reads: copyTitle), "The open CV is named as the copy's row")
        showList(in: app)
        XCTAssertTrue(row(titled: copyTitle, in: app).waitForExistence(timeout: 30), "The list shows the copy")
        XCTAssertTrue(
            row(titled: backendEngineer.title, in: app).exists, "The CV the other window changed is still listed")
    }

    // MARK: Deleted elsewhere

    @MainActor
    func testDeletedElsewhereSaveAsCopy() throws {
        let app = try launch(otherWindow: "deleted")
        try blocked(by: deletedElsewhere, in: app)
        let copy = app.buttons["editor.notice.saveAsCopy"]
        assertTall(copy, named: "Save as a copy")
        assertTall(app.buttons["editor.notice.discard"], named: "Discard")
        keepScreenshot("The notice of a CV deleted elsewhere", of: app)

        copy.tap()

        XCTAssertTrue(waitUntil(status(of: app), reads: saved), "The copy is saved")
        XCTAssertTrue(waitUntilGone(element("editor.notice", in: app)), "The notice goes once the copy is saved")
        XCTAssertEqual(
            textInput("editor.field.title", in: app).value as? String, copyTitle, "The editor now holds the copy")
        showList(in: app)
        XCTAssertTrue(row(titled: copyTitle, in: app).waitForExistence(timeout: 30), "The list shows the copy")
        XCTAssertTrue(
            waitUntilGone(row(titled: backendEngineer.title, in: app)), "The CV the other window deleted is not listed")
    }

    @MainActor
    func testDeletedElsewhereDiscard() throws {
        let app = try launch(otherWindow: "deleted")
        try blocked(by: deletedElsewhere, in: app)

        app.buttons["editor.notice.discard"].tap()

        XCTAssertTrue(waitUntilGone(element("editor.notice", in: app)), "Discard closes the editor")
        if isCompact(app) {
            XCTAssertTrue(
                row(titled: dataAnalyst.title, in: app).waitForExistence(timeout: 30), "The list shows once the editor closed")
        } else {
            XCTAssertTrue(
                element("shell.detail.empty", in: app).waitForExistence(timeout: 30), "The detail shows nothing selected")
        }
        XCTAssertTrue(
            waitUntilGone(row(titled: backendEngineer.title, in: app)), "The CV the other window deleted is not listed")
        XCTAssertFalse(row(titled: copyTitle, in: app).exists, "Discard stores nothing")
    }

    // MARK: Leaving

    @MainActor
    func testBackIsHiddenWhileBlocked() throws {
        let app = try launch(otherWindow: "conflict")
        try blocked(by: changedElsewhere, in: app)

        if isCompact(app) {
            XCTAssertFalse(app.navigationBars.buttons.firstMatch.exists, "No Back while the text cannot be stored")
            let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
            XCTAssertTrue(element("editor.notice", in: app).exists, "The swipe from the edge does not leave the editor")
            let list = row(titled: dataAnalyst.title, in: app)
            XCTAssertFalse(list.exists && list.isHittable, "The list does not come into view")
        } else {
            row(titled: dataAnalyst.title, in: app).tap()
            XCTAssertTrue(element("editor.notice", in: app).exists, "Another row does not replace the editor")
        }
        XCTAssertEqual(
            textInput("editor.field.title", in: app).value as? String, edited, "The text typed is still in the editor")

        app.buttons["editor.notice.reload"].tap()
        XCTAssertTrue(waitUntil(status(of: app), reads: saved), "The stored version is saved and shown")
        if isCompact(app) {
            let back = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(back.waitForExistence(timeout: 30), "Back comes back once the text is stored")
            back.tap()
        }
        open(dataAnalyst, in: app)
        XCTAssertEqual(
            textInput("editor.field.title", in: app).value as? String, dataAnalyst.title,
            "Another CV opens once the editor can be left")
    }

    @MainActor
    func testNoticeScrollsInLandscape() throws {
        let app = try launch(otherWindow: "conflict", largestText: true)
        try XCTSkipUnless(isCompact(app), "Only an iPhone has a compact height on its side")
        try blocked(by: changedElsewhere, in: app)

        XCTAssertTrue(app.turn(to: .landscapeLeft), "The screen turned")
        XCTAssertEqual(app.windows.firstMatch.verticalSizeClass, .compact, "The iPhone turned")

        let editor = element("shell.detail.opened", in: app)
        let notice = app.scrollViews.containing(.any, identifier: "editor.notice").firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The notice scrolls inside where the form is short of room")
        assertQuarterBelowTheBar(notice, of: editor, in: app)
        let reload = app.buttons["editor.notice.reload"]
        guard scroll(notice, toShow: reload, named: "Reload", in: app) else { return }
        XCTAssertTrue(reload.isHittable, "Reload comes into view inside the notice")
        assertTall(reload, named: "Reload")
        keepScreenshot("The notice in landscape at the largest text size", of: app)
        scrollUntilHittable(textInput("editor.field.title", in: app), named: "The title field", in: app)

        reload.tap()
        XCTAssertTrue(waitUntilGone(element("editor.notice", in: app)), "The notice goes once the text is the stored one")
    }

    // MARK: Helpers

    /// Opens Backend Engineer, types at the end of its title, and waits for the status the other window's change gives,
    /// with the notice above the form. The keyboard is put away, so that only the notice and the form remain. While the
    /// person types, the form may scroll the status line at its top off the screen, where a form shows no row: it is
    /// brought back before it is read.
    @MainActor
    private func blocked(by words: String, in app: XCUIApplication) throws {
        open(backendEngineer, in: app)
        XCTAssertTrue(waitUntil(status(of: app), reads: saved), "The CV opens stored")
        let title = textInput("editor.field.title", in: app)
        scrollUntilHittable(title, named: "The title field", in: app)
        append(typed, to: title)
        XCTAssertTrue(element("editor.notice", in: app).waitForExistence(timeout: 30), "The notice says what to do")
        let done = app.buttons["keyboard.done"]
        if done.exists { done.tap() }
        scrollBackUntilHittable(status(of: app), named: "The status line", in: app)
        XCTAssertTrue(waitUntil(status(of: app), reads: words), "The status line says why the text is not stored")
    }

    @MainActor
    private func launch(otherWindow change: String, largestText: Bool = false) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage",
            "-PrestoCVNextSeed", try seed([backendEngineer, dataAnalyst]),
            "-PrestoCVNextOtherWindow", change,
        ]
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    /// The seed of the launch fixture: the stored files of `cvs`, as base64 of a JSON object by file name.
    private func seed(_ cvs: [StoredCV]) throws -> String {
        var files: [String: String] = [:]
        for cv in cvs {
            files["\(cv.identity).cv.json"] = """
                {"schemaVersion":1,"id":"\(cv.identity)","revision":1,\
                "createdAt":"2026-01-01T00:00:00Z","updatedAt":"\(cv.saved)","title":"\(cv.title)",\
                "personal":{"fullName":"\(cv.person)","professionalTitle":"","location":"","summary":""},\
                "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],\
                "interests":[]}
                """
        }
        return try JSONEncoder().encode(files).base64EncodedString()
    }

    private func open(_ cv: StoredCV, in app: XCUIApplication) {
        let row = row(titled: cv.title, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The list shows \(cv.title)")
        row.tap()
        let title = textInput("editor.field.title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 30), "The form of \(cv.title) opens")
    }

    /// The list, from the editor: a compact screen goes back to it, a regular one shows it beside the editor.
    private func showList(in app: XCUIApplication) {
        guard isCompact(app) else { return }
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 30), "Back shows once the text is stored")
        back.tap()
    }

    private func row(titled title: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "shell.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", title + ", ")).firstMatch
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The text input with this identifier, of either kind: a field of one line wraps at the largest text sizes, and
    /// XCUITest may then show it as a text view.
    private func textInput(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let kinds = NSPredicate(
            format: "elementType == %lu OR elementType == %lu",
            XCUIElement.ElementType.textField.rawValue, XCUIElement.ElementType.textView.rawValue)
        return app.descendants(matching: .any).matching(identifier: identifier).matching(kinds).firstMatch
    }

    private func status(of app: XCUIApplication) -> XCUIElement {
        app.staticTexts["editor.status"]
    }

    private func isCompact(_ app: XCUIApplication) -> Bool {
        app.windows.firstMatch.horizontalSizeClass != .regular
    }

    /// The notice takes at most a quarter of the editor, both measured below the navigation bar. A scroll view at the
    /// top reaches under the bar, and so does the editor around it: both frames hold the bar's height, which the person
    /// sees as neither. The frames are kept with the result, so that a failure says what was measured.
    @MainActor
    private func assertQuarterBelowTheBar(_ notice: XCUIElement, of editor: XCUIElement, in app: XCUIApplication) {
        let (bars, top) = navigationBars(in: app)
        let shown = notice.frame.maxY - max(notice.frame.minY, top)
        let room = editor.frame.maxY - max(editor.frame.minY, top)
        let window = app.windows.firstMatch.frame
        let frames = "notice \(notice.frame), editor \(editor.frame), bars \(bars), window \(window)"
        let record = XCTAttachment(string: frames)
        record.name = "Frames in landscape"
        record.lifetime = .keepAlways
        add(record)
        XCTAssertGreaterThan(room, 0, "The editor shows below the bar: \(frames)")
        XCTAssertLessThanOrEqual(shown, room * 0.25 + 1, "The notice takes at most a quarter of the editor: \(frames)")
    }

    /// Keeps a picture of the screen with the result, for the review of what the person sees.
    @MainActor
    private func keepScreenshot(_ name: String, of app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// The navigation bars over the window, and the line below them, where what the person sees of the screen begins.
    @MainActor
    private func navigationBars(in app: XCUIApplication) -> (frames: [CGRect], bottom: CGFloat) {
        let window = app.windows.firstMatch.frame
        let frames = app.navigationBars.allElementsBoundByIndex.map(\.frame)
            .filter { window.intersects($0) && !$0.isEmpty }
        return (frames, frames.map(\.maxY).max() ?? window.minY)
    }

    /// Scrolls the notice with slow drags inside its visible part until the middle of `button` shows in it, and says
    /// whether it does. A swipe flicks: in a notice a quarter of the editor high it scrolls past the button, under the
    /// bar, where XCUITest cannot tell whether the button is hittable and records a failure instead of saying no.
    @MainActor
    private func scroll(
        _ notice: XCUIElement, toShow button: XCUIElement, named name: String, in app: XCUIApplication
    ) -> Bool {
        XCTAssertTrue(button.waitForExistence(timeout: 30), "The notice offers \(name)")
        let top = navigationBars(in: app).bottom
        let origin = notice.coordinate(withNormalizedOffset: .zero)
        for drag in 0...12 {
            let frame = notice.frame
            let visibleTop = max(frame.minY, top)
            let middle = button.frame.midY
            if middle > visibleTop, middle < frame.maxY { return true }
            guard drag < 12 else { break }
            // Clear of the text and the buttons, which sit in the readable width, and of the scroll bar at the edge.
            let x = frame.width * 0.9
            let inset = min(8, (frame.maxY - visibleTop) / 4)
            let low = origin.withOffset(CGVector(dx: x, dy: frame.maxY - inset - frame.minY))
            let high = origin.withOffset(CGVector(dx: x, dy: visibleTop + inset - frame.minY))
            // Below the visible part, a drag up brings the lower text up; above it, a drag down brings it back.
            let (from, to) = middle >= frame.maxY ? (low, high) : (high, low)
            from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        XCTFail("\(name) does not come into view in the notice: \(button.frame), notice \(notice.frame), bar \(top)")
        return false
    }

    /// Every action of the notice is at least as tall as the smallest tap target.
    private func assertTall(_ button: XCUIElement, named name: String) {
        XCTAssertTrue(button.waitForExistence(timeout: 30), "The notice offers \(name)")
        XCTAssertGreaterThanOrEqual(button.frame.height, 43.99, "\(name) is at least 44 points tall")
    }

    @MainActor
    private func waitUntil(_ element: XCUIElement, reads label: String) -> Bool {
        let reads = expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
        return XCTWaiter().wait(for: [reads], timeout: 30) == .completed
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: 30) == .completed
    }

    /// Scrolls the form up in steps shorter than the screen until the element can be tapped.
    @MainActor
    private func scrollUntilHittable(_ element: XCUIElement, named name: String, in app: XCUIApplication) {
        scroll(until: element, named: name, in: app, from: 0.6, to: 0.3)
    }

    /// The same towards the top of the form. The drag starts below the notice, which scrolls by itself and would keep
    /// the drag.
    @MainActor
    private func scrollBackUntilHittable(_ element: XCUIElement, named name: String, in app: XCUIApplication) {
        scroll(until: element, named: name, in: app, from: 0.5, to: 0.8)
    }

    /// Drags the form from one height to another, as fractions of its frame, until the element can be tapped.
    @MainActor
    private func scroll(
        until element: XCUIElement, named name: String, in app: XCUIApplication, from start: CGFloat, to end: CGFloat
    ) {
        let form = self.element("shell.detail.opened", in: app)
        let from = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start))
        let to = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: end))
        for _ in 0..<15 where !(element.exists && element.isHittable) {
            // Held at the end, so the form does not glide on
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(element.exists && element.isHittable, "\(name) comes into view")
    }

    /// Puts the cursor after the text of the field and types: a tap near its end, past the last word, and low in the
    /// field, on its last line where the field wraps. A tap at the middle of a field of two lines lands at the end of
    /// the first.
    @MainActor
    private func append(_ text: String, to field: XCUIElement) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        field.typeText(text)
    }
}
