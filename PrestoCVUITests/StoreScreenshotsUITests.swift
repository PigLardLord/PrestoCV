import XCTest

/// The screenshots of the App Store listing: six screens in each language of the app, with the fictional people of
/// `StoreScreenshotFixture`, attached to the test results at the full resolution of the simulator.
///
/// It is in no test plan that CI runs: `Tools/Release/store-screenshots.sh` runs it through the `StoreScreenshots`
/// test plan, on simulators with a fixed status bar, and puts the captions of `docs/release/store-listing.md` above
/// the screenshots. Each attachment is named after the language and the screen, as in `de-03`.
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
        strings = try AppStrings(language: language)
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
        XCTAssertTrue(row(named: fixture.completeName, in: app).waitForExistence(timeout: 30), "The list should show the CVs")
        attachScreenshot(1)
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
        // On a smaller screen the form goes up just enough to show the whole of Generate
        let generate = app.buttons.matching(labeled(text("ai.generation.button_title"), containing: true)).firstMatch
        XCTAssertTrue(generate.waitForExistence(timeout: 10), "The AI screen should offer to generate")
        let hidden = generate.frame.maxY + 24 - app.frame.maxY
        if hidden > 0 {
            scroll(app, by: hidden)
        }
        attachScreenshot(2)
    }

    /// 3. A CV with only the facts of that description: what it does not mention is blank
    private func captureTheFactsOnly() throws {
        let app = try launch(with: fixture.draftFiles())
        let draft = row(named: fixture.draftName, in: app)
        XCTAssertTrue(draft.waitForExistence(timeout: 30), "The list should show the CV")
        draft.tap()
        XCTAssertTrue(app.textFields.matching(labeled(text("field.full_name"))).firstMatch.waitForExistence(timeout: 10),
                      "The editor should open")
        // Where the tab bar floats over the blank contact fields, the form goes up: the personal details to the top, and
        // further where the last blank field would still be under the tab bar
        let portfolio = app.textFields.matching(labeled(text("field.portfolio_url"))).firstMatch
        XCTAssertTrue(portfolio.waitForExistence(timeout: 10), "The editor should have the portfolio field")
        let tabBar = app.tabBars.firstMatch
        let barTop = tabBar.exists ? tabBar.frame.minY : app.frame.height * 0.7
        if barTop > app.frame.height / 2 && portfolio.frame.maxY > barTop {
            let header = app.staticTexts.matching(labeled(text("section.personal_info"))).firstMatch
            XCTAssertTrue(header.waitForExistence(timeout: 5), "The editor should have the personal details")
            let toTheTop = header.frame.minY - app.navigationBars.firstMatch.frame.maxY
            let clearOfTheTabBar = portfolio.frame.maxY + 16 - barTop
            scroll(app, by: max(toTheTop, clearOfTheTabBar))
        }
        attachScreenshot(3)
    }

    /// 4. The ways to start a CV: blank or from an example. The AI draft has its own screenshot, so its card is left out,
    /// as on a device without Apple Intelligence.
    private func captureTheNewCVChoices() throws {
        let app = try launch(with: fixture.listFiles(), arguments: ["-AIAvailabilityOverride", "deviceNotEligible"])
        XCTAssertTrue(row(named: fixture.completeName, in: app).waitForExistence(timeout: 30), "The list should show the CVs")
        app.navigationBars.buttons.firstMatch.tap()
        let example = app.buttons.matching(labeled(text("template.example.title"), containing: true)).firstMatch
        XCTAssertTrue(example.waitForExistence(timeout: 10), "The New CV screen should offer the examples")
        attachScreenshot(4)
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
        attachScreenshot(5)

        app.buttons.matching(labeled(text("export.fonts.tab"))).firstMatch.tap()
        let serif = app.buttons.matching(labeled(text("export.font.serif"))).firstMatch
        XCTAssertTrue(serif.waitForExistence(timeout: 10), "The font styles should be offered")
        serif.tap()
        _ = wait(until: send, isEnabled: false, timeout: 5)
        XCTAssertTrue(wait(until: send, isEnabled: true, timeout: 120), "The PDF should be ready in the new font style")
        send.tap()
        // The share sheet is drawn by another process: it is given time to appear and settle
        Thread.sleep(forTimeInterval: 4)
        attachScreenshot(6)
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

    /// Attaches the whole screen once its animations are over.
    private func attachScreenshot(_ screen: Int) {
        Thread.sleep(forTimeInterval: 1.5)
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
