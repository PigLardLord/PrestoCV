import XCTest

/// On a device that cannot run the model, the "New CV" screen shows the AI card off, with the sentence that says why.
/// VoiceOver reads the sentence with the card, and the card fits the screen in German at the largest text size.
final class NewCVAIEntryUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 300
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
    }

    private func card(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
    }

    func testTheAICardIsOffAndSaysWhyWhereTheDeviceCannotRunIt() throws {
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage",
            "-AIAvailabilityOverride", "deviceNotEligible",
        ]
        app.launch()
        app.openTheNewCVScreen()
        XCTAssertTrue(app.navigationBars["New CV"].waitForExistence(timeout: 10), "The New CV screen should open")

        let example = card("Example CV")
        XCTAssertTrue(example.waitForExistence(timeout: 10), "The New CV screen should offer the examples")
        let aiCard = card("AI CV Generation")
        XCTAssertTrue(aiCard.exists, "The New CV screen should show the AI card on a device that cannot use it")
        XCTAssertLessThan(example.frame.minY, aiCard.frame.minY, "What works now should come first")
        XCTAssertFalse(aiCard.isEnabled, "The AI card should be off, and VoiceOver should read it as dimmed")
        XCTAssertEqual(aiCard.value as? String, Self.notOnThisDevice, "VoiceOver should read why, after the card")
        let sentence = app.staticTexts.matching(NSPredicate(format: "label == %@", Self.notOnThisDevice)).firstMatch
        XCTAssertFalse(sentence.exists, "VoiceOver should read the sentence once, with the card")
    }

    func testTheAICardThatIsOffFitsTheScreenInGermanAtTheLargestTextSize() throws {
        // A first launch saves a CV, so that the list of a later launch offers the New CV screen
        let storage = ["-PrestoCVUITestsStorage", UUID().uuidString, "-AIAvailabilityOverride", "deviceNotEligible"]
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + storage
        app.launch()
        app.openTheNewCVScreen()
        app.terminate()

        app.launchArguments = [
            "-AppleLanguages", "(de)", "-AppleLocale", "de_DE",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ] + storage
        app.launch()
        // The list's only button in the bar is the one that adds a CV
        let addCV = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(addCV.waitForExistence(timeout: 20), "The list should offer to add a CV")
        addCV.tap()

        XCTAssertTrue(app.navigationBars["Neuer Lebenslauf"].waitForExistence(timeout: 10), "The New CV screen should open")
        let aiCard = card("Lebenslauf mit KI erstellen")
        app.scrollTo(aiCard)

        XCTAssertTrue(aiCard.isHittable, "The AI card should be on screen once scrolled to")
        XCTAssertFalse(aiCard.isEnabled, "The AI card should be off")
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(aiCard.frame.minX, screen.minX, "The AI card should not run off the left of the screen")
        XCTAssertLessThanOrEqual(aiCard.frame.maxX, screen.maxX, "The AI card should not run off the right of the screen")
        XCTAssertEqual(aiCard.value as? String, Self.notOnThisDeviceInGerman, "VoiceOver should read why, after the card")
        add(app.keptScreenshot(named: "New CV, German, largest text, device not eligible"))
    }

    // MARK: - Sentences

    private static let notOnThisDevice = "This device doesn't support AI drafts. You can create your CV by hand or start from an example."

    private static let notOnThisDeviceInGerman = "Dieses Gerät unterstützt keine KI-Entwürfe. "
        + "Sie können Ihren Lebenslauf selbst erstellen oder mit einem Beispiel beginnen."
}
