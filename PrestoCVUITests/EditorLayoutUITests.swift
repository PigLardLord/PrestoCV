import XCTest

/// The editor leaves room for what is typed, at the normal text size and at the largest one.
final class EditorLayoutUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 240
    }

    private func launch(contentSize: String? = nil) {
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage"]
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
    }

    /// An address such as maria.rossi@example-hospital.org needs about this much room at the normal text size.
    func testEmailAndPhoneEachGetRoomForALongEntry() throws {
        launch()
        let email = app.textFields["Email"]
        let phone = app.textFields["Phone"]
        var scrolls = 0
        while !(email.isHittable && phone.isHittable) && scrolls < 8 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertGreaterThanOrEqual(email.frame.width, 250, "The email field should not be squeezed into half a row")
        XCTAssertGreaterThanOrEqual(phone.frame.width, 250, "The phone field should not be squeezed into half a row")
    }

    /// At the largest text size the export button used to take a fifth of the screen.
    func testTheExportButtonDoesNotTakeTheScreenAtTheLargestTextSize() throws {
        launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        let export = app.buttons["Preview & export"]
        XCTAssertTrue(export.waitForExistence(timeout: 10), "The editor should offer to preview and export")
        XCTAssertLessThanOrEqual(export.frame.height, app.frame.height * 0.12, "The export button should keep a readable, bounded size")
    }

    /// At the largest text size an address needs several lines, and a field that keeps to one would cut it off.
    func testAFieldGrowsToShowALongEntryAtTheLargestTextSize() throws {
        launch(contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        let email = app.textFields["Email"]
        app.scrollTo(email)
        let heightBefore = email.frame.height
        email.tap()
        email.typeText("ada.lovelace@analytical-engine.example")

        let deadline = Date().addingTimeInterval(10)
        while email.frame.height <= heightBefore && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertGreaterThan(email.frame.height, heightBefore, "The email field should grow to show the whole address")
    }
}
