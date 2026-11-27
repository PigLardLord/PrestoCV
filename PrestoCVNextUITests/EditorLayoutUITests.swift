import XCTest

/// Where the editor puts its export control (5-15c): in its bar, which stays while the form scrolls and while the person
/// types, once, in portrait and in landscape, with no bar below the form.
final class EditorLayoutUITests: RuntimeIssueFailingTestCase {

    private let engineer = (identity: "6B1F6C1E-1B8C-4C1B-9D55-1F3B2C8B7A01", title: "Backend Engineer")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: Tests

    /// On the open iPhone Duo the bar scrolled away with the form: the bar stays, whatever the form shows.
    @MainActor
    func testTheExportControlStaysInReachWhileTheFormScrolls() throws {
        let app = try launchAndOpen()
        let export = app.buttons["editor.export"]
        XCTAssertTrue(export.waitForExistence(timeout: 30), "The editor offers to preview and export")

        let summary = app.textInput("editor.field.summary")
        app.scrollForm(until: summary, named: "The summary")

        XCTAssertTrue(export.isHittable, "The export control stays in reach")
        if app.isCompactWidth {
            XCTAssertTrue(app.backButton.isHittable, "The Back button stays in reach")
        }
    }

    /// The keyboard takes the bottom of the screen, and the bar keeps the export control above it: the control is
    /// reached by a tap while a field has the keyboard, and the keyboard does not carry a bar of its own for it.
    @MainActor
    func testTheExportControlStaysInTheNavigationBarWhileTyping() throws {
        let app = try launchAndOpen()
        let title = app.textInput("editor.field.title")
        title.tap()
        XCTAssertTrue(title.waitUntilFocused(), "The field takes the keyboard")

        let export = app.navigationBars.buttons["editor.export"]
        XCTAssertTrue(export.exists, "The export control is in the navigation bar while the person types")
        XCTAssertTrue(export.isHittable, "The export control can be tapped while the person types")
        XCTAssertEqual(
            app.buttons.matching(identifier: "editor.export").count, 1, "The editor offers to preview and export only once")
    }

    /// A bar below the form took its height on every device: the export control sits in the navigation bar, in portrait
    /// and in landscape, on an iPhone and on an iPad. The outer screen of the iPhone Duo stays upright for every app,
    /// Safari too: there, only portrait is checked.
    @MainActor
    func testTheExportControlIsInTheNavigationBarInBothOrientations() throws {
        let app = try launchAndOpen()
        assertOneExportControlInTheNavigationBar(of: app, context: "in portrait")

        guard try app.turnsToLandscape() else {
            XCTFail("The screen should turn to landscape")
            return
        }
        assertOneExportControlInTheNavigationBar(of: app, context: "in landscape")

        XCTAssertTrue(app.turn(to: .portrait), "The screen should turn back to portrait")
        assertOneExportControlInTheNavigationBar(of: app, context: "back in portrait")
    }

    // MARK: Helpers

    /// The editor offers to preview and export once, in its bar, and leaves no bar below the form: the form reaches the
    /// bottom of the screen, save the strip of the home indicator, which is narrower than any button.
    @MainActor
    private func assertOneExportControlInTheNavigationBar(
        of app: XCUIApplication, context: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let barExport = app.navigationBars.buttons["editor.export"]
        XCTAssertTrue(
            barExport.waitForExistence(timeout: 10), "The bar offers to preview and export \(context)", file: file, line: line)
        XCTAssertEqual(
            app.buttons.matching(identifier: "editor.export").count, 1,
            "The editor offers to preview and export only once \(context)", file: file, line: line)
        let form = app.openForm
        XCTAssertTrue(form.exists, "The editor shows its form \(context)", file: file, line: line)
        let window = app.windows.firstMatch
        XCTAssertGreaterThan(
            form.frame.maxY, window.frame.maxY - 44, "Nothing sits below the form \(context)", file: file, line: line)
    }

    @MainActor
    private func launchAndOpen() throws -> XCUIApplication {
        let json = XCUIApplication.storedCV(identity: engineer.identity, title: engineer.title)
        let app = try XCUIApplication.seeded([(engineer.identity, json)])
        app.launch()
        app.openCV(titled: engineer.title)
        return app
    }
}
