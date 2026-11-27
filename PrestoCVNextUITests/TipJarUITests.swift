import XCTest

/// The tip jar opens from Settings and shows what the store answers: three sizes with their prices, or the reason there
/// is nothing to show. A row buys nothing, and the fixture's store answers at once.
final class TipJarUITests: RuntimeIssueFailingTestCase {
    private let identity = "5B1C9E44-7A2D-4F60-8E13-2D9A6C0B7F35"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// One stored CV, so that the list and its gear show instead of the first-run page.
    private func seed() throws -> String {
        let cv = """
        {"schemaVersion":1,"id":"\(identity)","revision":1,
         "createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-02T00:00:00Z","title":"Site Electrician",
         "personal":{"fullName":"Tomas Verlaine","professionalTitle":"","location":"","summary":""},
         "experiences":[],"education":[],"skills":[],"languages":[],"certifications":[],"profiles":[],"interests":[]}
        """
        return try JSONEncoder().encode(["\(identity).cv.json": cv]).base64EncodedString()
    }

    /// The tip jar over the given answer of the store, open from Settings.
    @MainActor
    private func openTipJar(answer: String) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-PrestoCVNextEmptyStorage", "-PrestoCVNextReadyDesigns",
            "-PrestoCVNextSeed", try seed(), "-PrestoCVNextTips", answer,
        ]
        app.launch()
        let gear = app.buttons["settings.open"]
        XCTAssertTrue(gear.waitForExistence(timeout: 30))
        gear.tap()
        let row = app.buttons["settings.tips"]
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        row.tap()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// The three sizes show in order, each with the price the store gives.
    @MainActor
    func testTheOffersShowTheThreeSizesWithTheirPrices() throws {
        let app = try openTipJar(answer: "offers")

        XCTAssertTrue(app.navigationBars["Support PrestoCV"].waitForExistence(timeout: 30))
        for (size, name) in [("small", "Small tip"), ("medium", "Medium tip"), ("large", "Large tip")] {
            let row = element("settings.tips.row.\(size)", in: app)
            XCTAssertTrue(row.waitForExistence(timeout: 30), size)
            XCTAssertTrue(row.label.contains(name), row.label)
            XCTAssertTrue(row.label.contains("€"), row.label)
        }
        XCTAssertTrue(element("settings.tips.intro", in: app).exists)
    }

    /// A device that may not pay says so, and offers no new try.
    @MainActor
    func testWhenPurchasesAreOffTheScreenSaysSo() throws {
        let app = try openTipJar(answer: "notAllowed")

        XCTAssertTrue(element("settings.tips.notAllowed", in: app).waitForExistence(timeout: 30))
        XCTAssertFalse(element("settings.tips.row.small", in: app).exists)
        XCTAssertFalse(app.buttons["settings.tips.retry"].exists)
    }

    /// A store that cannot be reached, or answers no offer, or fails, offers a new try.
    @MainActor
    func testAFailureOffersANewTry() throws {
        for answer in ["unreachable", "noOffers", "failed"] {
            let app = try openTipJar(answer: answer)

            XCTAssertTrue(app.buttons["settings.tips.retry"].waitForExistence(timeout: 30), answer)
            XCTAssertFalse(element("settings.tips.row.small", in: app).exists, answer)
            app.terminate()
        }
    }
}
