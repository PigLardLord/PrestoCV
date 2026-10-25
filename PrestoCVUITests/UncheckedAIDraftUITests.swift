import XCTest

/// When the second check of the AI draft cannot run, the draft opens without the personal items it could not check, and
/// the notice above the editor says which ones and asks the person to add them. VoiceOver reads the notice as one
/// element, and at the largest text size it leaves the form on screen.
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
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(notice.frame.minY, screen.minY, "The notice should start on screen")

        let name = app.textFields["Full Name"]
        app.scrollTo(name)
        XCTAssertTrue(name.isHittable, "The form should still be reachable below the notice")
        add(app.keptScreenshot(named: "Unchecked AI draft - largest text, form"))
    }
}
