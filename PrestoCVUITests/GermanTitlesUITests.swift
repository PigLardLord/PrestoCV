import XCTest
import UIKit

/// The titles the app gives its screens are whole in German, where the words are long: the bar cuts a title that
/// needs more room than it has to "…". The editor of a new CV used to read "Neuer Leben…", and the AI screen
/// "Lebenslauf mit KI erst…".
///
/// A cut title is drawn narrower than its text, so each check measures the text, in the font the bar draws it in,
/// against the width the bar gives it. VoiceOver reads the whole text either way, which is the text measured.
final class GermanTitlesUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(de)", "-AppleLocale", "de_DE", "-PrestoCVUITestsEmptyStorage",
            "-AIAvailabilityOverride", "available",
        ]
        app.launch()
    }

    /// Between Cancel and Save, at the normal text size.
    func testTheTitleOfANewCVIsWhole() throws {
        openANewCV()

        assertTheTitleIsWhole(font: Self.inlineTitleFont)
    }

    /// A CV that is saved without a name of its own or of the person in it.
    func testTheTitleOfACVWithoutANameIsWhole() throws {
        openANewCV()
        let jobTitle = app.textFields["Berufsbezeichnung"]
        XCTAssertTrue(jobTitle.waitForExistence(timeout: 10), "The editor should ask for the job title")
        jobTitle.tap()
        jobTitle.typeText("Pflegefachmann\n")
        app.navigationBars.buttons["Speichern"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Fertig"].waitForExistence(timeout: 10), "A saved CV should be left with Done")

        assertTheTitleIsWhole(font: Self.inlineTitleFont)
    }

    /// The large title above the description of the AI draft.
    func testTheTitleOfTheAIScreenIsWhole() throws {
        let aiDraft = app.buttons["Meinen Lebenslauf mit KI entwerfen"]
        XCTAssertTrue(aiDraft.waitForExistence(timeout: 20), "The first run should offer the AI draft")
        aiDraft.tap()
        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Ihr beruflicher Werdegang")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI draft should open the AI screen")

        assertTheTitleIsWhole(font: Self.largeTitleFont)
    }

    // MARK: - Helpers

    /// The title of a bar at the normal text size: the headline, semibold.
    private static let inlineTitleFont = UIFont.preferredFont(forTextStyle: .headline)
    /// A large title at the normal text size: the large title style, bold.
    private static let largeTitleFont = UIFont.systemFont(
        ofSize: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize, weight: .bold
    )

    private func openANewCV() {
        let start = app.buttons["Meinen ersten Lebenslauf erstellen"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first run should offer to create a CV")
        start.tap()
        XCTAssertTrue(app.navigationBars.buttons["Abbrechen"].waitForExistence(timeout: 10), "A new CV should offer to cancel")
    }

    /// The title of the bar, which the bar is named after, is drawn as wide as its text needs. A bar with a large
    /// title also holds the small one it shows once scrolled, so the widest of them is the one on screen.
    private func assertTheTitleIsWhole(font: UIFont, file: StaticString = #filePath, line: UInt = #line) {
        let bar = app.navigationBars.firstMatch
        let text = bar.identifier
        let titles = bar.staticTexts.matching(NSPredicate(format: "label == %@", text))
        XCTAssertTrue(titles.firstMatch.waitForExistence(timeout: 10), "The bar should show its title, \"\(text)\"", file: file, line: line)
        let drawn = titles.allElementsBoundByIndex.map(\.frame.width).max() ?? 0
        let needed = (text as NSString).size(withAttributes: [.font: font]).width
        XCTAssertGreaterThanOrEqual(
            drawn + 1, needed,
            "\"\(text)\" needs \(Int(needed.rounded())) points and is drawn in \(Int(drawn.rounded())): it is cut to \"…\"",
            file: file, line: line
        )
    }
}
