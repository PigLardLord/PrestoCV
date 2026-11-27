import XCTest

/// The tip jar opens from Settings and shows what the store answers: three sizes with their prices, or the reason there
/// is nothing to show. A row buys its tip, and the fixture's store answers the offers and the purchase at once, as the
/// launch argument gives (`-PrestoCVNextTips`): never through StoreKit, so these tests need no StoreKit configuration.
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

    /// The row of the small tip, once the offers show.
    @MainActor
    private func smallTip(in app: XCUIApplication) -> XCUIElement {
        let row = element("settings.tips.row.small", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        return row
    }

    /// The three offers are on screen and each can be chosen again.
    @MainActor
    private func assertTheOffersStay(in app: XCUIApplication, _ message: String) {
        for size in ["small", "medium", "large"] {
            let row = element("settings.tips.row.\(size)", in: app)
            XCTAssertTrue(row.exists, "\(message): \(size)")
            XCTAssertTrue(row.isEnabled, "\(message): \(size)")
        }
        XCTAssertFalse(app.buttons["settings.tips.retry"].exists, message)
    }

    /// A tip that goes through thanks the person above the offers, and the thank-you leaves with the screen.
    @MainActor
    func testATipThanksAndTheThankYouLeavesWithTheScreen() throws {
        let app = try openTipJar(answer: "offers")

        smallTip(in: app).tap()

        XCTAssertTrue(element("settings.tips.thanks", in: app).waitForExistence(timeout: 30))
        assertTheOffersStay(in: app, "after the thank-you")

        app.backButton.tap()
        let row = app.buttons["settings.tips"]
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        row.tap()
        XCTAssertTrue(smallTip(in: app).exists)
        XCTAssertFalse(element("settings.tips.thanks", in: app).exists, "The thank-you left with the screen")
    }

    /// A purchase the person cancels in the store's sheet leaves the offers as they were, with nothing said.
    @MainActor
    func testACancelKeepsTheOffers() throws {
        let app = try openTipJar(answer: "cancelled")

        smallTip(in: app).tap()

        assertTheOffersStay(in: app, "after a cancel")
        for notice in ["settings.tips.thanks", "settings.tips.pending", "settings.tips.purchaseFailed"] {
            XCTAssertFalse(element(notice, in: app).exists, notice)
        }
    }

    /// A purchase that waits for someone's approval says so, and the offers stay.
    @MainActor
    func testAPurchaseWaitingForApprovalSaysSo() throws {
        let app = try openTipJar(answer: "pending")

        smallTip(in: app).tap()

        XCTAssertTrue(element("settings.tips.pending", in: app).waitForExistence(timeout: 30))
        XCTAssertFalse(element("settings.tips.thanks", in: app).exists)
        assertTheOffersStay(in: app, "while the purchase waits")
    }

    /// A purchase that fails says it did not go through, and the offers stay for another try.
    @MainActor
    func testAFailedPurchaseSaysSoAndKeepsTheOffers() throws {
        let app = try openTipJar(answer: "purchaseFailed")

        smallTip(in: app).tap()

        XCTAssertTrue(element("settings.tips.purchaseFailed", in: app).waitForExistence(timeout: 30))
        XCTAssertFalse(element("settings.tips.thanks", in: app).exists)
        assertTheOffersStay(in: app, "after a failed purchase")
    }
}
