import XCTest

/// The app starts in each of its six languages, in dark mode and in landscape, and its first run offers the import in the
/// language it started in. One launch per case: Xcode's matrix of every appearance, language and orientation
/// (`runsForEachTargetApplicationUIConfiguration`) took 128 launches and about 12 minutes, and checked nothing but a
/// screenshot.
final class PrestoCVUITestsLaunchTests: XCTestCase {

    private var appearanceBefore: XCUIDevice.Appearance = .unspecified

    override func setUpWithError() throws {
        continueAfterFailure = false
        appearanceBefore = XCUIDevice.shared.appearance
    }

    /// The tests that run next start as the device was: upright, in the appearance it had.
    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.appearance = appearanceBefore
    }

    // MARK: - Languages

    func testLaunchesInEnglish() throws {
        launch(language: "en", locale: "en_US")
    }

    func testLaunchesInSpanish() throws {
        launch(language: "es", locale: "es_ES")
    }

    func testLaunchesInFrench() throws {
        launch(language: "fr", locale: "fr_FR")
    }

    func testLaunchesInGerman() throws {
        launch(language: "de", locale: "de_DE")
    }

    func testLaunchesInItalian() throws {
        launch(language: "it", locale: "it_IT")
    }

    func testLaunchesInPortuguese() throws {
        launch(language: "pt", locale: "pt_PT")
    }

    // MARK: - Appearance and orientation

    func testLaunchesInDarkMode() throws {
        XCUIDevice.shared.appearance = .dark
        launch(language: "en", locale: "en_US")
    }

    func testLaunchesInLandscape() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        launch(language: "en", locale: "en_US")
    }

    // MARK: - Helpers

    /// The first run's import in English, and its localization key: in another language, a label that is either of
    /// them means the app did not load that language.
    private let englishImportLabel = "Paste or import a CV"
    private let importLabelKey = "onboarding.import.button"

    /// Launches on an empty store, waits for the first run's import, and keeps a screenshot of the first screen.
    private func launch(language: String, locale: String) {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-PrestoCVUITestsEmptyStorage"]
        app.launch()

        let importButton = app.buttons["firstrun.import"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 20), "The first run should offer the import in \"\(language)\"")
        if language == "en" {
            XCTAssertEqual(importButton.label, englishImportLabel)
        } else {
            XCTAssertNotEqual(importButton.label, englishImportLabel, "The first run should be in \"\(language)\", not English")
            XCTAssertNotEqual(importButton.label, importLabelKey, "The first run should show the \"\(language)\" text, not its key")
        }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen, \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
