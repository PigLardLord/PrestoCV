import XCTest

/// The Diagnostics row of Settings and its screen (#405, ADR 0032). The row is there only on a TestFlight install, and the
/// screen lists the runs the app stored, shows the summary of the chosen one and offers its files to share. A UI test cannot
/// read the header trait of a title or the hint of a row: those are the view's, and a person tries them with VoiceOver.
final class DiagnosticsUITests: RuntimeIssueFailingTestCase {
    private let identity = "5B1C9E44-7A2D-4F60-8E13-2D9A6C0B7F35"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Launching

    private func seed() throws -> String {
        let cv = """
        {"schemaVersion":1,"id":"\(identity)","revision":1,
         "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"Site Electrician",
         "personal":{"fullName":"Tomas Verlaine","professionalTitle":"","location":"","summary":""},
         "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],"interests":[]}
        """
        return try JSONEncoder().encode(["\(identity).cv.json": cv]).base64EncodedString()
    }

    /// The app with Settings open, over a folder of the fixture. `distribution` is the store's answer: only `sandbox` (a
    /// TestFlight install) opens the gate. `traceRuns` stores two invented runs before the app starts.
    @MainActor
    private func openSettings(
        distribution: String, traceRuns: Bool = false, storage: [String] = ["-PrestoCVNextEmptyStorage"]
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += storage + ["-PrestoCVNextSeed", try seed(), "-PrestoCVNextDistribution", distribution]
        if traceRuns { app.launchArguments += ["-PrestoCVNextTraceRuns"] }
        app.launch()
        let gear = app.buttons["settings.open"]
        XCTAssertTrue(gear.waitForExistence(timeout: 30))
        gear.tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 30))
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The row, after swiping the sheet up until it shows: an iPad's form sheet may end above the last rows.
    private func reveal(_ row: XCUIElement, in app: XCUIApplication) -> XCUIElement {
        for _ in 0..<3 where !(row.exists && row.isHittable) {
            app.swipeUp()
        }
        return row
    }

    /// Opens the Diagnostics screen from the row.
    @MainActor
    private func openDiagnostics(in app: XCUIApplication) {
        let row = reveal(element("settings.diagnostics", in: app), in: app)
        XCTAssertTrue(row.isHittable)
        row.tap()
        XCTAssertTrue(app.navigationBars["Diagnostics"].waitForExistence(timeout: 30))
    }

    // MARK: The row

    /// On a TestFlight install the row is there, after the build, and opens the screen with its title and its notice.
    @MainActor
    func testDiagnosticsRowIsPresentOnATestFlightInstall() throws {
        let app = try openSettings(distribution: "sandbox")

        let row = reveal(element("settings.diagnostics", in: app), in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        XCTAssertEqual(row.label, "Diagnostics")
        let build = reveal(element("settings.build", in: app), in: app)
        XCTAssertLessThan(build.frame.minY, reveal(row, in: app).frame.minY, "The row comes after the build")

        openDiagnostics(in: app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "stays on your device")).firstMatch.exists)
    }

    /// On an App Store install the row is not there.
    @MainActor
    func testDiagnosticsRowIsAbsentOnAnAppStoreInstall() throws {
        let app = try openSettings(distribution: "production")

        XCTAssertTrue(reveal(element("settings.build", in: app), in: app).waitForExistence(timeout: 30))
        XCTAssertFalse(element("settings.diagnostics", in: app).exists)
    }

    /// When the store cannot say how the app was installed, the row is not there either: the gate fails closed.
    @MainActor
    func testDiagnosticsRowIsAbsentWhenTheInstallIsUnknown() throws {
        let app = try openSettings(distribution: "unknown")

        XCTAssertTrue(reveal(element("settings.build", in: app), in: app).waitForExistence(timeout: 30))
        XCTAssertFalse(element("settings.diagnostics", in: app).exists)
    }

    // MARK: The screen

    /// The two runs stored list newest first, the newest chosen, with its summary and the share in the bar. Choosing the
    /// other moves the choice, and the share is still there after the screen closes and opens again.
    @MainActor
    func testDiagnosticsListsTheDraftAndTheImportAndOffersAShare() throws {
        let app = try openSettings(distribution: "sandbox", traceRuns: true)
        openDiagnostics(in: app)

        let runs = app.buttons.matching(identifier: "diagnostics.run")
        XCTAssertTrue(runs.element(boundBy: 1).waitForExistence(timeout: 30))
        XCTAssertEqual(runs.count, 2)
        let draft = runs.element(boundBy: 0)
        let stored = runs.element(boundBy: 1)
        XCTAssertTrue(draft.label.contains("AI draft"), "The newest run is the draft: \(draft.label)")
        XCTAssertTrue(stored.label.contains("CV import"))
        XCTAssertTrue(draft.isSelected)
        XCTAssertFalse(stored.isSelected)
        XCTAssertFalse(element("diagnostics.summary", in: app).label.isEmpty)
        XCTAssertTrue(app.navigationBars.buttons["diagnostics.share"].waitForExistence(timeout: 30))

        stored.tap()
        XCTAssertTrue(stored.waitForExistence(timeout: 30))
        XCTAssertTrue(stored.isSelected)
        XCTAssertFalse(draft.isSelected)

        app.backButton.tap()
        openDiagnostics(in: app)
        XCTAssertTrue(app.navigationBars.buttons["diagnostics.share"].waitForExistence(timeout: 30))
    }

    /// A gate that is closed purges the runs: the app launched with them on an App Store install, and launched again on a
    /// TestFlight install over the same folder, has none to list. A launch with the runs shows its first screen only once
    /// the gate has purged them, so the first app may be ended as soon as Settings shows.
    @MainActor
    func testTheRunsOfAClosedGateAreGone() throws {
        let storage = ["-PrestoCVNextStorage", "closed-gate-\(UUID().uuidString)"]
        let closed = try openSettings(distribution: "production", traceRuns: true, storage: storage)
        XCTAssertTrue(reveal(element("settings.build", in: closed), in: closed).waitForExistence(timeout: 30))
        closed.terminate()

        let open = try openSettings(distribution: "sandbox", storage: storage)
        openDiagnostics(in: open)

        XCTAssertTrue(element("diagnostics.empty", in: open).waitForExistence(timeout: 30))
        XCTAssertFalse(element("diagnostics.run", in: open).exists)
    }
}
