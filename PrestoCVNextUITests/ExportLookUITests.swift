import XCTest

/// The look of the PDF in the export sheet (#407). On a narrow screen one line, "Design", names the design, the fonts and
/// the colours in use, and a tap opens the picker in a sheet over the export; on a wide screen the picker sits among the
/// sheet's lines. A tap on an item chooses it at once, the PDF is made again, and the CV keeps the choice. A CV whose look
/// comes from an earlier version shows that choice as one more item, chosen, until another one replaces it.
final class ExportLookUITests: RuntimeIssueFailingTestCase {

    /// A CV the launch fixture stores before the app starts, in English, with its look: nil for a part the design sets.
    private struct StoredCV {
        let identity: String
        let title: String
        let design: String
        let palette: String?
        let fonts: String?
    }

    private let chosen = StoredCV(
        identity: "9E4C9F41-4EBF-4F4E-8A88-4C6E5FBE0D04", title: "Product Designer",
        design: "modern", palette: "ocean", fonts: "serif")
    private let designsOwn = StoredCV(
        identity: "AF5DA052-5FC0-4A5F-9B99-5D7F60CF1E05", title: "Nurse Practitioner",
        design: "modern", palette: nil, fonts: nil)
    private let earlier = StoredCV(
        identity: "B06EB163-60D1-4B60-8CAA-6E8071D02F06", title: "Sales Lead",
        design: "modern", palette: "sunset", fonts: "serif")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: A narrow screen

    @MainActor
    func testLineNamesTheLookAndOpensThePicker() throws {
        let app = try launch(chosen, largestText: false)
        try XCTSkipUnless(isCompact(app), "Only a narrow screen shows the look as one line")
        let line = try openExport(chosen, in: app)

        XCTAssertEqual(line.label, "Design", "VoiceOver reads what the line changes")
        XCTAssertEqual(line.value as? String, "Modern, Serif, Ocean", "The line names the look the CV keeps")
        XCTAssertFalse(element("look.design.modern", in: app).exists, "The picker waits for a tap on the line")
        keepScreenshot("The look as one line", of: app)

        line.tap()
        XCTAssertTrue(app.buttons["look.done"].waitForExistence(timeout: 10), "A tap opens the picker")
        XCTAssertTrue(app.buttons["look.design.modern"].isSelected, "The design in use is chosen")
        XCTAssertTrue(app.buttons["look.fonts.serif"].isSelected, "The fonts in use are chosen")
        XCTAssertFalse(app.buttons["look.design.minimal"].isSelected, "Only one design is chosen")
        XCTAssertTrue(reveal("look.palette.ocean", in: app).isSelected, "The colours in use are chosen")
        XCTAssertFalse(app.buttons["look.palette.plum"].isSelected, "Only one palette is chosen")
        XCTAssertFalse(element("look.footer.kept", in: app).exists, "Every choice of the CV is one the app offers")
        XCTAssertTrue(staysAtHalfTheHeight(app), "Scrolling to the colours leaves the sheet at half the height")
        keepScreenshot("The picker over the PDF", of: app)
    }

    @MainActor
    func testChoiceIsShownAtOnceAndKeptInTheCV() throws {
        let app = try launch(chosen, largestText: false)
        try XCTSkipUnless(isCompact(app), "Only a narrow screen shows the look as one line")
        let line = try openExport(chosen, in: app)
        line.tap()
        XCTAssertTrue(app.buttons["look.done"].waitForExistence(timeout: 10), "A tap opens the picker")

        let plum = reveal("look.palette.plum", in: app)
        plum.tap()
        XCTAssertTrue(wait(for: plum, toBeSelected: true), "The colour tapped is chosen at once")
        XCTAssertFalse(app.buttons["look.palette.ocean"].isSelected, "It replaces the colour chosen before")
        XCTAssertTrue(staysAtHalfTheHeight(app), "The PDF made again stays in view above the picker")
        keepScreenshot("Plum chosen", of: app)

        app.buttons["look.done"].tap()
        XCTAssertTrue(wait(for: line, toRead: "Modern, Serif, Plum"), "The line names the colour chosen")
        XCTAssertTrue(app.staticTexts["export.pages"].waitForExistence(timeout: 60), "The PDF is made again")

        let close = app.buttons["export.close"]
        close.tap()
        XCTAssertTrue(waitUntilGone(close), "Close takes the sheet away")
        app.buttons["editor.export"].tap()
        let again = app.buttons["export.look"]
        XCTAssertTrue(again.waitForExistence(timeout: 60), "The sheet shows the look again")
        XCTAssertEqual(again.value as? String, "Modern, Serif, Plum", "The CV keeps the colour chosen")
    }

