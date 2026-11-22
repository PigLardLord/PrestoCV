import XCTest

/// The first run of the app speaks the language of the device, in each of the six (5-15c): on an empty store the offer
/// of the import reads in that language, not in another one the app fell back to and not as its key.
final class LanguagePassUITests: RuntimeIssueFailingTestCase {

    /// The text of the first run's import button, `start.import` in `PrestoCVNext/Resources/Localizable.xcstrings`, in
    /// each language. All six differ, so a launch that falls back to another language or shows the key fails.
    private static let importOffer = [
        "en": "Paste or import a CV",
        "es": "Pega o importa un CV",
        "fr": "Coller ou importer un CV",
        "de": "Lebenslauf einfügen oder importieren",
        "it": "Incolla o importa un CV",
        "pt": "Colar ou importar um CV",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Tests

    @MainActor
    func testLaunchesInEnglish() throws {
        try assertTheFirstRunSpeaks(language: "en", locale: "en_US")
    }

    @MainActor
    func testLaunchesInSpanish() throws {
        try assertTheFirstRunSpeaks(language: "es", locale: "es_ES")
    }

    @MainActor
    func testLaunchesInFrench() throws {
        try assertTheFirstRunSpeaks(language: "fr", locale: "fr_FR")
    }

    @MainActor
    func testLaunchesInGerman() throws {
        try assertTheFirstRunSpeaks(language: "de", locale: "de_DE")
    }

    @MainActor
    func testLaunchesInItalian() throws {
        try assertTheFirstRunSpeaks(language: "it", locale: "it_IT")
    }

    @MainActor
    func testLaunchesInPortuguese() throws {
        try assertTheFirstRunSpeaks(language: "pt", locale: "pt_PT")
    }

    // MARK: Checks

    /// Launches on an empty store in `language` and waits for the first run's import button, whose label is the text
    /// written above for that language.
    @MainActor
    private func assertTheFirstRunSpeaks(language: String, locale: String) throws {
        XCTAssertEqual(
            Set(Self.importOffer.values).count, Self.importOffer.count, "The six texts differ, or the check proves nothing")
        let expected = try XCTUnwrap(Self.importOffer[language], "A text is written for \"\(language)\"")
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-PrestoCVNextEmptyStorage"]
        app.launch()

        let importing = app.buttons["start.import"]
        XCTAssertTrue(importing.waitForExistence(timeout: 30), "The first run offers the import in \"\(language)\"")
        XCTAssertEqual(
            importing.label, expected, "The import is offered in \"\(language)\": it reads \"\(importing.label)\"")
    }
}
