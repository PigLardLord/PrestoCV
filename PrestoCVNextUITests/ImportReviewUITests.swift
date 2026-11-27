import XCTest

/// The review of an import (#404, 5-13b): the notice above the imported draft says what to check and what was not
/// added, Review opens a sheet with the values to check and the text not imported, Copy all copies that text, and the
/// review ends at the first store of a change the person made or on Dismiss. The texts come through the system's
/// pasteboard and paste button, as from another app.
///
/// A UI test cannot observe three things: that the sheet stays open while the editor stores the CV, which
/// `ShellReviewTests` checks (no action of a person stores the CV while the sheet covers the form); that the two titles
/// of the sheet are headings, since XCUITest does not show the header trait (they are found by their words and their
/// place); and VoiceOver's announcement of the copy.
final class ImportReviewUITests: RuntimeIssueFailingTestCase {
    /// A CV with a value to check, a language whose level is not a CEFR level, and lines that fit no field.
    private let cvToCheckAndCopy = """
        Ada Lovelace
        Analyst
        Leeds

        Experience
        Analyst, Example Engines, 2019 – 2024
        Wrote the first programs for the engine.

        Languages
        French, fluent

        Hobbies: chess, sailing
        """

    /// A CV whose every line fits a field, with one value to check.
    private let cvToCheck = """
        Ada Lovelace
        ada@example.com

        Experience
        Analyst, Example Engines, 2019 – 2024
        Wrote the first programs for the engine.
        """

    /// A value to check, as the sheet shows it: where it is, the person's text, and why to check it.
    private struct Entry {
        let field: String
        let text: String
        let reason: String
    }

    // MARK: English words

    private let checkAndCopy = "Imported from your CV. Check every field before you send it. "
        + "Text that fits no field was not added; you can copy it."
    private let checkOnly = "Imported from your CV. Check every field before you send it."
    private let footer = "This text fits no field of the CV. Copy what you need into the editor."
    private let checkTitle = "Values to check"
    private let notImportedTitle = "Not imported"
    /// The values to check of `cvToCheckAndCopy`, in the order the import gives them.
    private let entries = [
        Entry(field: "Experience 1", text: "Analyst — Example Engines",
              reason: "Role and employer were told apart by their order: swap them if needed."),
        Entry(field: "Language 1 in your CV", text: "French — fluent",
              reason: "The level is not a CEFR level, so the language was not added. Add it with a CEFR level."),
    ]
    /// The lines of `cvToCheckAndCopy` that fit no field.
    private let notImported = "Leeds\nHobbies: chess\nsailing\nFrench — fluent"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The tests that run next start upright, also after a test that turned the device stopped on a failure.
    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: Notice

