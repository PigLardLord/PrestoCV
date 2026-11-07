import UIKit
import XCTest

/// The AI screen can be used with VoiceOver, and with the keyboard up, and it waits for the language data a description needs.
/// A CV pasted whole is read as written, not drafted.
final class AIGenerationUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
        app = XCUIApplication()
        // The simulator cannot run the model: the debug override offers the AI card all the same
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage",
            "-AIAvailabilityOverride", "available",
        ]
    }

    /// Launches the app, with the debug launch arguments of the test, if any.
    private func launch(_ arguments: [String] = []) {
        app.launchArguments += arguments
        app.launch()
    }

    /// Opens the AI screen from the card of the "New CV" screen.
    private func openTheAIScreen() {
        app.openTheNewCVScreen()
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "AI CV Generation")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The New CV screen should offer AI drafting")
        card.tap()
    }

    func testTheDescriptionFieldIsNamedByTheTitleAboveIt() throws {
        launch()
        openTheAIScreen()

        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "VoiceOver should name the description field")
    }

    /// A text view has no Return key that closes the keyboard, and the keyboard covered Generate.
    func testGenerateCanBeReachedAfterTypingTheDescription() throws {
        launch()
        openTheAIScreen()
        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should have a description to type into")
        description.tap()
        description.typeText("I have been a nurse at San Camillo hospital in Rome since 2015.")
        XCTAssertTrue(description.waitForKeyboardFocus(true), "Typing should give the description the keyboard focus")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), XCUIApplication.noSoftwareKeyboard)

        let done = app.toolbars.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The keyboard should offer a Done button")
        done.tap()
        XCTAssertTrue(description.waitForKeyboardFocus(false), "Done should take the keyboard focus from the description")
        XCTAssertTrue(waitUntil(app.keyboards.firstMatch, exists: false), "Done should close the keyboard")

        let generate = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Generate CV with AI")).firstMatch
        app.scrollTo(generate)
        XCTAssertTrue(generate.isHittable, "Generate should be reachable once the keyboard is closed")
        XCTAssertTrue(generate.isEnabled, "Generate should be on for the description just typed")
    }

    /// Going back from the AI screen used to throw the description away.
    func testTheDescriptionIsStillThereAfterGoingBack() throws {
        launch()
        openTheAIScreen()
        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should have a description to type into")
        let typed = "I have been a nurse at San Camillo hospital in Rome since 2015."
        description.tap()
        description.typeText(typed)

        app.backButton.tap()
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "AI CV Generation")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Back should return to the New CV screen")
        card.tap()

        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should open again")
        XCTAssertEqual(description.value as? String, typed, "The description should be as it was left")
    }

    // MARK: - Language data (#270)

    /// An English description, which the device can ground only with the English language data.
    private let englishDescription = "I have worked at San Camillo in Roma since 2015. I use Excel every day."
    /// What the overlay that covers the screen says while the app waits for the data. Its loading view hides the message from
    /// accessibility as text, and is named with it, as VoiceOver reads it, in place of the "Processing..." that other screens show.
    private let waiting = "Getting the language data your description needs..."
    /// The note of the same overlay while the model writes. It would be false during the wait for the data, so it is not there.
    private let timeNote = "This can take up to a minute."
    private let endMessage = "This device cannot get the language data that drafts in English or German need."
    /// The notice says that the AI wrote the draft, and that the summary, the role descriptions and the skills are its suggestions
    /// (ADR 0031).
    private let reminder = "Draft written by AI from your description. The summary, the role descriptions and the skills are "
        + "suggestions"

    /// The device has no English data and the system never answers: the screen says that it waits for the data until the app's
    /// bound, then says what the person can do instead, and the screen can be used again. The simulator cannot run the model, and
    /// its language data is whatever it has: the debug launch arguments script both, and the bound of this launch is a few
    /// seconds, not the app's minute, which a unit test checks (`LanguageDataPreparationTests`).
    func testLanguageDataThatNeverArrivesEndsWithTheMessageAndTheScreenWorksAgain() throws {
        launch(["-PrestoCVUITestsScriptedDraft", "nurse", "-LanguageDataOverride", "neverArrives"])
        openTheAIScreenOnFirstRun()
        let generate = describeAndGenerate(englishDescription)

        let waitingScreen = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", waiting)).firstMatch
        XCTAssertTrue(waitingScreen.waitForExistence(timeout: 10), "The screen should say that it waits for the data, as VoiceOver reads it")
        XCTAssertFalse(app.staticTexts[timeNote].exists, "The model's minute does not hold while the app waits for the data")
        add(app.keptScreenshot(named: "Language data - waiting"))
        let alert = app.alerts["Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: 30), "The wait should end at its bound with a message")
        XCTAssertTrue(
            alert.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", endMessage)).firstMatch.exists,
            "The message should say that the device cannot get the data, and what to do instead"
        )
        add(app.keptScreenshot(named: "Language data - end message"))
        alert.buttons["OK"].tap()
        XCTAssertTrue(waitUntil(alert, exists: false), "OK should close the message")
        XCTAssertTrue(waitUntil(waitingScreen, exists: false), "The screen should no longer be busy")

        app.scrollTo(generate)
        XCTAssertTrue(generate.isEnabled, "Generate should be on again for the same description")
        generate.tap()
        XCTAssertTrue(waitingScreen.waitForExistence(timeout: 10), "Generate should start again")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(waitUntil(waitingScreen, exists: false), "Cancel should end the wait at once")
        XCTAssertFalse(alert.exists, "A cancelled wait shows no message")
    }

    /// The device has no English data until the app asks for it, and the system then gives it: the draft opens in the editor
    /// without another tap. The claim check fails, so the draft opens with the notice that says so and keeps the job.
    func testLanguageDataThatArrivesOpensTheDraftWithoutAnotherTap() throws {
        launch([
            "-PrestoCVUITestsScriptedDraft", "nurse", "-PrestoCVUITestsClaimCheck", "fail", "-LanguageDataOverride", "arrives",
        ])
        openTheAIScreenOnFirstRun()
        describeAndGenerate(englishDescription)

        let notice = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", reminder)).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The draft should open in the editor once the data has arrived")
        XCTAssertFalse(app.alerts.firstMatch.exists, "The arrived data should end in the draft, not in a message")
        add(app.keptScreenshot(named: "Language data - arrived, editor"))

        // The tab, wherever the device puts the tabs: a tab bar on an iPhone, the bar at the top of an iPad
        app.buttons["Experience"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "value == 'San Camillo'")).firstMatch
            .waitForExistence(timeout: 10), "The draft should hold the job of the description")
    }

    // MARK: - A CV pasted whole (#371)

    /// An invented CV, pasted whole as a person pastes the one they already have.
    private let pastedCV = """
        Marcus Hale
        Line Cook
        marcus.hale@example.com | +44 7700 900123
        Leeds, UK

        Summary
        Reliable cook with eight years in busy kitchens.

        Experience
        Line Cook, The Copper Pot, Leeds
        03/2019 – Present
        • Prepared mise en place for 120 covers a night
        • Trained two new commis chefs

        Commis Chef, Harbour Inn, Hull
        2016 – 2019
        • Made sauces and soups
        • Kept the cold room stocked

        Education
        Level 2 Diploma in Professional Cookery, Leeds College, 2016

        Skills
        Knife skills, Food safety, Stock control

        Languages
        English – Native
        Polish – B2
        """
    private let readAsWritten = "Your text was already a CV, so it was read as written."

    /// A CV pasted whole is read by the import and not drafted: the editor opens with the notice that says so, the duties as
    /// the person wrote them, and what to check. The launch scripts no draft, so a model asked for one fails the test: the
    /// simulator cannot run it.
    func testAPastedCVOpensAsWrittenWithWhatToCheck() throws {
        launch()
        openTheAIScreenOnFirstRun()
        pasteAsTheDescription(pastedCV).tap()

        let notice = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", readAsWritten)).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The pasted CV should open in the editor, read as written")
        XCTAssertFalse(app.alerts.firstMatch.exists, "A pasted CV asks no model, so no message comes")
        XCTAssertEqual(app.textFields["Full Name"].value as? String, "Marcus Hale")
        add(app.keptScreenshot(named: "Pasted CV - editor"))

        let review = app.buttons["editor.notice.review"]
        XCTAssertTrue(review.exists, "The notice should lead to what to check")
        review.tap()
        XCTAssertTrue(app.navigationBars["Check the import"].waitForExistence(timeout: 10), "The review should open")
        add(app.keptScreenshot(named: "Pasted CV - what to check"))
        app.buttons["Done"].tap()

        // The tab, wherever the device puts the tabs: a tab bar on an iPhone, the bar at the top of an iPad
        app.buttons["Experience"].firstMatch.tap()
        let duties = app.textViews.matching(NSPredicate(format: "label == %@", "Description")).firstMatch
        XCTAssertTrue(duties.waitForExistence(timeout: 10), "The first job should have its duties")
        app.scrollTo(duties)
        XCTAssertEqual(duties.value as? String, "• Prepared mise en place for 120 covers a night\n• Trained two new commis chefs",
                       "The first job's duties should be the pasted ones, word for word")
        add(app.keptScreenshot(named: "Pasted CV - experience"))
    }

    /// A free description over the limit is not a CV: Generate is on, and the AI draft refuses it with its own message, before
    /// the model is asked.
    func testAFreeDescriptionOverTheLimitIsRefusedWithItsMessage() throws {
        launch(["-PrestoCVUITestsScriptedDraft", "nurse"])
        openTheAIScreenOnFirstRun()
        let description = String(repeating: "I cook in a busy kitchen in Leeds and I train the new staff every week. ", count: 30)
        let generate = pasteAsTheDescription(description)

        XCTAssertTrue(app.staticTexts["\(description.count) of 2000 characters, over the limit"].exists,
                      "The counter should be read as words, with the text over the limit")
        XCTAssertTrue(generate.isEnabled, "Generate should be on over the limit")
        generate.tap()
        let alert = app.alerts["Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: 30), "A free description over the limit should end with a message")
        XCTAssertTrue(alert.staticTexts["That description is too long. Please shorten it and try again."].exists,
                      "The message should say the description is too long")
        alert.buttons["OK"].tap()
        XCTAssertTrue(waitUntil(alert, exists: false), "OK should close the message")
        XCTAssertTrue(generate.exists, "The screen should stay, with the description to shorten")
    }

    /// Pastes `text` as the description with the text view's own menu, as a person pastes a CV, closes the keyboard and returns
    /// Generate, in reach.
    private func pasteAsTheDescription(_ text: String) -> XCUIElement {
        UIPasteboard.general.string = text
        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should have a description to paste into")
        description.tap()
        XCTAssertTrue(description.waitForKeyboardFocus(true), "A tap should give the description the keyboard focus")
        // A tap on the caret of a focused text view opens its menu
        description.tap()
        let paste = app.menuItems["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 10), "The description's menu should offer to paste")
        paste.tap()
        XCTAssertEqual(description.value as? String, text, "The description should be the pasted text")
        let done = app.toolbars.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), XCUIApplication.noSoftwareKeyboard)
        done.tap()

        let generate = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Generate CV with AI")).firstMatch
        app.scrollTo(generate)
        return generate
    }

    /// Opens the AI screen from the first-run screen, which offers the AI draft when the model can run.
    private func openTheAIScreenOnFirstRun() {
        let aiDraft = app.buttons["Draft My CV with AI"]
        XCTAssertTrue(aiDraft.waitForExistence(timeout: 20), "The first-run screen should offer the AI draft")
        aiDraft.tap()
    }

    /// Types `text` as the description, closes the keyboard and taps Generate, which it returns.
    @discardableResult
    private func describeAndGenerate(_ text: String) -> XCUIElement {
        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should have a description to type into")
        description.tap()
        description.typeText(text)
        let done = app.toolbars.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), XCUIApplication.noSoftwareKeyboard)
        done.tap()

        let generate = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Generate CV with AI")).firstMatch
        app.scrollTo(generate)
        generate.tap()
        return generate
    }

    private func waitUntil(_ element: XCUIElement, exists: Bool, timeout: TimeInterval = 10) -> Bool {
        let condition = expectation(for: NSPredicate(format: "exists == %@", NSNumber(value: exists)), evaluatedWith: element)
        return XCTWaiter().wait(for: [condition], timeout: timeout) == .completed
    }
}
