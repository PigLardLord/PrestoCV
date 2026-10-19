import XCTest

/// Where the AI draft cannot be made now, the "New CV" screen shows the AI card dimmed and last, with a line that says
/// why in place of what the card does; a tap shows the full explanation. The card fits the screen in German at the
/// largest text size.
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

    func testTheAICardIsDimmedLastAndExplainsWhileTheModelDownloads() throws {
        checkTheDimmedAICard(.modelNotReady)
    }

    func testTheAICardIsDimmedLastAndExplainsWhereAppleIntelligenceIsOff() throws {
        checkTheDimmedAICard(.appleIntelligenceNotEnabled)
    }

    func testTheAICardIsDimmedLastAndExplainsWhereTheDeviceCannotRunIt() throws {
        checkTheDimmedAICard(.deviceNotEligible)
    }

    func testTheAICardIsDimmedLastAndExplainsWhenTheReasonIsUnknown() throws {
        checkTheDimmedAICard(.unknown)
    }

    func testTheAICardThatIsDimmedFitsTheScreenInGermanAtTheLargestTextSize() throws {
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
        XCTAssertFalse(aiCard.isEnabled, "The AI card should be dimmed")
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(aiCard.frame.minX, screen.minX, "The AI card should not run off the left of the screen")
        XCTAssertLessThanOrEqual(aiCard.frame.maxX, screen.maxX, "The AI card should not run off the right of the screen")
        XCTAssertEqual(aiCard.value as? String, Self.notOnThisDeviceInGerman, "VoiceOver should read why, after the card")
        add(app.keptScreenshot(named: "New CV, German, largest text, device not eligible"))

        aiCard.tap()

        XCTAssertTrue(app.text(Self.notOnThisDeviceInGerman).waitForExistence(timeout: 10), "A tap should show the full explanation")
        add(app.keptScreenshot(named: "New CV, German, largest text, device not eligible, explanation"))
        app.navigationBars.buttons["Fertig"].tap()
    }

    /// The AI card is there, dimmed, after the cards that work, and a tap explains it.
    private func checkTheDimmedAICard(_ draft: DimmedAIDraft, file: StaticString = #filePath, line: UInt = #line) {
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage",
            "-AIAvailabilityOverride", draft.override,
        ]
        app.launch()
        app.openTheNewCVScreen()
        XCTAssertTrue(app.navigationBars["New CV"].waitForExistence(timeout: 10), "The New CV screen should open", file: file, line: line)

        let example = card("Example CV")
        XCTAssertTrue(example.waitForExistence(timeout: 10), "The New CV screen should offer the examples", file: file, line: line)
        let aiCard = card("AI CV Generation")
        XCTAssertTrue(aiCard.waitForExistence(timeout: 10), "The New CV screen should show the AI card", file: file, line: line)
        XCTAssertLessThan(example.frame.minY, aiCard.frame.minY, "The AI card should come last", file: file, line: line)

        app.checkDimmedAIDraft(aiCard, says: draft, file: file, line: line)
    }

    private static let notOnThisDeviceInGerman = "Dieses Gerät unterstützt keine KI-Entwürfe. "
        + "Sie können Ihren Lebenslauf selbst erstellen oder mit einem Beispiel beginnen."
}
