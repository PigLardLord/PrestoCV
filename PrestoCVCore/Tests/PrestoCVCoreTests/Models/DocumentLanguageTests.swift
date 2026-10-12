import Testing
import Foundation
@testable import PrestoCVCore

@Suite("DocumentLanguage")
struct DocumentLanguageTests {

    struct Resolution: Sendable, CustomTestStringConvertible {
        let tag: String?
        let preferred: [String]
        let expected: DocumentLanguage

        var testDescription: String { "\(tag ?? "nil") with \(preferred) -> \(expected.rawValue)" }
    }

    static let resolutions: [Resolution] = [
        Resolution(tag: "it", preferred: ["de"], expected: .italian),
        Resolution(tag: "pt-BR", preferred: [], expected: .portuguese),
        Resolution(tag: "DE", preferred: ["it"], expected: .german),
        Resolution(tag: "ja", preferred: ["it"], expected: .italian),
        Resolution(tag: "ja", preferred: ["ko"], expected: .english),
        Resolution(tag: nil, preferred: ["it-IT", "en"], expected: .italian),
        Resolution(tag: nil, preferred: ["ja-JP", "fr-CA", "de"], expected: .french),
        Resolution(tag: nil, preferred: ["ja"], expected: .english),
        Resolution(tag: nil, preferred: [], expected: .english),
        Resolution(tag: "", preferred: ["es"], expected: .spanish),
        Resolution(tag: "  ", preferred: ["es"], expected: .spanish),
    ]

    @Test("A document language resolves to a supported language", arguments: resolutions)
    func resolve(_ resolution: Resolution) {
        let language = DocumentLanguage.resolve(resolution.tag, preferredLanguages: resolution.preferred)

        #expect(language == resolution.expected)
    }

    @Test("The six languages of the app are the supported ones")
    func supportedLanguages() {
        #expect(DocumentLanguage.allCases.map(\.rawValue) == ["en", "it", "de", "es", "fr", "pt"])
    }

    @Test("Each language is named in its own language")
    func nativeNames() {
        let names = Dictionary(uniqueKeysWithValues: DocumentLanguage.allCases.map { ($0.rawValue, $0.nativeName) })

        #expect(names == ["en": "English", "it": "Italiano", "de": "Deutsch", "es": "Español", "fr": "Français", "pt": "Português"])
    }

    @Test("A language is created from the tag of its language, region included")
    func initFromTag() {
        #expect(DocumentLanguage(languageTag: "fr-CH") == .french)
        #expect(DocumentLanguage(languageTag: "es_MX") == .spanish)
        #expect(DocumentLanguage(languageTag: "ja") == nil)
        #expect(DocumentLanguage(languageTag: "") == nil)
    }
}
