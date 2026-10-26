import XCTest

/// VoiceOver reads the document language of the editor in one stop, as it read the system's picker: "Document
/// language, Automatic (English), pop-up button". The label is said once, on the control that opens the choice.
final class DocumentLanguageAccessibilityUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
        // The launch tests can leave the simulator in landscape
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage",
            "-AIAvailabilityOverride", "deviceNotEligible",
        ]
    }

    private func openANewCV(contentSize: String? = nil) {
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
    }

    func testTheEditorNamesTheDocumentLanguageOnceOnTheControlThatOpensTheChoice() throws {
        openANewCV()
        assertTheDocumentLanguageIsOneControlThatOpensTheChoice()
    }

    /// At the accessibility sizes the menu goes under the label, and the middle of the row is the label
    func testTheDocumentLanguageOpensTheChoiceAtTheLargestTextSize() throws {
        openANewCV(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        assertTheDocumentLanguageIsOneControlThatOpensTheChoice()
    }

    private func assertTheDocumentLanguageIsOneControlThatOpensTheChoice() {
        let named = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Document language"))
        XCTAssertTrue(named.firstMatch.waitForExistence(timeout: 10), "The editor should ask for the document language")
        XCTAssertEqual(named.count, 1, "VoiceOver should read the document language once, not as a text and then a button")

        let language = named.firstMatch
        XCTAssertEqual(language.elementType, .button, "The document language should be the control that opens the choice")
        XCTAssertEqual(language.value as? String, "Automatic (English)", "The control should say which language the CV is in")

        language.tap()
        XCTAssertTrue(app.buttons["Deutsch"].waitForExistence(timeout: 10), "The control should open the choice of the languages")
    }
}
