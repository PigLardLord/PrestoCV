import XCTest

/// What is typed into a CV survives iOS ending the app in the background. It used to be lost: the first-run screen came
/// back after a relaunch, with nothing kept.
final class UnsavedEditsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 300
        // In landscape the first run has room only for its first choice, the AI draft where the device can run it:
        // these steps start a blank CV
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        // A folder of its own that the launches of this test share, as an installation keeps its data between them
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsStorage", UUID().uuidString]
    }

    /// Types a name into a new CV, sends the app to the background and lets iOS end it.
    private func typeIntoANewCVAndEndTheAppInTheBackground() {
        app.launch()
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV")
        start.tap()
        let name = app.textFields["Full Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The editor should have a full name to type into")
        name.tap()
        name.typeText("Marta Rinaldi")

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10), "The app should go to the background")
        app.terminate()
        app.launch()
    }

    func testANewCVTypedBeforeTheAppWasEndedIsRestoredAndSavedOnce() throws {
        typeIntoANewCVAndEndTheAppInTheBackground()

        let offer = app.alerts["Restore Unsaved Changes?"]
        XCTAssertTrue(offer.waitForExistence(timeout: 20), "The relaunched app should offer the unsaved changes")
        let message = offer.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "“Marta Rinaldi”")).firstMatch
        XCTAssertTrue(message.exists, "The offer should name the CV")
        offer.buttons["Restore"].tap()

        let name = app.textFields["Full Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "Restoring should open the editor")
        XCTAssertEqual(name.value as? String, "Marta Rinaldi", "The editor should show what was typed")

        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.savedConfirmation.waitForExistence(timeout: 10), "Saving should be confirmed in the editor")
        XCTAssertEqual(app.alerts.count, 0, "Saving should not stop the person with a dialog")
        app.navigationBars.buttons["Done"].tap()

        // A CV without a name of its own is listed under the name of its person
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Marta Rinaldi"))
        XCTAssertTrue(row.firstMatch.waitForExistence(timeout: 10), "The list should show the saved CV")
        XCTAssertEqual(row.count, 1, "The CV should be stored once")

        app.terminate()
        app.launch()
        XCTAssertTrue(row.firstMatch.waitForExistence(timeout: 20), "The saved CV should be there after a relaunch")
        XCTAssertFalse(app.alerts["Restore Unsaved Changes?"].exists, "Saved changes should not be offered again")
    }

    func testUnsavedChangesDiscardedAfterARelaunchAreGone() throws {
        typeIntoANewCVAndEndTheAppInTheBackground()

        let offer = app.alerts["Restore Unsaved Changes?"]
        XCTAssertTrue(offer.waitForExistence(timeout: 20), "The relaunched app should offer the unsaved changes")
        offer.buttons["Discard"].tap()
        XCTAssertTrue(app.buttons["Create My First CV"].waitForExistence(timeout: 10), "Nothing should be stored")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Create My First CV"].waitForExistence(timeout: 20), "Nothing should be stored")
        XCTAssertFalse(app.alerts["Restore Unsaved Changes?"].waitForExistence(timeout: 3), "Discarded changes should not be offered again")
    }
}