    @MainActor
    func testDesignsOwnIsChosenWhenTheCVLeavesItToTheDesign() throws {
        let app = try launch(designsOwn, largestText: false)
        try XCTSkipUnless(isCompact(app), "Only a narrow screen shows the look as one line")
        let line = try openExport(designsOwn, in: app)

        XCTAssertEqual(line.value as? String, "Modern, Template’s own, Template’s own", "The design sets the fonts and colours")
        line.tap()
        XCTAssertTrue(app.buttons["look.done"].waitForExistence(timeout: 10), "A tap opens the picker")
        XCTAssertTrue(app.buttons["look.fonts.designsOwn"].isSelected, "The design's own fonts are chosen")
        let colours = reveal("look.palette.designsOwn", in: app)
        XCTAssertTrue(colours.isSelected, "The design's own colours are chosen")
        XCTAssertEqual(colours.label, "Template’s own", "VoiceOver reads the item's name")
        keepScreenshot("The design's own fonts and colours", of: app)
    }

    @MainActor
    func testChoiceFromAnEarlierVersionStaysUntilAnotherIsChosen() throws {
        let app = try launch(earlier, largestText: false)
        try XCTSkipUnless(isCompact(app), "Only a narrow screen shows the look as one line")
        let line = try openExport(earlier, in: app)

        XCTAssertEqual(line.value as? String, "Modern, Serif, From an earlier version", "The line names the kept colour")
        line.tap()
        XCTAssertTrue(app.buttons["look.done"].waitForExistence(timeout: 10), "A tap opens the picker")
        let kept = reveal("look.palette.kept", in: app)
        XCTAssertTrue(kept.isSelected, "The colour from an earlier version is chosen")
        XCTAssertEqual(kept.label, "From an earlier version", "VoiceOver reads where the colour comes from")
        XCTAssertTrue(element("look.footer.kept", in: app).exists, "The group says what choosing another one does")
        keepScreenshot("A colour from an earlier version", of: app)

        let ocean = reveal("look.palette.ocean", in: app)
        ocean.tap()
        XCTAssertTrue(wait(for: ocean, toBeSelected: true), "The colour tapped is chosen")
        XCTAssertTrue(waitUntilGone(kept), "The colour from an earlier version goes")
        XCTAssertFalse(element("look.footer.kept", in: app).exists, "Its line goes with it")
        app.buttons["look.done"].tap()
        XCTAssertTrue(wait(for: line, toRead: "Modern, Serif, Ocean"), "The line names the colour chosen")
    }

