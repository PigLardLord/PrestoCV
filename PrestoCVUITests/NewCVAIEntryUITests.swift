import XCTest

/// The "New CV" screen offers the import first, then the AI card, the examples and the empty CV. Where the AI draft
/// cannot be made now, the AI card is dimmed in the same place, with a line that says why in place of what the card
/// does; a tap shows the full explanation. The card fits the screen in German at the largest text size.
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

    func testTheAICardFollowsTheImportWhereTheDeviceCanDraft() throws {
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage",
            "-AIAvailabilityOverride", "available",
        ]
        app.launch()
        app.openTheNewCVScreen()
        XCTAssertTrue(app.navigationBars["New CV"].waitForExistence(timeout: 10), "The New CV screen should open")

        checkTheOrderOfTheCards()
    }

    func testTheAICardIsDimmedAfterTheImportAndExplainsWhileTheModelDownloads() throws {
        checkTheDimmedAICard(.modelNotReady)
    }

    func testTheAICardIsDimmedAfterTheImportAndExplainsWhereAppleIntelligenceIsOff() throws {
        checkTheDimmedAICard(.appleIntelligenceNotEnabled)
    }

    func testTheAICardIsDimmedAfterTheImportAndExplainsWhereTheDeviceCannotRunIt() throws {
        checkTheDimmedAICard(.deviceNotEligible)
    }

    func testTheAICardIsDimmedAfterTheImportAndExplainsWhenTheReasonIsUnknown() throws {
        checkTheDimmedAICard(.unknown)
    }

    func testVoiceControlAndSwitchControlCanOpenTheExplanation() throws {
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage",
            "-AIAvailabilityOverride", DimmedAIDraft.deviceNotEligible.override,
        ]
        app.launch()
        app.openTheNewCVScreen()
        let aiCard = card("AI CV Generation")
        XCTAssertTrue(aiCard.waitForExistence(timeout: 10), "The New CV screen should show the AI card")
        // The AI card is the second, and the import above it may leave it partly below the fold of an iPhone
        app.scrollTo(aiCard)

        app.activateAsAnAssistiveTechnology(aiCard, says: .deviceNotEligible)
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
        XCTAssertTrue(aiCard.isEnabled, "The dimmed AI card should still be activated to explain itself")
        let screen = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(aiCard.frame.minX, screen.minX, "The AI card should not run off the left of the screen")
        XCTAssertLessThanOrEqual(aiCard.frame.maxX, screen.maxX, "The AI card should not run off the right of the screen")
        XCTAssertEqual(aiCard.value as? String, "Nicht verfügbar. " + Self.notOnThisDeviceInGerman, "VoiceOver should read that it is unavailable, and why")
        add(app.keptScreenshot(named: "New CV, German, largest text, device not eligible"))

        aiCard.tap()

        XCTAssertTrue(app.text(Self.notOnThisDeviceInGerman).waitForExistence(timeout: 10), "A tap should show the full explanation")
        add(app.keptScreenshot(named: "New CV, German, largest text, device not eligible, explanation"))
        app.navigationBars.buttons["Fertig"].tap()
    }

    /// The cards of the screen, from the top: the import, the AI card, the examples, the empty CV.
    private func checkTheOrderOfTheCards(file: StaticString = #filePath, line: UInt = #line) {
        let inOrder = [
            ("the import", app.buttons["newcv.import"]), ("the AI card", card("AI CV Generation")),
            ("the examples", card("Example CV")), ("the empty CV", card("Empty CV")),
        ]
        for (name, element) in inOrder {
            XCTAssertTrue(element.waitForExistence(timeout: 10), "The New CV screen should offer \(name)", file: file, line: line)
        }
        for ((above, upper), (below, lower)) in zip(inOrder, inOrder.dropFirst()) {
            XCTAssertLessThan(upper.frame.minY, lower.frame.minY, "\(above) should come before \(below)", file: file, line: line)
        }
    }

    /// The AI card is there, dimmed, after the import and before the examples, and a tap explains it.
    private func checkTheDimmedAICard(_ draft: DimmedAIDraft, file: StaticString = #filePath, line: UInt = #line) {
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage",
            "-AIAvailabilityOverride", draft.override,
        ]
        app.launch()
        app.openTheNewCVScreen()
        XCTAssertTrue(app.navigationBars["New CV"].waitForExistence(timeout: 10), "The New CV screen should open", file: file, line: line)

        checkTheOrderOfTheCards(file: file, line: line)

        let aiCard = card("AI CV Generation")
        app.checkDimmedAIDraft(aiCard, says: draft, file: file, line: line)
    }

    private static let notOnThisDeviceInGerman = "Dieses Gerät unterstützt keine KI-Entwürfe. "
        + "Sie können Ihren Lebenslauf selbst erstellen oder mit einem Beispiel beginnen."
}
