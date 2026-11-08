import XCTest

/// The app starts in each of its six languages, in dark mode and in landscape, and its first run offers the import in the
/// language it started in. One launch per case: Xcode's matrix of every appearance, language and orientation
/// (`runsForEachTargetApplicationUIConfiguration`) took 128 launches and about 12 minutes, and checked nothing but a
/// screenshot.
final class PrestoCVUITestsLaunchTests: XCTestCase {

    private var appearanceBefore: XCUIDevice.Appearance = .unspecified

    /// Every test starts upright, as the other UI tests do: a class that stopped before its tear-down may have left the
    /// device turned.
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        appearanceBefore = XCUIDevice.shared.appearance
    }

    /// The tests that run next start as the device was: upright, in the appearance it had.
    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.appearance = appearanceBefore
    }

    // MARK: - Languages

    func testLaunchesInEnglish() throws {
        keepScreenshot(of: launch(language: "en", locale: "en_US"))
    }

    func testLaunchesInSpanish() throws {
        keepScreenshot(of: launch(language: "es", locale: "es_ES"))
    }

    func testLaunchesInFrench() throws {
        keepScreenshot(of: launch(language: "fr", locale: "fr_FR"))
    }

    func testLaunchesInGerman() throws {
        keepScreenshot(of: launch(language: "de", locale: "de_DE"))
    }

    func testLaunchesInItalian() throws {
        keepScreenshot(of: launch(language: "it", locale: "it_IT"))
    }

    func testLaunchesInPortuguese() throws {
        keepScreenshot(of: launch(language: "pt", locale: "pt_PT"))
    }

    // MARK: - Appearance and orientation

    func testLaunchesInDarkMode() throws {
        XCUIDevice.shared.appearance = .dark
        let app = launch(language: "en", locale: "en_US")
        XCTAssertEqual(XCUIDevice.shared.appearance, .dark, "The device should still be in dark mode on the first screen")
        keepScreenshot(of: app)
    }

    /// Skipped only where no app turns, as on the outer screen of the iPhone Duo.
    func testLaunchesInLandscape() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch(language: "en", locale: "en_US")
        guard try app.turnsToLandscape() else {
            XCTFail("The first run should turn to landscape")
            return
        }
        XCTAssertTrue(app.buttons["firstrun.import"].exists, "The first run should still offer the import in landscape")
        keepScreenshot(of: app)
    }

    // MARK: - Helpers

    /// The first run's import as the string catalog writes it in each language: the label tells which language the
    /// app loaded, so a launch that falls back to another language, or shows the key, fails.
    private let importLabels = [
        "en": "Paste or import a CV",
        "es": "Pega o importa un CV",
        "fr": "Coller ou importer un CV",
        "de": "Lebenslauf einfügen oder importieren",
        "it": "Incolla o importa un CV",
        "pt": "Colar ou importar um currículo",
    ]

    /// Launches on an empty store and waits for the first run's import, in the language asked for.
    private func launch(language: String, locale: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-PrestoCVUITestsEmptyStorage"]
        app.launch()

        let importButton = app.buttons["firstrun.import"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 20), "The first run should offer the import in \"\(language)\"")
        XCTAssertEqual(importButton.label, importLabels[language], "The first run should be in \"\(language)\"")
        return app
    }

    private func keepScreenshot(of app: XCUIApplication) {
        add(app.keptScreenshot(named: "Launch Screen, \(name)"))
    }
}
