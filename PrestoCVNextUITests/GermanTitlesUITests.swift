import UIKit
import XCTest

/// The titles the editor gives its bar are whole in German, where the words are long: the bar cuts a title that needs
/// more room than it has to "…". The editor of a new CV used to read "Neuer Leben…" (5-15c).
///
/// A cut title is drawn narrower than its text, so each check measures the text, in the font the bar draws it in,
/// against the width the bar gives it. VoiceOver reads the whole text either way, which is the text measured.
final class GermanTitlesUITests: RuntimeIssueFailingTestCase {

    /// `shell.draft.title` and `shell.untitled` in `PrestoCVNext/Resources/Localizable.xcstrings`, in German.
    private static let newCV = "Neuer Lebenslauf"
    private static let untitled = "Lebenslauf ohne Titel"

    private let nameless = "9D2C4B7E-5A1F-4E83-B6C0-2F7A8D9E1B34"

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
    }

    override func tearDown() async throws {
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
        try await super.tearDown()
    }

    // MARK: Tests

    /// A blank draft from the first run, at the normal text size: the title is the headline between Back and the
    /// export control.
    @MainActor
    func testTheTitleOfANewCVIsWhole() throws {
        let app = launchInGerman(arguments: ["-PrestoCVNextEmptyStorage"])
        let blank = app.buttons["start.blank"]
        XCTAssertTrue(blank.waitForExistence(timeout: 30), "The first run offers a blank CV")
        blank.tap()

        assertTheTitleIsWhole(Self.newCV, in: app)
    }

    /// A stored CV with no name of its own, no name of its person and no role: the list and the editor call it by the
    /// words for a CV without a title.
    @MainActor
    func testTheTitleOfACVWithoutANameIsWhole() throws {
        let json = XCUIApplication.storedCV(identity: nameless, title: "", person: "")
        let app = launchInGerman(arguments: [
            "-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", try XCUIApplication.seed(["\(nameless).cv.json": json]),
        ])
        let row = app.element("shell.row")
        XCTAssertTrue(row.waitForExistence(timeout: 30), "The list shows the CV without a name")
        row.tap()
        XCTAssertTrue(app.element("shell.detail.opened").waitForExistence(timeout: 30), "The editor of the CV opens")

        assertTheTitleIsWhole(Self.untitled, in: app)
    }

    // MARK: Helpers

    /// The title of a bar at the normal text size: the headline, semibold. The editor's bar has no line under it.
    private static let titleFont = UIFont.preferredFont(forTextStyle: .headline)

    @MainActor
    private func launchInGerman(arguments: [String]) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"] + arguments
        app.launch()
        return app
    }

    /// The title of the editor's bar is drawn as wide as its text needs: the bar that carries it is found by the text,
    /// which on a wide screen tells it from the sidebar's bar beside it.
    @MainActor
    private func assertTheTitleIsWhole(_ text: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let bar = app.navigationBars[text]
        XCTAssertTrue(bar.waitForExistence(timeout: 30), "The editor's bar is named \"\(text)\"", file: file, line: line)
        let titles = bar.staticTexts.matching(NSPredicate(format: "label == %@", text))
        XCTAssertTrue(titles.firstMatch.waitForExistence(timeout: 30), "The bar shows its title, \"\(text)\"", file: file, line: line)
        let drawn = titles.allElementsBoundByIndex.map(\.frame.width).max() ?? 0
        let needed = (text as NSString).size(withAttributes: [.font: Self.titleFont]).width
        XCTAssertGreaterThanOrEqual(
            drawn + 1, needed,
            "\"\(text)\" needs \(Int(needed.rounded())) points and is drawn in \(Int(drawn.rounded())): it is cut to \"…\"",
            file: file, line: line)
    }
}
