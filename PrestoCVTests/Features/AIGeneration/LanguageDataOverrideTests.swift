#if DEBUG
import Testing
@testable import PrestoCV

@MainActor
@Suite("LanguageDataOverride - a UI test scripts whether the language data arrives", .timeLimit(.minutes(1)))
struct LanguageDataOverrideTests {
    private let description = "I have worked at San Camillo since 2015."

    private func scripted(_ value: String) throws -> LanguageDataOverride {
        try #require(LanguageDataOverride.current(arguments: ["PrestoCV", "-LanguageDataOverride", value]))
    }

    @Test("arrives: no language is tagged until the app asks; asked, the system gives the data at once, and no word is a verb")
    func dataArrivesWhenAsked() async throws {
        let data = try scripted("arrives")

        #expect(!data.tagger.tagsLexicalClass(inLanguage: "en"))
        #expect(await data.requester.requestLexicalClassData(forLanguage: "en") == .available)
        #expect(data.tagger.tagsLexicalClass(inLanguage: "en"))
        #expect(data.tagger.tagsLexicalClass(inLanguage: "de"))
        #expect(data.tagger.verbs(in: description, language: "en").isEmpty, "A draft is the same on every simulator")
    }

    @Test("neverArrives: a cancelled request ends with notAvailable, and the data stays missing")
    func dataNeverArrives() async throws {
        let data = try scripted("neverArrives")
        let requester = data.requester

        let request = Task { await requester.requestLexicalClassData(forLanguage: "en") }
        request.cancel()

        #expect(await request.value == .notAvailable)
        #expect(!data.tagger.tagsLexicalClass(inLanguage: "en"))
        #expect(data.tagger.verbs(in: description, language: "en").isEmpty)
    }

    @Test("neverArrives shortens the wait of the app to a few seconds, so that a UI test does not pay the 60 seconds; arrives keeps the app's bound")
    func neverArrivesShortensTheBound() throws {
        let silent = try scripted("neverArrives")
        let arriving = try scripted("arrives")

        #expect(silent.bound == LanguageDataOverride.silentBound)
        #expect(silent.bound < LanguageDataPreparation.bound)
        #expect(silent.bound >= .seconds(5), "Long enough for a UI test to see the screen wait")
        #expect(arriving.bound == LanguageDataPreparation.bound)
    }

    @Test("Without the launch argument, without a value after it, or with another value, the device's data is used")
    func otherwiseTheDevicesData() {
        #expect(LanguageDataOverride.current(arguments: ["PrestoCV"]) == nil)
        #expect(LanguageDataOverride.current(arguments: ["PrestoCV", "-LanguageDataOverride"]) == nil)
        #expect(LanguageDataOverride.current(arguments: ["PrestoCV", "-LanguageDataOverride", "soon"]) == nil)
    }
}
#endif
