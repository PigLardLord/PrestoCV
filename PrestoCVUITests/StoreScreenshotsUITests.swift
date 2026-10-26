import XCTest

/// The screenshots of the App Store listing: six screens in each language of the app, with the fictional people of
/// `StoreScreenshotFixture`, attached to the test results at the full resolution of the simulator.
///
/// It is in no test plan that CI runs: `Tools/Release/store-screenshots.sh` runs it through the `StoreScreenshots`
/// test plan, on a simulator erased for each language and with a fixed status bar, hands it the app's texts, and puts
/// the captions of `docs/release/store-listing.md` above the screenshots. Each attachment is named after the language
/// and the screen, as in `de-03`. Nothing waits for a fixed time: each screen is taken once the element it shows has
/// come to rest.
final class StoreScreenshotsUITests: XCTestCase {

    private var app: XCUIApplication?
    private var fixture = StoreScreenshotFixture.english
    private var strings: AppStrings?

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 900
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        app?.terminate()
        super.tearDown()
    }

    func testEnglish() throws { try captureTheScreens(in: "en") }
    func testGerman() throws { try captureTheScreens(in: "de") }
    func testItalian() throws { try captureTheScreens(in: "it") }
    func testSpanish() throws { try captureTheScreens(in: "es") }
    func testFrench() throws { try captureTheScreens(in: "fr") }
    func testPortuguese() throws { try captureTheScreens(in: "pt") }

    private func captureTheScreens(in language: String) throws {
        fixture = try XCTUnwrap(StoreScreenshotFixture.fixture(for: language), "No fixture for \(language)")
        strings = try AppStrings()
        try captureTheList()
        try captureTheAIDescription()
        try captureTheFactsOnly()
        try captureTheNewCVChoices()
        try captureTheExport()
    }

    // MARK: - Screens

    /// 1. The list: a complete CV and three copies adapted to other jobs, all on the device
    private func captureTheList() throws {
        let app = try launch(with: fixture.listFiles())
        let last = row(named: fixture.adaptations[fixture.adaptations.count - 1].name, in: app)
        XCTAssertTrue(last.waitForExistence(timeout: 30), "The list should show the CVs")
        attachScreenshot(1, showing: last)
    }

    /// 2. The AI screen with the person's description typed in and the keyboard closed
    private func captureTheAIDescription() throws {
        // The simulator cannot run the on-device model: the debug override offers the AI draft all the same
        let app = try launch(with: [:], arguments: ["-AIAvailabilityOverride", "available"])
        let start = app.buttons.matching(labeled(text("onboarding.ai.button"))).firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 30), "The first run should offer the AI draft")
        start.tap()

        let description = app.textViews.matching(labeled(text("ai.generation.prompt_section_title"))).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should have a description to type into")
        description.tap()
        description.typeText(fixture.description)
        closeTheKeyboard(in: app)
        app.swipeDown()
        // On a smaller screen the form goes up to show the whole of Generate, but no further than the collapse of the
        // large title: the heading of the screen stays below the navigation bar, not behind it. The descriptions are
        // short enough for both on every device.
        let generate = app.buttons.matching(labeled(text("ai.generation.button_title"), containing: true)).firstMatch
        let heading = app.staticTexts.matching(labeled(text("ai.generation.header_title"))).firstMatch
        XCTAssertTrue(generate.waitForExistence(timeout: 10), "The AI screen should offer to generate")
        waitUntilStill(generate)
        let hidden = generate.frame.maxY + 24 - app.frame.maxY
        if hidden > 0 {
            scroll(app, by: hidden)
            waitUntilStill(heading)
            let behindTheBar = app.navigationBars.firstMatch.frame.maxY + 8 - heading.frame.minY
            if behindTheBar > 0 {
                scroll(app, by: -behindTheBar)
                waitUntilStill(heading)
            }
        }
        XCTAssertGreaterThanOrEqual(heading.frame.minY, app.navigationBars.firstMatch.frame.maxY,
                                    "The heading should be below the navigation bar, not behind it")
        XCTAssertLessThanOrEqual(generate.frame.maxY, app.frame.maxY - 8,
                                 "Generate should be whole: the description is too long for this screen")
        attachScreenshot(2, showing: generate)
    }

    /// 3. A CV with only the facts of that description: what it does not mention is blank
    ///
    /// On both devices the fields of the first section hold the facts of the description (name, title, location),
    /// are blank where it says nothing (e-mail, phone, portfolio, and the summary with its hint), and are all in view.
    ///
    /// On iPhone the section bar floats over the lower part of the form, and the form is taller than the room between
    /// the bars. The form goes up until the heading of the first section, with the facts, sits just under the
    /// navigation bar (the one with the name of the CV and "Saved on this device"). Every fact and every blank field
    /// with its hint is then in view, down to the hint of the empty summary, which ends just above the section bar:
    /// the bar floats over the empty box of the summary. Behind the navigation bar there is only the name of the CV and
    /// its language, which the bar blurs, and no text is cut in two by the edge of either bar. The form moves with the
    /// push of the editor and with the scroll, so each position is read once the heading has stopped moving.
    private func captureTheFactsOnly() throws {
        let app = try launch(with: fixture.draftFiles())
        let draft = row(named: fixture.draftName, in: app)
        XCTAssertTrue(draft.waitForExistence(timeout: 30), "The list should show the CV")
        draft.tap()
        let location = app.textFields.matching(labeled(text("field.location"))).firstMatch
        XCTAssertTrue(location.waitForExistence(timeout: 10), "The editor should open on the CV")
        waitUntilStill(location)
        let form = app.collectionViews.firstMatch
        let heading = form.staticTexts.matching(labeled(text("section.personal_info"))).firstMatch
        XCTAssertTrue(heading.exists, "The editor should show the section with the facts")
        // On iPhone the section bar is at the bottom of the screen, over the form; on iPad it is not
        let sectionBar = app.tabBars.firstMatch
        let bottomBar = sectionBar.exists && sectionBar.frame.minY > app.frame.height / 2 ? sectionBar : nil
        if let bottomBar {
            // A point behind the edge of the bar: the heading has room above its text, and the hint of the summary
            // stays a few points over the section bar
            scroll(app, until: heading, isBelowTheNavigationBarBy: -1)
            assertNoText(of: form, under: bottomBar)
        }
        assertNoTextCut(of: form, byTheEdgeOf: app.navigationBars.firstMatch)
        let inView = CGRect(x: app.frame.minX, y: app.navigationBars.firstMatch.frame.maxY, width: app.frame.width,
                            height: (bottomBar?.frame.minY ?? app.frame.maxY) - app.navigationBars.firstMatch.frame.maxY)
        assertTheFacts(of: form, areInView: inView)
        attachScreenshot(3, showing: location)
    }

    /// 4. The ways to start a CV: import a CV, the AI draft, an example, or a blank CV, all of them offered. The
    /// simulator cannot run the on-device model, so the debug override offers the AI draft, as on a device with Apple
    /// Intelligence: the card is not dimmed, and does not say why it cannot be used.
    private func captureTheNewCVChoices() throws {
        let app = try launch(with: fixture.listFiles(), arguments: ["-AIAvailabilityOverride", "available"])
        XCTAssertTrue(row(named: fixture.completeName, in: app).waitForExistence(timeout: 30), "The list should show the CVs")
        app.navigationBars.buttons.firstMatch.tap()
        let example = app.buttons.matching(labeled(text("template.example.title"), containing: true)).firstMatch
        XCTAssertTrue(example.waitForExistence(timeout: 10), "The New CV screen should offer the examples")
        let aiDraft = app.buttons.matching(labeled(text("ai.card.title"), containing: true)).firstMatch
        XCTAssertTrue(aiDraft.exists, "The New CV screen should offer the AI draft")
        let announcement = aiDraft.value as? String ?? ""
        XCTAssertFalse(announcement.mentions(text("ai.entry.unavailable")),
                       "The AI draft should be live, not dimmed: it announces \"\(announcement)\"")
        XCTAssertTrue(aiDraft.label.mentions(text("ai.card.subtitle")),
                      "The AI draft should say what it does, not why it cannot: its label is \"\(aiDraft.label)\"")
        attachScreenshot(4, showing: example)
    }

    /// 5. The export sheet with its designs, then 6. the PDF in another font style, on its way to the share sheet
    private func captureTheExport() throws {
        let app = try launch(with: fixture.listFiles())
        let cv = row(named: fixture.completeName, in: app)
        XCTAssertTrue(cv.waitForExistence(timeout: 30), "The list should show the CVs")
        cv.tap()
        let export = app.buttons.matching(labeled(text("export.button.title"))).firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 10), "The editor should offer the export")
        export.tap()

        let send = app.buttons.matching(labeled(text("export.share"))).firstMatch
        XCTAssertTrue(send.waitForExistence(timeout: 30), "The export sheet should open")
        XCTAssertTrue(wait(until: send, isEnabled: true, timeout: 120), "The PDF should be ready")
        attachScreenshot(5, showing: send)

        app.buttons.matching(labeled(text("export.fonts.tab"))).firstMatch.tap()
        let serif = app.buttons.matching(labeled(text("export.font.serif"))).firstMatch
        XCTAssertTrue(serif.waitForExistence(timeout: 10), "The font styles should be offered")
        serif.tap()
        _ = wait(until: send, isEnabled: false, timeout: 5)
        XCTAssertTrue(wait(until: send, isEnabled: true, timeout: 120), "The PDF should be ready in the new font style")
        send.tap()
        let shareSheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 30), "The share sheet should open")
        attachScreenshot(6, showing: shareSheet)
    }

    // MARK: - Helpers

    private func text(_ key: String) -> String {
        strings?[key] ?? key
    }

    /// Matches a label in either of its Unicode forms: the labels of the app reach the test with their accents
    /// decomposed ("n" and a combining tilde for "ñ"), and a plain comparison tells the two forms apart.
    private func labeled(_ label: String, containing: Bool = false) -> NSPredicate {
        let comparison = containing ? "CONTAINS" : "=="
        return NSPredicate(format: "label \(comparison) %@ OR label \(comparison) %@",
                           label.precomposedStringWithCanonicalMapping, label.decomposedStringWithCanonicalMapping)
    }

    /// Starts the app in the fixture's language on a folder of its own holding `files`.
    private func launch(with files: [String: String], arguments: [String] = []) throws -> XCUIApplication {
        self.app?.terminate()
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(fixture.language))", "-AppleLocale", fixture.locale,
                               "-PrestoCVUITestsEmptyStorage"]
        if !files.isEmpty {
            app.launchArguments += ["-PrestoCVUITestsSeed", try JSONEncoder().encode(files).base64EncodedString()]
        }
        app.launchArguments += arguments
        app.launch()
        self.app = app
        return app
    }

    private func row(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(labeled(strings?.format("accessibility.navigate_to", name) ?? name)).firstMatch
    }

    /// Drags the content up by `distance` points, slowly and held at the end, so that it does not glide on.
    private func scroll(_ app: XCUIApplication, by distance: CGFloat) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let to = from.withOffset(CGVector(dx: 0, dy: -distance))
        from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.5)
    }

    /// Drags the form until the top of `element` is `gap` points under the navigation bar, give or take 3.
    ///
    /// A drag loses the first points of its travel before the form follows the finger, and a drag shorter than that
    /// moves nothing at all: a correction of a few points has to ask for more than it needs. The first long drag
    /// shows how many points are lost, and the next ones add them.
    private func scroll(_ app: XCUIApplication, until element: XCUIElement, isBelowTheNavigationBarBy gap: CGFloat) {
        var lost: CGFloat = 0
        for _ in 0..<4 {
            waitUntilStill(element)
            let before = element.frame.minY
            let error = before - (app.navigationBars.firstMatch.frame.maxY + gap)
            if abs(error) <= 3 { return }
            let drag = error > 0 ? error + lost : error - lost
            scroll(app, by: drag)
            waitUntilStill(element)
            let moved = (before - element.frame.minY) * (drag > 0 ? 1 : -1)
            lost = moved > 1 ? max(0, abs(drag) - moved) : lost + 5
        }
        waitUntilStill(element)
        let off = element.frame.minY - (app.navigationBars.firstMatch.frame.maxY + gap)
        XCTAssertLessThanOrEqual(abs(off), 3, "The form should stop \(gap) points under the navigation bar, and it is \(off) points off")
    }

    /// Fails if the lower edge of the bar cuts a text or a field of the form in two, by more than the 5 points of
    /// padding that a heading has around its text. What lies wholly under the bar has scrolled away, and the bar blurs
    /// it, but half a line under the bar reads as a mistake.
    private func assertNoTextCut(of form: XCUIElement, byTheEdgeOf bar: XCUIElement) {
        let edge = bar.frame.maxY
        let cut = (form.staticTexts.allElementsBoundByIndex + form.textFields.allElementsBoundByIndex)
            .filter { $0.frame.minY < edge - 5 && $0.frame.maxY > edge + 5 }
            .map(\.label)
        XCTAssertTrue(cut.isEmpty, "The navigation bar should cut no text, and it cuts \(cut)")
    }

    /// Fails if a text or a field of the form is under the bar, which would hide it
    private func assertNoText(of form: XCUIElement, under bar: XCUIElement) {
        let covered = (form.staticTexts.allElementsBoundByIndex + form.textFields.allElementsBoundByIndex)
            .filter { $0.frame.intersects(bar.frame) }
            .map(\.label)
        XCTAssertTrue(covered.isEmpty, "The section bar should cover no text, and it covers \(covered)")
    }

    /// Fails unless the first section of the editor holds the facts of the description, is blank where the description
    /// says nothing, and shows all of it inside `area`. An empty field shows its hint as its value, and the summary
    /// shows its hint as a text of its own over the editor, which is empty.
    private func assertTheFacts(of form: XCUIElement, areInView area: CGRect) {
        let facts = [("field.full_name", fixture.name), ("field.professional_title", fixture.draft.title),
                     ("field.location", fixture.draft.location)]
        for (key, expected) in facts {
            let field = form.textFields.matching(labeled(text(key))).firstMatch
            XCTAssertTrue(field.exists, "The editor should show \(key)")
            XCTAssertTrue((field.value as? String ?? "").isSameText(as: expected),
                          "\(key) should hold \"\(expected)\", and it holds \"\(field.value as? String ?? "nothing")\"")
            XCTAssertTrue(area.contains(field.frame), "\(key) should be in view: it is at \(field.frame), the room is \(area)")
        }
        for key in ["field.email", "field.phone", "field.portfolio_url"] {
            let field = form.textFields.matching(labeled(text(key))).firstMatch
            XCTAssertTrue(field.exists, "The editor should show \(key)")
            XCTAssertEqual(field.value as? String, field.placeholderValue,
                           "\(key) should be blank, and it holds \"\(field.value as? String ?? "nothing")\"")
            XCTAssertFalse(field.placeholderValue?.isEmpty ?? true, "\(key) should have a hint to show while it is blank")
            XCTAssertTrue(area.contains(field.frame), "\(key) should be in view: it is at \(field.frame), the room is \(area)")
        }
        let summaryHint = form.staticTexts.matching(labeled(text("field.professional_summary_placeholder"))).firstMatch
        XCTAssertTrue(summaryHint.exists, "The summary should be blank, with its hint")
        XCTAssertTrue(area.contains(summaryHint.frame),
                      "The hint of the summary should be in view: it is at \(summaryHint.frame), the room is \(area)")
        // The hint is a text of its own, there whether the summary is written or not: the editor under it holds the summary.
        // On iPhone the section bar floats over the upper part of the editor, so its value is checked and its place is not.
        let summary = form.textViews.firstMatch
        XCTAssertTrue(summary.exists, "The editor should show the summary")
        XCTAssertEqual(summary.value as? String ?? "", "",
                       "The summary should be blank, and it holds \"\(summary.value as? String ?? "nothing")\"")
    }

    private func closeTheKeyboard(in app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else { return }
        app.toolbars.buttons.matching(labeled(text("common.done"))).firstMatch.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed, "Done should close the keyboard")
    }

    private func wait(until element: XCUIElement, isEnabled: Bool, timeout: TimeInterval) -> Bool {
        let condition = expectation(for: NSPredicate(format: "isEnabled == %@", NSNumber(value: isEnabled)), evaluatedWith: element)
        return XCTWaiter().wait(for: [condition], timeout: timeout) == .completed
    }

    /// Waits until the element has stopped moving: its frame is the same on two reads in a row.
    private func waitUntilStill(_ element: XCUIElement, timeout: TimeInterval = 30) {
        var last = CGRect.null
        let still = NSPredicate { _, _ in
            guard element.exists else { return false }
            let frame = element.frame
            defer { last = frame }
            return frame == last
        }
        let rest = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: still, object: nil)], timeout: timeout)
        XCTAssertEqual(rest, .completed, "\(element) should come to rest")
    }

    /// Attaches the whole screen once the element it shows has come to rest.
    private func attachScreenshot(_ screen: Int, showing element: XCUIElement) {
        waitUntilStill(element)
        let attachment = XCTAttachment(
            uniformTypeIdentifier: "public.png",
            name: String(format: "%@-%02d", fixture.language, screen),
            payload: XCUIScreen.main.screenshot().pngRepresentation,
            userInfo: nil
        )
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension String {
    /// Whether `part` is in the text, in either of its Unicode forms (see `labeled(_:containing:)`).
    func mentions(_ part: String) -> Bool {
        precomposedStringWithCanonicalMapping.contains(part.precomposedStringWithCanonicalMapping)
    }

    /// Whether the two texts are the same, whichever of its Unicode forms each is in.
    func isSameText(as other: String) -> Bool {
        precomposedStringWithCanonicalMapping == other.precomposedStringWithCanonicalMapping
    }
}
