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

    /// Between Back and the export control, at the normal text size.
    func testTheTitleOfANewCVIsWhole() throws {
        openANewCV()

        assertTheTitleIsWhole(fonts: [Self.inlineTitleFont])
    }

    /// A CV that is saved without a name of its own or of the person in it. The line under the title says it is saved.
    func testTheTitleOfACVWithoutANameIsWhole() throws {
        openANewCV()
        let jobTitle = app.textFields["Berufsbezeichnung"]
        XCTAssertTrue(jobTitle.waitForExistence(timeout: 10), "The editor should ask for the job title")
        jobTitle.tap()
        jobTitle.typeText("Pflegefachmann\n")
        let saved = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Auf diesem Gerät gespeichert")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 10), "The editor should save the CV by itself")

        assertTheTitleIsWhole(fonts: [Self.subtitledTitleFont])
    }

    /// The large title above the description of the AI draft.
    func testTheTitleOfTheAIScreenIsWhole() throws {
        let aiDraft = app.buttons["Meinen Lebenslauf mit KI entwerfen"]
        XCTAssertTrue(aiDraft.waitForExistence(timeout: 20), "The first run should offer the AI draft")
        aiDraft.tap()
        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Ihr beruflicher Werdegang")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI draft should open the AI screen")

        assertTheTitleIsWhole(fonts: Self.largeTitleFonts)
    }

    // MARK: - Helpers

    /// The title of a bar at the normal text size: the headline, semibold.
    private static let inlineTitleFont = UIFont.preferredFont(forTextStyle: .headline)
    /// The title of a bar with a line under it: the subheadline size, semibold.
    private static let subtitledTitleFont = UIFont.systemFont(
        ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .semibold
    )
    /// A large title at the normal text size: the large title style, bold. A short screen, as the outer screen of the
    /// iPhone Duo, draws it smaller, in the size of the first title style.
    private static let largeTitleFonts = [UIFont.TextStyle.largeTitle, .title1].map {
        UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: $0).pointSize, weight: .bold)
    }

    private func openANewCV() {
        let start = app.buttons["Meinen ersten Lebenslauf erstellen"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first run should offer to create a CV")
        start.tap()
        XCTAssertTrue(app.backButton.waitForExistence(timeout: 10), "A new CV should go back to the list")
    }

    /// The title of the bar, which the bar is named after, is drawn as wide as its text needs. A bar with a large
    /// title also holds the small one it shows once scrolled, so the widest of them is the one on screen. Its text is
    /// measured in the one of `fonts` whose line height is closest to the height of the title: a title takes one line,
    /// since the bar cuts one that does not fit.
    private func assertTheTitleIsWhole(fonts: [UIFont], file: StaticString = #filePath, line: UInt = #line) {
        let bar = app.navigationBars.firstMatch
        let text = bar.identifier
        let titles = bar.staticTexts.matching(NSPredicate(format: "label == %@", text))
        XCTAssertTrue(titles.firstMatch.waitForExistence(timeout: 10), "The bar should show its title, \"\(text)\"", file: file, line: line)
        let shown = titles.allElementsBoundByIndex.map(\.frame).max { $0.width < $1.width } ?? .zero
        let font = fonts.min { abs($0.lineHeight - shown.height) < abs($1.lineHeight - shown.height) } ?? fonts[0]
        let drawn = shown.width
        let needed = (text as NSString).size(withAttributes: [.font: font]).width
        XCTAssertGreaterThanOrEqual(
            drawn + 1, needed,
            "\"\(text)\" needs \(Int(needed.rounded())) points and is drawn in \(Int(drawn.rounded())): it is cut to \"…\"",
            file: file, line: line
        )
    }
}