    /// The notice stands above the form, says what to check and what to copy, Review opens the sheet and Done closes
    /// it with the notice still there, and Dismiss ends the review.
    @MainActor
    func testNoticeLeadsToTheReview() throws {
        let app = importCV(cvToCheckAndCopy)
        let notice = element("import.review.notice", in: app)
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The imported draft opens with its notice")
        XCTAssertTrue(notice.staticTexts[checkAndCopy].exists, "The notice says what to check and what to copy")
        let name = textInput("editor.field.fullName", in: app)
        XCTAssertLessThanOrEqual(notice.frame.maxY, name.frame.minY + 1, "The notice stands above the form")

        openReview(in: app)
        let done = app.buttons["import.review.done"]
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 30), "Done closes the sheet")
        XCTAssertTrue(notice.exists, "The review goes on after the sheet")

        app.buttons["import.review.notice.dismiss"].tap()
        XCTAssertTrue(notice.waitForNonExistence(timeout: 30), "Dismiss ends the review")
    }

    /// The first edit stores the CV, and the review ends with it.
    @MainActor
    func testReviewEndsAfterTheFirstEdit() throws {
        let app = importCV(cvToCheckAndCopy)
        let notice = element("import.review.notice", in: app)
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The imported draft opens with its notice")

        let name = textInput("editor.field.fullName", in: app)
        app.scrollForm(until: name, named: "The name field")
        append(" Byron", to: name)

        XCTAssertTrue(notice.waitForNonExistence(timeout: 30), "The notice goes once the CV is stored")
        XCTAssertFalse(app.buttons["import.review.notice.review"].exists, "Review goes with it")
    }

    /// The notice says the CV was imported, whatever brought it: it names neither a pasted text nor a PDF.
    @MainActor
    func testNoticeNamesNoSource() throws {
        let app = importCV(cvToCheckAndCopy)
        let notice = element("import.review.notice", in: app)
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The imported draft opens with its notice")

        let texts = notice.staticTexts.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(texts.contains { $0.hasPrefix("Imported from your CV") }, "The notice reads \(texts)")
        for source in ["your text", "PDF"] {
            XCTAssertFalse(texts.contains { $0.localizedCaseInsensitiveContains(source) }, "The notice reads \(texts)")
        }
    }

    // MARK: Sheet

    /// The sheet lists the values to check in the import's order, then the text not imported, Copy all and the footer,
    /// each under its title. A CV whose every line fits a field shows no part for the text not imported.
    @MainActor
    func testReviewListsEntriesThenNotImported() throws {
        var app = importCV(cvToCheckAndCopy)
        openReview(in: app)
        scrollSheet(until: element("import.review.footer", in: app), named: "The footer", in: app)

        let ids = ["import.review.entry.1", "import.review.entry.2", "import.review.notImported", "import.review.copy",
                   "import.review.footer"]
        let read = app.descendants(matching: .any).matching(NSPredicate(format: "identifier IN %@", ids))
            .allElementsBoundByIndex.map(\.identifier)
        let order = read.reduce(into: [String]()) { order, id in if !order.contains(id) { order.append(id) } }
        XCTAssertEqual(order, ids, "The sheet reads the values to check, then the text not imported")
        XCTAssertFalse(element("import.review.entry.3", in: app).exists, "The import gave two values to check")
        for (index, entry) in entries.enumerated() {
            assertReads(element("import.review.entry.\(index + 1)", in: app), entry)
        }
        let check = heading(checkTitle, in: app)
        let notImportedHeading = heading(notImportedTitle, in: app)
        let text = element("import.review.notImported", in: app)
        XCTAssertTrue(check.exists && notImportedHeading.exists, "Each part of the sheet has its title")
        XCTAssertLessThanOrEqual(check.frame.maxY, element("import.review.entry.1", in: app).frame.minY + 1,
                                 "The values to check stand under their title")
        XCTAssertLessThanOrEqual(element("import.review.entry.2", in: app).frame.maxY,
                                 notImportedHeading.frame.minY + 1, "The text not imported comes after the values")
        XCTAssertLessThanOrEqual(notImportedHeading.frame.maxY, text.frame.minY + 1,
                                 "The text not imported stands under its title")
        XCTAssertEqual(text.label, notImported, "The text not imported is shown whole")
        XCTAssertEqual(element("import.review.footer", in: app).label, footer)

        app = importCV(cvToCheck)
        let notice = element("import.review.notice", in: app)
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The imported draft opens with its notice")
        XCTAssertTrue(notice.staticTexts[checkOnly].exists, "The notice says only what to check")
        openReview(in: app)
        XCTAssertTrue(element("import.review.entry.1", in: app).waitForExistence(timeout: 30))
        XCTAssertFalse(element("import.review.entry.2", in: app).exists, "The import gave one value to check")
        XCTAssertFalse(element("import.review.notImported", in: app).exists, "Every line fits a field")
        XCTAssertFalse(app.buttons["import.review.copy"].exists, "There is nothing to copy")
        XCTAssertFalse(heading(notImportedTitle, in: app).exists, "No title stands over an empty part")
    }

    /// Copy all turns to Copied and stays usable, and the text it copied is the one a paste brings into the import.
    /// The copy is read back through the import's paste button, as a person reads it: the test reading the pasteboard
    /// would ask the system to allow it.
    @MainActor
    func testCopyChangesToCopied() throws {
        let app = importCV(cvToCheckAndCopy)
        openReview(in: app)
        let copy = app.buttons["import.review.copy"]
        scrollSheet(until: copy, named: "Copy all", in: app)
        XCTAssertEqual(copy.label, "Copy all")

        copy.tap()
        XCTAssertTrue(waitUntil(copy, reads: "Copied"), "Copy all says the text was copied")
        XCTAssertTrue(copy.isEnabled, "The text can be copied again")
        copy.tap()
        XCTAssertTrue(waitUntil(copy, reads: "Copied"), "A second copy reads the same")

        let done = app.buttons["import.review.done"]
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 30), "Done closes the sheet")
        if isCompact(app) {
            XCTAssertTrue(app.backButton.waitForExistence(timeout: 30), "The bar holds \(app.barButtonIdentifiers)")
            app.backButton.tap()
        }
        let add = app.buttons["shell.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 30), "The list offers a new CV")
        add.tap()
        // The sheet's own: on a wide screen the empty list beside it offers the same choice
        let start = element("start.sheet", in: app).buttons["start.import"]
        XCTAssertTrue(start.waitForExistence(timeout: 30), "A new CV can be imported")
        start.tap()
        let paste = app.importPaste
        XCTAssertTrue(paste.waitForExistence(timeout: 30), "The import offers Paste")
        paste.tap()
        let pasted = expectation(for: NSPredicate(format: "value == %@", notImported), evaluatedWith: app.importBox)
        XCTAssertEqual(XCTWaiter().wait(for: [pasted], timeout: 30), .completed,
                       "The copy holds the text not imported: the box holds \(String(describing: app.importBox.value))")
    }

    // MARK: Room

    /// At the largest text size the notice takes at most a quarter of the editor and scrolls inside, the form stays in
    /// reach, and the sheet opens tall, with every part and action in reach and the actions as tall as a tap target.
    @MainActor
    func testReviewAtTheLargestTextSize() throws {
        let app = importCV(cvToCheckAndCopy, largestText: true)
        let editor = element("shell.detail.opened", in: app)
        let notice = app.scrollViews.containing(.any, identifier: "import.review.notice").firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The notice scrolls inside where the form is short of room")
        assertQuarterBelowTheBar(notice, of: editor, in: app)
        let review = app.buttons["import.review.notice.review"]
        guard scroll(notice, toShow: review, named: "Review", in: app) else { return }
        assertTall(review, named: "Review")
        app.scrollForm(until: textInput("editor.field.fullName", in: app), named: "The name field")
        guard scroll(notice, toShow: review, named: "Review", in: app) else { return }

        review.tap()
        let done = app.buttons["import.review.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 30), "Review opens the sheet")
        if isCompact(app) {
            let window = app.windows.firstMatch.frame
            XCTAssertLessThan(sheetBar(in: app).frame.minY, window.minY + window.height * 0.2,
                              "The sheet opens tall: one row would show at half the screen")
        }
        let parts = [("import.review.entry.1", "The first value"), ("import.review.entry.2", "The second value"),
                     ("import.review.notImported", "The text not imported"), ("import.review.copy", "Copy all"),
                     ("import.review.footer", "The footer")]
        for (identifier, name) in parts {
            scrollSheet(until: element(identifier, in: app), named: name, in: app)
        }
        assertTall(app.buttons["import.review.copy"], named: "Copy all")
        assertTakesATapInItsBand(done, named: "Done")
    }

    /// On an iPhone on its side the notice takes at most a quarter of the editor and scrolls inside, with Review in
    /// reach, and the form stays in reach below it. No picture is kept: a screenshot in landscape comes out upright.
    @MainActor
    func testNoticeScrollsInLandscape() throws {
        let app = importCV(cvToCheckAndCopy)
        try XCTSkipUnless(isCompact(app), "Only an iPhone has a compact height on its side")
        XCTAssertTrue(element("import.review.notice", in: app).waitForExistence(timeout: 30), "The notice shows")

        XCTAssertTrue(app.turn(to: .landscapeLeft), "The screen turned")
        XCTAssertEqual(app.windows.firstMatch.verticalSizeClass, .compact, "The iPhone turned")

        let editor = element("shell.detail.opened", in: app)
        let notice = app.scrollViews.containing(.any, identifier: "import.review.notice").firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The notice scrolls inside where the form is short of room")
        assertQuarterBelowTheBar(notice, of: editor, in: app)
        let review = app.buttons["import.review.notice.review"]
        guard scroll(notice, toShow: review, named: "Review", in: app) else { return }
        XCTAssertTrue(review.isHittable, "Review comes into view inside the notice")
        assertTall(review, named: "Review")
        app.scrollForm(until: textInput("editor.field.fullName", in: app), named: "The name field")
    }

    // MARK: VoiceOver

    /// The notice's actions say what they act on, each value to check is one element read as where, what and why, and
    /// both parts of the sheet have their titles.
    @MainActor
    func testReviewLabelsForVoiceOver() throws {
        let app = importCV(cvToCheckAndCopy)
        let review = app.buttons["import.review.notice.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 30), "The imported draft opens with its notice")
        XCTAssertEqual(review.label, "Review the import")
        XCTAssertEqual(app.buttons["import.review.notice.dismiss"].label, "Dismiss the import notice")

        openReview(in: app)
        for (index, entry) in entries.enumerated() {
            let row = element("import.review.entry.\(index + 1)", in: app)
            scrollSheet(until: row, named: entry.field, in: app)
            // XCUITest still lists the parts of a combined row; VoiceOver reads the row's one label
            assertReads(row, entry)
        }
        scrollSheet(until: element("import.review.footer", in: app), named: "The footer", in: app)
        XCTAssertTrue(heading(checkTitle, in: app).exists, "The values to check have their title")
        XCTAssertTrue(heading(notImportedTitle, in: app).exists, "The text not imported has its title")
        XCTAssertEqual(app.buttons["import.review.done"].label, "Done")
    }

    // MARK: Helpers

    /// Launches on an empty store, imports `text` from the first run, and waits for its draft in the editor.
    @MainActor
    private func importCV(_ text: String, largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage", "-PrestoCVNextReadyDesigns",
        ]
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        let start = app.buttons["start.import"]
        XCTAssertTrue(start.waitForExistence(timeout: 30), "The first run offers the import")
        start.tap()
        app.pasteInImport(text)
        app.scrollImport(until: app.importButton, named: "Import")
        app.importButton.tap()
        // At the largest text size the notice pushes the name below the screen, where the list makes no row yet
        let opened = largestText ? element("shell.detail.opened", in: app) : textInput("editor.field.fullName", in: app)
        XCTAssertTrue(opened.waitForExistence(timeout: 30), "The draft opens")
        return app
    }

    /// Opens the review's sheet from the notice.
    @MainActor
    private func openReview(in app: XCUIApplication) {
        let review = app.buttons["import.review.notice.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 30), "The notice offers Review")
        review.tap()
        XCTAssertTrue(app.buttons["import.review.done"].waitForExistence(timeout: 30), "Review opens the sheet")
    }

    /// The bar of the review's sheet, which holds Done.
    private func sheetBar(in app: XCUIApplication) -> XCUIElement {
        app.navigationBars.containing(.button, identifier: "import.review.done").firstMatch
    }

    /// Scrolls the sheet on, with slow drags under its bar, until the element can be tapped. A medium sheet grows to
    /// its full height on the first drag. The drags go only on: a drag down at the top of a sheet closes it.
    @MainActor
    private func scrollSheet(until element: XCUIElement, named name: String, in app: XCUIApplication) {
        for _ in 0..<12 where !element.canBeTapped(in: app) {
            let bar = sheetBar(in: app).frame
            let window = app.windows.firstMatch
            let origin = window.coordinate(withNormalizedOffset: .zero)
            let x = bar.midX - window.frame.minX
            let low = min(bar.maxY + 260, window.frame.maxY - 60) - window.frame.minY
            let high = bar.maxY + 60 - window.frame.minY
            // Held at the end, so the list does not glide on
            origin.withOffset(CGVector(dx: x, dy: low)).press(
                forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: x, dy: high)), withVelocity: .slow,
                thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(element.canBeTapped(in: app), "\(name) comes into view in the sheet")
    }

    /// A title of the sheet, found by its words: a list may show a section's title in capitals.
    private func heading(_ words: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", words)).firstMatch
    }

    /// The row is read as where the value is, the person's text, and why to check it, in that order.
    private func assertReads(_ row: XCUIElement, _ entry: Entry, file: StaticString = #filePath, line: UInt = #line) {
        let label = row.label
        let parts = [entry.field, entry.text, entry.reason].map { label.range(of: $0) }
        let starts = parts.compactMap { $0?.lowerBound }
        XCTAssertEqual(starts.count, 3, "\(entry.field) reads its place, its text and why: \(label)", file: file,
                       line: line)
        XCTAssertEqual(starts, starts.sorted(), "\(entry.field) reads where, what and why in order: \(label)",
                       file: file, line: line)
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

    private func isCompact(_ app: XCUIApplication) -> Bool {
        app.windows.firstMatch.horizontalSizeClass != .regular
    }

    @MainActor
    private func waitUntil(_ element: XCUIElement, reads label: String) -> Bool {
        let reads = expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
        return XCTWaiter().wait(for: [reads], timeout: 30) == .completed
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
        record.name = "Frames of the notice"
        record.lifetime = .keepAlways
        add(record)
        XCTAssertGreaterThan(room, 0, "The editor shows below the bar: \(frames)")
        XCTAssertLessThanOrEqual(shown, room * 0.25 + 1, "The notice takes at most a quarter of the editor: \(frames)")
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

    /// An action is at least as tall as the smallest tap target.
    private func assertTall(_ button: XCUIElement, named name: String) {
        XCTAssertTrue(button.waitForExistence(timeout: 30), "\(name) is there")
        XCTAssertGreaterThanOrEqual(button.frame.height, 43.99, "\(name) is at least 44 points tall")
    }

    /// A bar button of the system is drawn shorter than a tap target (36 points on an iPad), and the bar takes the taps
    /// around it: the button closes the sheet on a tap near the top of a 44-point band around its middle.
    @MainActor
    private func assertTakesATapInItsBand(_ button: XCUIElement, named name: String) {
        XCTAssertTrue(button.waitForExistence(timeout: 30), "\(name) is there")
        let reach = max(0, (44 - button.frame.height) / 2)
        // One point inside the band, since a frame comes as a float
        let top = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
        top.withOffset(CGVector(dx: 0, dy: 1 - reach)).tap()
        XCTAssertTrue(button.waitForNonExistence(timeout: 30),
                      "\(name) takes a tap \(reach - 1) points above its frame of \(button.frame.height) points")
    }

    /// Puts the cursor after the text of the field and types: a tap near its end, past the last word, and low in the
    /// field, on its last line where the field wraps.
    @MainActor
    private func append(_ text: String, to field: XCUIElement) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.9)).tap()
        field.typeText(text)
    }
}
