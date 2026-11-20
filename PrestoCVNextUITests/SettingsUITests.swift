import XCTest

/// Settings opens from the gear in the sidebar's bar as a sheet, and Done closes it. Its rows that leave the app are links,
/// and Licences opens the notices the app ships, each with its text.
final class SettingsUITests: RuntimeIssueFailingTestCase {
    private let identity = "5B1C9E44-7A2D-4F60-8E13-2D9A6C0B7F35"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Launching

    /// The app over one stored CV, so that the list and its bar show, with Settings open.
    @MainActor
    private func openSettings() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-PrestoCVNextEmptyStorage", "-PrestoCVNextSeed", try seed()]
        app.launch()
        let gear = app.buttons["settings.open"]
        XCTAssertTrue(gear.waitForExistence(timeout: 30))
        gear.tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 30))
        return app
    }

    private func seed() throws -> String {
        let cv = """
        {"schemaVersion":1,"id":"\(identity)","revision":1,
         "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"Site Electrician",
         "personal":{"fullName":"Tomas Verlaine","professionalTitle":"","location":"","summary":""},
         "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],"interests":[]}
        """
        return try JSONEncoder().encode(["\(identity).cv.json": cv]).base64EncodedString()
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func text(containing words: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    /// The row, after swiping the sheet up until it shows: an iPad's form sheet may end above the last rows, and a row
    /// below its end is not made until it shows.
    private func reveal(_ row: XCUIElement, in app: XCUIApplication) -> XCUIElement {
        for _ in 0..<3 where !(row.exists && row.isHittable) {
            app.swipeUp()
        }
        return row
    }

    // MARK: The sheet

    /// The gear opens Settings with its title, and Done closes it: the list and the gear show again.
    @MainActor
    func testTheGearOpensSettingsAndDoneClosesIt() throws {
        let app = try openSettings()

        XCTAssertTrue(app.navigationBars["Settings"].exists)
        let done = app.buttons["settings.done"]
        XCTAssertTrue(done.isHittable)
        done.tap()

        XCTAssertTrue(done.waitForNonExistence(timeout: 30))
        XCTAssertTrue(app.buttons["settings.open"].isHittable)
        XCTAssertTrue(element("shell.row", in: app).exists)
    }

    /// The rows come in the groups' order: support, privacy, the open-source statement, Licences, source code, version
    /// and build. Each row is below the one before it, unless that one has scrolled away above it.
    @MainActor
    func testTheRowsComeInTheGroupsOrder() throws {
        let app = try openSettings()

        var above: XCUIElement?
        for name in ["settings.contactSupport", "settings.privacy", "settings.openSource.statement", "settings.licences",
                     "settings.source", "settings.version", "settings.build"] {
            let row = reveal(element(name, in: app), in: app)
            XCTAssertTrue(row.isHittable, "\(name) shows")
            if let above, above.exists, above.isHittable {
                XCTAssertLessThan(above.frame.minY, row.frame.minY, "\(name) comes after the row before it")
            }
            above = row
        }
    }

    /// Contact support, Privacy policy and Source code leave the app, Licences stays in it. The address of support
    /// shows under its row. The privacy policy and the source code open in the browser: a link in a form row reaches
    /// the test as a button, so the browser coming forward is what shows that it leaves the app.
    @MainActor
    func testTheLinkRowsLeaveTheAppForTheBrowser() throws {
        let app = try openSettings()

        XCTAssertTrue(element("settings.contactSupport", in: app).isHittable)
        XCTAssertTrue(element("settings.support.footer", in: app).label.contains("support@prestocv.app"))
        XCTAssertTrue(app.buttons["settings.licences"].exists)
        let browser = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        for row in ["settings.privacy", "settings.source"] {
            let link = reveal(element(row, in: app), in: app)
            XCTAssertTrue(link.isHittable, "\(row) shows")
            link.tap()
            XCTAssertTrue(browser.wait(for: .runningForeground, timeout: 30), "\(row) opens the browser")
            app.activate()
            XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 30), "Settings is still open")
        }
    }

    /// Version and build each show a value after their name.
    @MainActor
    func testVersionAndBuildShowValues() throws {
        let app = try openSettings()

        for (row, name) in [("settings.version", "Version"), ("settings.build", "Build")] {
            let label = reveal(element(row, in: app), in: app).label
            XCTAssertTrue(label.hasPrefix(name), "\(row) reads \(label)")
            XCTAssertGreaterThan(label.count, name.count + 2, "\(row) has a value: \(label)")
        }
    }

    // MARK: Licences

    /// Licences lists the app's own notice with its licence, and says that nothing by others is included. The notice
    /// opens with its text, and Back returns to the list and then to Settings.
    @MainActor
    func testLicencesShowThePrestoCVNoticeAndItsText() throws {
        let app = try openSettings()
        app.buttons["settings.licences"].tap()

        let row = app.buttons["settings.licences.row.prestocv"]
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        XCTAssertTrue(row.label.contains("PrestoCV") && row.label.contains("Apache License 2.0"), row.label)
        XCTAssertTrue(element("settings.licences.noOthers", in: app).exists)

        row.tap()
        XCTAssertTrue(text(containing: "This product includes PrestoCV", in: app).waitForExistence(timeout: 30))
        XCTAssertTrue(app.navigationBars["PrestoCV"].exists)

        app.backButton.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        app.backButton.tap()
        XCTAssertTrue(app.buttons["settings.licences"].waitForExistence(timeout: 30))
    }
}
