import XCTest

/// An empty store is a first run: the app shows the welcome and the ways to start in place of the list, and a choice
/// opens a draft that nothing has stored. Once the store was used, "+" in the sidebar offers the same ways in a sheet.
final class FirstRunUITests: RuntimeIssueFailingTestCase {
    private let identity = "0F6E2B7A-3C59-4D8E-A1B2-7C4D5E6F8091"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The tests that run next start upright, also after a test that turned the device stopped on a failure.
    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: Launching

    @MainActor
    private func launch(seeded: Bool = false, largestText: Bool = false) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-PrestoCVNextEmptyStorage"]
        if seeded {
            app.launchArguments += ["-PrestoCVNextSeed", try seed()]
        }
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    /// One stored CV, so that the store was used and the list shows.
    private func seed() throws -> String {
        let cv = """
        {"schemaVersion":1,"id":"\(identity)","revision":1,
         "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"Site Electrician",
         "personal":{"fullName":"Tomas Verlaine","professionalTitle":"","location":"","summary":""},
         "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],"interests":[]}
        """
        return try JSONEncoder().encode(["\(identity).cv.json": cv]).base64EncodedString()
    }

    // MARK: Elements

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func isCompact(_ app: XCUIApplication) -> Bool {
        app.windows.firstMatch.horizontalSizeClass != .regular
    }

    /// The identifier that comes first in the order VoiceOver reads, of the two given. The order does not depend on
    /// how the screen is turned, as frames do.
    @MainActor
    private func firstOf(_ one: String, _ other: String, in app: XCUIApplication) -> String {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier IN %@", [one, other]))
            .firstMatch
            .identifier
    }

    // MARK: The welcome

