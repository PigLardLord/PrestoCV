import Testing
import PrestoCVPresentation

/// The app's language, which the export sheet offers first: the first of the app's languages that is a tag (5-12a).
@Suite("Export language")
struct ExportLanguageTests {

    @Test("The app's language is the first of its languages, in canonical case")
    func firstOfTheAppsLanguages() {
        #expect(ExportLanguage.preferred(["de", "en"]).tag == "de")
        #expect(ExportLanguage.preferred(["pt-br", "it"]).tag == "pt-BR")
    }

    @Test("A localization that is no language tag is passed over")
    func passesOverWhatIsNoTag() {
        #expect(ExportLanguage.preferred(["Base", "it"]).tag == "it")
    }

    @Test("With no language tag among them the app's language is English", arguments: [[String](), ["Base"]])
    func englishWhenNoneIsATag(_ tags: [String]) {
        #expect(ExportLanguage.preferred(tags).tag == "en")
    }
}
