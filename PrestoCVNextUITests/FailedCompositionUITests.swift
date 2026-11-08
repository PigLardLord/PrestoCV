import XCTest

/// A launch that cannot assemble the app shows one error screen with the failure's code and a retry. The launch argument
/// the app cannot read is the failure: it fails the same way at every launch, so a retry shows the screen again.
final class FailedCompositionUITests: XCTestCase {
    private let failedIdentifier = "root.failed.launchFixturesRejected"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchFailing(largestText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-PrestoCVNextStorage", "../outside"]
        if largestText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    private func screen(of app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: failedIdentifier).firstMatch
    }

    /// The screen names the failure by its code, and the retry launches again: the screen is there after the tap.
    @MainActor
    func testAFailedCompositionShowsItsCodeAndRetryShowsTheScreenAgain() throws {
        let app = launchFailing()
        XCTAssertTrue(screen(of: app).waitForExistence(timeout: 30))
        let code = app.staticTexts["error.code"]
        XCTAssertTrue(code.exists)
        XCTAssertTrue(code.label.hasSuffix("launchFixturesRejected"), code.label)

        let retry = app.buttons["error.retry"]
        XCTAssertTrue(retry.isHittable)
        retry.tap()

        XCTAssertTrue(screen(of: app).waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["error.code"].exists)
        XCTAssertTrue(app.buttons["error.retry"].waitForExistence(timeout: 30))
    }

    /// At the largest accessibility text size the retry stays reachable: the screen scrolls to it and it can be tapped.
    @MainActor
    func testTheRetryCanBeTappedAtTheLargestTextSize() throws {
        let app = launchFailing(largestText: true)
        XCTAssertTrue(screen(of: app).waitForExistence(timeout: 30))
        let retry = app.buttons["error.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 30))
        for _ in 0..<5 where !retry.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(retry.isHittable)

        retry.tap()

        XCTAssertTrue(screen(of: app).waitForExistence(timeout: 30))
    }
}
