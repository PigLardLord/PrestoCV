import XCTest

/// The helpers the screens' tests share to scroll the form and to say where an element lies (5-15c): `place(in:)` reads
/// where the middle of an element is against the window, `canBeTapped(in:)` adds that a tap would reach it,
/// `tapRoom(in:)` is the part of the form a tap lands on, clear of the bar, the keyboard and the Done button over it, and
/// `scrollForm` fails the test where it cannot bring the element into that room.
final class ScreenHelpersUITests: RuntimeIssueFailingTestCase {

    private let engineer = (identity: "6B1F6C1E-1B8C-4C1B-9D55-1F3B2C8B7A01", title: "Backend Engineer")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Tests

    /// With the keyboard up, a field the form brings into view lies in the room the form leaves for a tap, clear of the
    /// keyboard and of the Done button over it where they show (a simulator with a hardware keyboard shows none), and a
    /// tap on it gives it the keyboard. XCTest's own `isHittable` said yes for the field under the Done button's strip,
    /// where the tap reached nothing.
    @MainActor
    func testAnElementThatFitsIsWhollyBetweenTheBarAndTheKeyboard() throws {
        let app = try launchAndOpen(largestText: true)
        let title = app.textInput("editor.field.title")
        title.tap()
        XCTAssertTrue(title.waitUntilFocused(), "The first field takes the keyboard")

        let website = app.textInput("editor.field.website")
        app.scrollForm(until: website, named: "The website")

        XCTAssertEqual(website.place(in: app), .inside, "The field is inside the window")
        XCTAssertTrue(website.canBeTapped(in: app), "A tap reaches the field")
        let bar = app.navigationBars.firstMatch
        XCTAssertGreaterThanOrEqual(website.frame.midY, bar.frame.maxY, "The field is not under the bar")
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists {
            XCTAssertLessThan(website.frame.midY, keyboard.frame.minY, "The field is not under the keyboard")
        }
        let done = app.buttons["keyboard.done"]
        if done.exists {
            XCTAssertLessThan(website.frame.midY, done.frame.minY, "The field is not under the Done button")
        }
        XCTAssertEqual(website.place(within: app.tapRoom(in: app.openForm)), .inside,
                       "The field lies in the room the form leaves for a tap")

        website.tap()
        XCTAssertTrue(website.waitUntilFocused(), "A tap on the field gives it the keyboard")
    }

    /// Without the keyboard, a field far down the form is brought inside the window, below the bar.
    @MainActor
    func testWithoutTheKeyboardAnElementComesToTheUpperHalf() throws {
        let app = try launchAndOpen(largestText: true)
        XCTAssertFalse(app.keyboards.firstMatch.exists, "The form opens with the keyboard down")

        let summary = app.textInput("editor.field.summary")
        app.scrollForm(until: summary, named: "The summary")

        XCTAssertEqual(summary.place(in: app), .inside, "The field is inside the window")
        XCTAssertTrue(summary.canBeTapped(in: app), "A tap reaches the field")
        XCTAssertGreaterThanOrEqual(
            summary.frame.midY, app.navigationBars.firstMatch.frame.maxY, "The field is not under the bar")
    }

    /// An element that is not in the app is nowhere, and no tap reaches it.
    @MainActor
    func testAnElementThatIsNotInTheAppIsNeverInReach() throws {
        let app = try launchAndOpen(largestText: false)
        let missing = app.buttons["An element that is not in the app"]

        XCTAssertEqual(missing.place(in: app), .missing, "An element that is not there has no place")
        XCTAssertFalse(missing.canBeTapped(in: app), "A tap cannot reach it")
    }

    /// A scroll that ends without the element where a tap lands on it fails the test, instead of letting the next tap
    /// land elsewhere.
    @MainActor
    func testAScrollThatCannotReachTheElementFailsTheTest() throws {
        let app = try launchAndOpen(largestText: false)

        // Only the failure of the scroll is expected: any other, as a drag that fails, fails the test
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { $0.compactDescription.contains("comes into view") }
        XCTExpectFailure("The element is not in the app", options: options) {
            app.scrollForm(until: app.buttons["An element that is not in the app"], named: "The element")
        }
    }

    // MARK: Launching

    @MainActor
    private func launchAndOpen(largestText: Bool) throws -> XCUIApplication {
        let json = XCUIApplication.storedCV(identity: engineer.identity, title: engineer.title)
        let app = try XCUIApplication.seeded([(engineer.identity, json)], largestText: largestText)
        app.launch()
        app.openCV(titled: engineer.title)
        return app
    }
}
