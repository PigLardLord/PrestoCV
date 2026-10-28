import UIKit
import XCTest

/// The diagnostics screen of a test build (ADR 0032). A Debug build is given the store's answer with
/// `-diagnosticsDistribution`: as a TestFlight install it records each AI draft and import and offers the screen in the
/// list; as an App Store install, or one the store cannot place, it offers nothing.
///
/// The simulator cannot run the model: the debug launch arguments script its answer for the nurse's description.
final class DiagnosticsUITests: XCTestCase {

    private var app: XCUIApplication!

    /// The description the scripted model answers, as `AIDraftScript.nurseDescription` in the app.
    private let nurseDescription = "Sono infermiera presso San Camillo a Roma dal 2015. Uso Excel ogni giorno."
    private let reminder = "Draft written by AI from your description."

    override func setUpWithError() throws {
        continueAfterFailure = false
        executionTimeAllowance = 300
        app = XCUIApplication()
    }

    private func launch(distribution: String) {
        app.launchArguments += [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-PrestoCVUITestsEmptyStorage",
            "-PrestoCVUITestsScriptedDraft", "nurse", "-PrestoCVUITestsClaimCheck", "fail",
            "-diagnosticsDistribution", distribution,
        ]
        app.launch()
    }

    /// The entry of the diagnostics screen in the bar of the list.
    private var entry: XCUIElement {
        app.buttons["diagnostics.entry"]
    }

    // MARK: A TestFlight install

    func testATestFlightInstallListsTheDraftAndTheImportAndOffersTheirFiles() throws {
        launch(distribution: "sandbox")
        draftTheNursesCV()
        XCTAssertTrue(app.backButton.waitForExistence(timeout: 10), "The editor should go back to the list")
        app.backButton.tap()
        try importAPastedCV()
        XCTAssertTrue(app.backButton.waitForExistence(timeout: 10), "The editor should go back to the list")
        app.backButton.tap()

        XCTAssertTrue(entry.waitForExistence(timeout: 10), "The list of a TestFlight install should offer the diagnostics")
        entry.tap()

        // Runs of earlier tests on this simulator may follow: the newest two are this test's, the import last
        let runs = app.buttons.matching(identifier: "diagnostics.run")
        XCTAssertTrue(runs.element(boundBy: 1).waitForExistence(timeout: 10), "The screen should list the draft and the import")
        XCTAssertTrue(runs.element(boundBy: 0).label.contains("CV import"), "The newest run is the import: \(runs.element(boundBy: 0).label)")
        XCTAssertTrue(runs.element(boundBy: 1).label.contains("AI draft"), "The run before it is the draft: \(runs.element(boundBy: 1).label)")
        let share = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "diagnostics.share", "Share report")).firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 10), "The screen should offer the files of the chosen run")
        add(app.keptScreenshot(named: "Diagnostics - runs"))
    }

    // MARK: Other installs

    func testAnAppStoreInstallOffersNoDiagnostics() throws {
        launch(distribution: "production")
        assertTheListOffersNoDiagnostics()
    }

    func testAnInstallTheStoreCannotPlaceOffersNoDiagnostics() throws {
        launch(distribution: "unknown")
        assertTheListOffersNoDiagnostics()
    }

    // MARK: Steps

    /// Saves a first CV, goes back to the list and checks that the entry does not come.
    private func assertTheListOffersNoDiagnostics(file: StaticString = #filePath, line: UInt = #line) {
        let start = app.buttons["Create My First CV"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "The first-run screen should offer to create a CV", file: file, line: line)
        start.tap()
        let name = app.textFields["Full Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "The editor should have a full name to type into", file: file, line: line)
        name.tap()
        name.typeText("Maria Rossi\n")
        XCTAssertTrue(app.savedOnThisDevice.waitForExistence(timeout: 10), "The editor should save by itself", file: file, line: line)
        app.backButton.tap()
        XCTAssertTrue(app.barButton("Add").waitForExistence(timeout: 10), "The list should show its bar", file: file, line: line)

        let comes = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: entry)
        XCTAssertEqual(XCTWaiter.wait(for: [comes], timeout: 3), .timedOut, "The list should not offer the diagnostics",
                       file: file, line: line)
    }

    /// Drafts the nurse's CV from the first-run screen and waits for the editor.
    private func draftTheNursesCV() {
        let aiDraft = app.buttons["Draft My CV with AI"]
        XCTAssertTrue(aiDraft.waitForExistence(timeout: 20), "The first-run screen should offer the AI draft")
        aiDraft.tap()

        let description = app.textViews.matching(NSPredicate(format: "label == %@", "Your Professional Background")).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 10), "The AI screen should have a description to type into")
        description.tap()
        description.typeText(nurseDescription)
        let done = app.toolbars.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), XCUIApplication.noSoftwareKeyboard)
        done.tap()

        let generate = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Generate CV with AI")).firstMatch
        app.scrollTo(generate)
        generate.tap()

        let notice = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", reminder)).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 30), "The draft should open in the editor")
    }

    /// Pastes a CV in the import of the "New CV" screen and waits for the editor.
    private func importAPastedCV() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "chat", withExtension: "txt"), "chat.txt is in the test bundle")
        UIPasteboard.general.string = String(decoding: try Data(contentsOf: url), as: UTF8.self)

        let add = app.barButton("Add")
        XCTAssertTrue(add.waitForExistence(timeout: 10), "The list should offer to add a CV")
        add.tap()
        let card = app.buttons["newcv.import"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "The New CV screen should offer to paste or import a CV")
        app.scrollTo(card)
        card.tap()

        let paste = app.buttons.matching(NSPredicate(format: "label == 'Paste'")).firstMatch
        XCTAssertTrue(paste.waitForExistence(timeout: 10), "The import screen should offer the system's paste button")
        paste.tap()
        let importText = app.buttons["Import this text"]
        XCTAssertTrue(importText.waitForExistence(timeout: 10))
        app.scrollTo(importText)
        importText.tap()
        XCTAssertTrue(app.textFields["Full Name"].waitForExistence(timeout: 10), "The imported CV should open in the editor")
    }
}