    /// The welcome comes first and then the ways to start: the import, the examples, then blank last. The list does not
    /// show.
    @MainActor
    func testAnEmptyStoreShowsTheWelcomeAndTheWaysToStart() throws {
        let app = try launch()

        let title = element("firstRun.title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 30))
        let importing = app.buttons["start.import"]
        let examples = app.buttons["start.examples"]
        let blank = app.buttons["start.blank"]
        XCTAssertTrue(importing.exists)
        XCTAssertTrue(examples.exists)
        XCTAssertTrue(blank.exists)
        XCTAssertLessThan(importing.frame.minY, examples.frame.minY, "The import leads")
        XCTAssertLessThan(examples.frame.minY, blank.frame.minY, "Blank is last")
        XCTAssertEqual(firstOf("firstRun.title", "start.examples", in: app), "firstRun.title", "The welcome comes first")
        XCTAssertFalse(element("shell.sidebar.empty", in: app).exists)
        XCTAssertFalse(app.buttons["shell.add"].exists)
    }

    /// Blank opens a draft in the detail and the welcome goes. Nothing is stored: where the list shows beside the
    /// detail, it is empty.
    @MainActor
    func testBlankOpensADraftThatIsNotStored() throws {
        let app = try launch()
        let blank = app.buttons["start.blank"]
        XCTAssertTrue(blank.waitForExistence(timeout: 30))

        blank.tap()

        XCTAssertTrue(app.staticTexts["shell.detail.title"].waitForExistence(timeout: 30))
        XCTAssertFalse(element("firstRun.title", in: app).exists)
        if !isCompact(app) {
            XCTAssertTrue(element("shell.sidebar.empty", in: app).waitForExistence(timeout: 30), "Nothing was stored")
            XCTAssertFalse(element("shell.row", in: app).exists)
        }
    }

    /// The examples open in a sheet, each with its summary, above a footer that says the names are invented. Picking one
    /// closes the sheet and opens a draft.
    @MainActor
    func testAnExampleOpensADraft() throws {
        let app = try launch()
        let examples = app.buttons["start.examples"]
        XCTAssertTrue(examples.waitForExistence(timeout: 30))

        examples.tap()

        let rows = app.buttons.matching(identifier: "examples.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 30))
        XCTAssertGreaterThan(rows.count, 1)
        // A list makes only the rows on screen: on a small iPhone the footer is below the examples
        let footer = element("examples.footer", in: app)
        for _ in 0..<3 where !footer.exists {
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(footer.exists)
        // The last example is on screen beside the footer
        rows.element(boundBy: rows.count - 1).tap()

        XCTAssertTrue(app.staticTexts["shell.detail.title"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons.matching(identifier: "examples.row").firstMatch.exists)
        XCTAssertFalse(element("firstRun.title", in: app).exists)
    }

    /// Examples that cannot be read are said where their entry would be, and blank still starts a CV. The launch fixture
    /// points the examples at a folder that is not there.
    @MainActor
    func testExamplesThatCannotBeReadAreSaidAndBlankStays() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-PrestoCVNextEmptyStorage", "-PrestoCVNextNoSamples"]
        app.launch()

        let issue = element("start.examples.issue", in: app)
        XCTAssertTrue(issue.waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["start.examples"].exists)
        let blank = app.buttons["start.blank"]
        XCTAssertTrue(blank.isHittable)

        blank.tap()

        XCTAssertTrue(app.staticTexts["shell.detail.title"].waitForExistence(timeout: 30))
    }

    /// Cancel closes the examples and leaves the welcome, with nothing open.
    @MainActor
    func testCancelClosesTheExamples() throws {
        let app = try launch()
        let examples = app.buttons["start.examples"]
        XCTAssertTrue(examples.waitForExistence(timeout: 30))
        examples.tap()
        let cancel = app.buttons["examples.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 30))

        cancel.tap()

        XCTAssertTrue(examples.waitForExistence(timeout: 30))
        XCTAssertTrue(examples.isHittable)
        XCTAssertFalse(app.staticTexts["shell.detail.title"].exists)
    }

    // MARK: Text size and height

    /// At the largest text size the ways to start come before the welcome, and both can be tapped without scrolling.
    @MainActor
    func testTheWaysToStartComeFirstAtTheLargestTextSize() throws {
        let app = try launch(largestText: true)
        let examples = app.buttons["start.examples"]
        XCTAssertTrue(examples.waitForExistence(timeout: 30))

        XCTAssertEqual(firstOf("firstRun.title", "start.examples", in: app), "start.examples")
        XCTAssertTrue(examples.canBeTapped(in: app))
        XCTAssertTrue(app.buttons["start.blank"].canBeTapped(in: app))
    }

    /// In compact height, an iPhone turned on its side, the ways to start come first and can be tapped without scrolling.
    @MainActor
    func testTheWaysToStartComeFirstInCompactHeight() throws {
        let app = try launch()
        let examples = app.buttons["start.examples"]
        XCTAssertTrue(examples.waitForExistence(timeout: 30))
        try XCTSkipUnless(isCompact(app), "Only an iPhone has a compact height on its side")

        let turned = try app.turnsToLandscape()
        XCTAssertTrue(turned, "The first run turns with the device, as Safari does")

        XCTAssertTrue(examples.waitForExistence(timeout: 30))
        XCTAssertEqual(app.windows.firstMatch.verticalSizeClass, .compact, "The iPhone turned")
        XCTAssertEqual(firstOf("firstRun.title", "start.examples", in: app), "start.examples")
        XCTAssertTrue(examples.canBeTapped(in: app))
        XCTAssertTrue(app.buttons["start.blank"].canBeTapped(in: app))
    }

    // MARK: A regular screen

    /// On a regular screen the welcome stands in the middle at the readable width, and once a draft is open the list and
    /// the detail show side by side.
    @MainActor
    func testTheWelcomeIsCentredAndReadableOnARegularScreen() throws {
        let app = try launch()
        // Read by type: on iOS 26.5 XCUITest also lists the hidden words that WholeWordsText measures, as Other
        // elements with the title's identifier and no frame
        let title = app.staticTexts["firstRun.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 30))
        try XCTSkipIf(isCompact(app), "A compact screen is narrower than the readable width")

        let window = app.windows.firstMatch.frame
        let blank = app.buttons["start.blank"]
        XCTAssertEqual(title.frame.midX, window.midX, accuracy: 2)
        XCTAssertEqual(blank.frame.midX, window.midX, accuracy: 2)
        XCTAssertLessThanOrEqual(blank.frame.width, 560)

        blank.tap()

        XCTAssertTrue(app.staticTexts["shell.detail.title"].waitForExistence(timeout: 30))
        XCTAssertTrue(element("shell.sidebar.empty", in: app).waitForExistence(timeout: 30))
    }

    // MARK: Another CV

    /// Once the store was used, "+" offers the same ways to start in a sheet, without the welcome. Cancel closes it;
    /// a choice closes it and then opens the draft.
    @MainActor
    func testPlusOffersTheWaysToStartInASheet() throws {
        let app = try launch(seeded: true)
        let add = app.buttons["shell.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 30))
        XCTAssertFalse(element("firstRun.title", in: app).exists)

        add.tap()
        let cancel = app.buttons["start.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["start.examples"].exists)
        XCTAssertTrue(app.buttons["start.import"].exists)
        XCTAssertFalse(element("firstRun.title", in: app).exists)
        cancel.tap()
        XCTAssertTrue(add.waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["start.blank"].exists)

        add.tap()
        let blank = app.buttons["start.blank"]
        XCTAssertTrue(blank.waitForExistence(timeout: 30))
        blank.tap()

        XCTAssertTrue(app.staticTexts["shell.detail.title"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["start.blank"].exists)
    }
}