    @MainActor
    func testPickerAtTheLargestTextSize() throws {
        let app = try launch(chosen, largestText: true)
        try XCTSkipUnless(isCompact(app), "Only a narrow screen shows the look as one line")
        let line = try openExport(chosen, in: app)

        // The pages fill the screen at this size: the lines under them are reached by scrolling, from the page count
        app.staticTexts["export.pages"].swipeUp()
        XCTAssertTrue(line.isHittable, "The line can be tapped at the largest text size")
        keepScreenshot("The look as one line at the largest text size", of: app)
        line.tap()
        let done = app.buttons["look.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "A tap opens the picker")
        XCTAssertTrue(done.isHittable, "Done can be tapped at the largest text size")
        XCTAssertTrue(app.buttons["look.design.modern"].isSelected, "The picker shows the design in use")
        keepScreenshot("The picker at the largest text size", of: app)
    }

    // MARK: A wide screen

    @MainActor
    func testPickerSitsAmongTheLinesOnAWideScreen() throws {
        let app = try launch(chosen, largestText: false)
        try XCTSkipIf(isCompact(app), "Only a wide screen shows the picker among the lines")
        open(chosen, in: app)
        app.buttons["editor.export"].tap()
        XCTAssertTrue(app.staticTexts["export.pages"].waitForExistence(timeout: 60), "The sheet counts the pages")

        let modern = app.buttons["look.design.modern"]
        XCTAssertTrue(modern.waitForExistence(timeout: 10), "The picker is among the sheet's lines")
        XCTAssertFalse(app.buttons["export.look"].exists, "A wide screen needs no line to open it")
        XCTAssertTrue(modern.isSelected, "The design in use is chosen")
        let plum = reveal("look.palette.plum", in: app)
        keepScreenshot("The picker among the lines", of: app)
        plum.tap()
        XCTAssertTrue(wait(for: plum, toBeSelected: true), "The colour tapped is chosen at once")
        XCTAssertTrue(app.staticTexts["export.pages"].waitForExistence(timeout: 60), "The PDF is made again")

        let close = app.buttons["export.close"]
        close.tap()
        XCTAssertTrue(waitUntilGone(close), "Close takes the sheet away")
        app.buttons["editor.export"].tap()
        XCTAssertTrue(app.staticTexts["export.pages"].waitForExistence(timeout: 60), "The sheet counts the pages again")
        XCTAssertTrue(reveal("look.palette.plum", in: app).isSelected, "The CV keeps the colour chosen")
    }

    // MARK: Leaving, and the dark mode

    /// A look chosen in the sheet is stored by the sheet itself: closing it and going Back leaves nothing to discard,
    /// so nothing is asked.
    @MainActor
    func testChoosingALookAndGoingBackAsksNothing() throws {
        let app = try launch(chosen, largestText: false)
        let line = try openExport(chosen, in: app)
        if isCompact(app) {
            line.tap()
            XCTAssertTrue(app.buttons["look.done"].waitForExistence(timeout: 10), "A tap opens the picker")
        }
        let plum = reveal("look.palette.plum", in: app)
        plum.tap()
        XCTAssertTrue(wait(for: plum, toBeSelected: true), "The colour tapped is chosen at once")
        if isCompact(app) {
            app.buttons["look.done"].tap()
        }
        XCTAssertTrue(app.staticTexts["export.pages"].waitForExistence(timeout: 60), "The PDF is made again")

        let close = app.buttons["export.close"]
        close.tap()
        XCTAssertTrue(waitUntilGone(close), "Close takes the sheet away")
        if app.isCompactWidth {
            XCTAssertTrue(app.backButton.waitForExistence(timeout: 10), "The editor has its Back")
            app.backButton.tap()
        }

        XCTAssertTrue(app.listRow(titled: chosen.title).waitForExistence(timeout: 30), "The list shows the CV")
        XCTAssertEqual(app.alerts.count, 0, "Leaving asks nothing")
        XCTAssertEqual(app.sheets.count, 0, "Leaving shows no question")
        XCTAssertEqual(app.dialogs.count, 0, "Leaving shows no dialog")
    }

    /// The list, the editor and the sheet show in dark mode, each with what it holds.
    @MainActor
    func testLaunchesInDarkMode() throws {
        let app = try launch(chosen, largestText: false, darkMode: true)
        XCTAssertTrue(app.listRow(titled: chosen.title).waitForExistence(timeout: 30), "The list shows the CV in dark mode")
        keepScreenshot("The list in dark mode", of: app)
        open(chosen, in: app)
        XCTAssertEqual(app.textInput("editor.field.title").value as? String, chosen.title, "The editor shows the CV in dark mode")
        keepScreenshot("The editor in dark mode", of: app)
        app.buttons["editor.export"].tap()
        XCTAssertTrue(app.staticTexts["export.pages"].waitForExistence(timeout: 60), "The sheet counts the pages in dark mode")
        keepScreenshot("The sheet in dark mode", of: app)
    }

    // MARK: Launching

    /// A store folder of its own with the CV, in English.
    @MainActor
    private func launch(_ cv: StoredCV, largestText: Bool, darkMode: Bool = false) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVNextEmptyStorage",
            "-PrestoCVNextSeed", try seed(cv),
        ]
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        if darkMode {
            app.launchArguments += ["-AppleInterfaceStyle", "Dark"]
        }
        app.launch()
        return app
    }

    private func seed(_ cv: StoredCV) throws -> String {
        let palette = cv.palette.map { "\"\($0)\"" } ?? "null"
        let fonts = cv.fonts.map { "\"\($0)\"" } ?? "null"
        // The store reads a CV from the file named by its identity; its look is the design and the codes it keeps
        let file = """
        {"schemaVersion":1,"id":"\(cv.identity)","revision":1,
         "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"\(cv.title)",
         "personal":{"fullName":"Ines Vartan","professionalTitle":"","email":"ines.vartan@example.com",
                     "phone":"+49 30 3456789","location":"","summary":""},
         "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],"interests":[],
         "language":"en","design":{"design":"\(cv.design)","palette":\(palette),"fonts":\(fonts)}}
        """
        // The fixture takes a JSON map from file name to content, in base 64
        return try JSONEncoder().encode(["\(cv.identity).cv.json": file]).base64EncodedString()
    }

    /// Opens the stored CV from its row and waits for its form.
    @MainActor
    private func open(_ cv: StoredCV, in app: XCUIApplication) {
        let row = app.descendants(matching: .any).matching(identifier: "shell.row")
            .matching(NSPredicate(format: "label BEGINSWITH %@", cv.title + ", ")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The list shows \(cv.title)")
        row.tap()
        XCTAssertTrue(app.textFields["editor.field.title"].waitForExistence(timeout: 30), "The form of \(cv.title) opens")
    }

    /// Opens the CV's export and gives back the line of its look, once the PDF is made. The line is there on a narrow
    /// screen only.
    @MainActor
    private func openExport(_ cv: StoredCV, in app: XCUIApplication) throws -> XCUIElement {
        open(cv, in: app)
        app.buttons["editor.export"].tap()
        XCTAssertTrue(app.staticTexts["export.pages"].waitForExistence(timeout: 60), "The sheet counts the pages")
        let line = app.buttons["export.look"]
        // A wide screen shows the picker itself, not the line
        if isCompact(app) {
            XCTAssertTrue(line.waitForExistence(timeout: 10), "The sheet shows the look as one line")
        }
        return line
    }

    private func isCompact(_ app: XCUIApplication) -> Bool {
        app.windows.firstMatch.horizontalSizeClass != .regular
    }

    /// The picker's sheet stops at half the height, so the PDF above it stays in view (the owner's D1): its Done, at
    /// the top of the sheet, sits in the lower part of the window. At the full height it would sit near the top.
    private func staysAtHalfTheHeight(_ app: XCUIApplication) -> Bool {
        let window = app.windows.firstMatch.frame
        return app.buttons["look.done"].frame.minY > window.minY + window.height * 0.4
    }

    // MARK: Elements and waiting

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Scrolls the picker until the item can be tapped and gives it back. The items of a group are made as they come
    /// into view, so the colours, under the designs and the fonts, are not there until the picker is scrolled; the
    /// scroll view is the one that holds the picker's footer, the picker's own sheet or the export sheet on a wide screen.
    @MainActor
    private func reveal(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let item = app.buttons[identifier]
        let picker = app.scrollViews.containing(.any, identifier: "look.footer").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "The picker is on screen")
        for _ in 0..<6 where !(item.exists && item.isHittable) {
            picker.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(item.exists && item.isHittable, "\(identifier) can be tapped")
        return item
    }

    @MainActor
    private func wait(for element: XCUIElement, toRead value: String) -> Bool {
        let reads = expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: element)
        return XCTWaiter().wait(for: [reads], timeout: 30) == .completed
    }

    @MainActor
    private func wait(for element: XCUIElement, toBeSelected selected: Bool) -> Bool {
        let chosen = expectation(for: NSPredicate(format: "isSelected == %@", NSNumber(value: selected)), evaluatedWith: element)
        return XCTWaiter().wait(for: [chosen], timeout: 30) == .completed
    }

    @MainActor
    private func waitUntilGone(_ element: XCUIElement) -> Bool {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        return XCTWaiter().wait(for: [gone], timeout: 30) == .completed
    }

    @MainActor
    private func keepScreenshot(_ name: String, of app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
