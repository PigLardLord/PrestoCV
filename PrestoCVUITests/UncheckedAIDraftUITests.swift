import XCTest

/// When the second check of the AI draft cannot run, the draft opens without the personal items it could not check, and
/// the notice above the editor says which ones and asks the person to add them. VoiceOver reads the notice as one
/// element, and at the largest text size and in landscape it leaves the form on screen.
///
/// The simulator cannot run the model: the debug launch arguments script its answer for the nurse's description, and
/// make the check fail.
final class UncheckedAIDraftUITests: XCTestCase {

    private var app: XCUIApplication!

    /// The description the scripted model answers, as `AIDraftScript.nurseDescription` in the app.
    private let nurseDescription = "Sono infermiera presso San Camillo a Roma dal 2015. Uso Excel ogni giorno."
    private let reminder = "Draft written by AI from your description."
    private let unchecked = "We could not check your skills, languages, interests, job title and place, so they are left blank."

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 300
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(contentSize: String? = nil) {
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage",
            "-PrestoCVUITestsScriptedDraft", "nurse", "-PrestoCVUITestsClaimCheck", "fail",
        ]
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
    }

    /// Drafts the nurse's CV from the first-run screen and waits for the editor.
    private func draftTheNursesCV() {
        let aiDraft = app.buttons["Draft My CV with AI"]
        XCTAssertTrue(aiDraft.waitForExistence(timeout: 20), "The first-run screen should offer the AI draft")
        aiDraft.tap()

        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should have a description to type into")
        description.tap()
        description.typeText(nurseDescription)
        let done = app.toolbars.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), XCUIApplication.noSoftwareKeyboard)
        done.tap()

        let generate = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Generate CV with AI")).firstMatch
        app.scrollTo(generate)
        generate.tap()
    }

    /// The notice as VoiceOver reads it: one element that holds the reminder and the line on what is left blank.
    private var notice: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", reminder, unchecked))
            .firstMatch
    }

    func testTheUncheckedDraftSaysWhatIsLeftBlankAndKeepsTheJob() throws {
        launch()
        draftTheNursesCV()

        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The editor should say what could not be checked, in one element")
        add(app.keptScreenshot(named: "Unchecked AI draft - editor"))

        // The tab, wherever the device puts the tabs: a tab bar on an iPhone, the bar at the top of an iPad
        app.buttons["Experience"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "value == 'San Camillo'")).firstMatch
            .waitForExistence(timeout: 10), "The job is not one of the items left blank")
    }

    /// At the largest text size the two lines of the notice need many rows, and they must not push the form off the screen.
    func testTheUncheckedNoticeLeavesTheFormOnScreenAtTheLargestTextSize() throws {
        launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        draftTheNursesCV()

        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The editor should say what could not be checked, in one element")
        add(app.keptScreenshot(named: "Unchecked AI draft - largest text"))
        XCTAssertNil(whyTheNoticeCannotBeRead(), "The notice should be readable at the largest text size")

        XCTAssertNil(whyTheFirstFieldIsOutOfReach(), "The form should still be reachable below the notice")
        add(app.keptScreenshot(named: "Unchecked AI draft - largest text, form"))
    }

    /// In landscape the notice shares a short screen with the tabs and the form: it must still be there, in one element,
    /// and the form must still be reachable below it, at the normal text size and at the largest one.
    func testTheUncheckedNoticeLeavesTheFormOnScreenInLandscape() throws {
        try assertTheNoticeAndTheFormInLandscape(contentSize: nil, name: "Unchecked AI draft - landscape")
    }

    func testTheUncheckedNoticeLeavesTheFormOnScreenInLandscapeAtTheLargestTextSize() throws {
        try assertTheNoticeAndTheFormInLandscape(
            contentSize: "UICTContentSizeCategoryAccessibilityXXXL", name: "Unchecked AI draft - landscape, largest text"
        )
    }

    /// The draft is written in portrait, where the description is typed; the editor then turns to landscape with its notice.
    private func assertTheNoticeAndTheFormInLandscape(contentSize: String?, name shot: String) throws {
        launch(contentSize: contentSize)
        draftTheNursesCV()
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The editor should say what could not be checked, in one element")

        guard app.turn(to: .landscapeLeft) else {
            throw XCTSkip("This screen does not turn to landscape, as the outer screen of the iPhone Duo")
        }
        XCTAssertTrue(notice.waitForExistence(timeout: 10), "The notice should stay, in one element, in landscape")
        add(app.keptScreenshot(named: shot))
        XCTAssertNil(whyTheNoticeCannotBeRead(), "The notice should be readable in landscape")

        XCTAssertNil(whyTheFirstFieldIsOutOfReach(), "The form should still be reachable below the notice in landscape")
        add(app.keptScreenshot(named: shot + ", form"))
    }

    /// The shortest part of the notice that the box shows, in points: the height of a control that a finger can use, and about one
    /// line of the notice at the largest text size.
    private let shortestReadablePart: CGFloat = 44

    /// Why the notice cannot be read where it stands, or nil when it can. Either it is on the screen in full, or it is taller than
    /// the box the editor gives it where the form is short of room and scrolls in that box. The frame that the tests report for an
    /// element in a scrolling box is the frame of its whole content, which can reach below the screen, so it says nothing about what
    /// the box shows. The scroll view's own frame starts at the top of the screen, under the navigation bar, and ends where the form
    /// begins: the box shows the notice from where the notice starts down to there, and that must be a line of it, on the screen.
    private func whyTheNoticeCannotBeRead() -> String? {
        let screen = app.windows.firstMatch.frame.insetBy(dx: -1, dy: -1)
        let frame = notice.frame
        let boxes = app.scrollViews
            .containing(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", reminder, unchecked))
            .allElementsBoundByIndex.map(\.frame).sorted { $0.height < $1.height }
        let seen = "the notice \(frame), the window \(app.windows.firstMatch.frame), the scroll views around the notice \(boxes)"

        guard frame.minX >= screen.minX, frame.maxX <= screen.maxX else { return "The notice is not on the screen across: \(seen)" }
        guard !screen.contains(frame) else { return nil }
        guard let box = boxes.first else { return "The notice is not on the screen in full and is in no scroll view: \(seen)" }
        guard box.minY <= frame.minY + 1, box.maxY <= screen.maxY else { return "The box of the notice is not on the screen: \(seen)" }
        guard min(box.maxY, frame.maxY) - frame.minY >= shortestReadablePart else { return "The box shows less than a line of the notice: \(seen)" }
        return nil
    }

    /// Why the first field of the form cannot be put under a finger, or nil when it can. A short screen shows it below the notice
    /// and under the tab bar, or not at all, so the field is tried where it stands and then down the form, wherever on the screen
    /// it can be tapped. The answer is what each try saw.
    private func whyTheFirstFieldIsOutOfReach() -> String? {
        let name = app.textFields["Full Name"]
        var seen: [String] = []
        func reachable(_ when: String) -> Bool {
            let found = name.exists
            let field = found ? "frame \(name.frame), hittable \(name.isHittable)" : "not drawn"
            seen.append("\(when): the field is \(field), the window \(app.windows.firstMatch.frame), the notice \(notice.frame)")
            return found && name.isHittable
        }
        if reachable("where it stands") { return nil }
        app.scrollTo(name, toTheUpperHalf: false)
        if reachable("after scrolling down") { return nil }
        return seen.joined(separator: "; ")
    }
}
