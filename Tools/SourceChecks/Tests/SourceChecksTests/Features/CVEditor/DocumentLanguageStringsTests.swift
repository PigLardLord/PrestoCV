import Testing
import Foundation

@Suite("Document language strings")
struct DocumentLanguageStringsTests {

    static let keys = ["field.document_language", "language.automatic"]
    static let languages = ["de", "en", "es", "fr", "it", "pt"]

    private static func value(of key: String, in language: String) throws -> String {
        let catalogURL = Repository.root.appendingPathComponent("PrestoCV/Localizable.xcstrings")
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: Any])
        let entry = try #require(strings[key] as? [String: Any], "\(key) is not in the catalog")
        let localizations = try #require(entry["localizations"] as? [String: Any])
        let localization = try #require(localizations[language] as? [String: Any], "\(key) has no \(language) text")
        let unit = try #require(localization["stringUnit"] as? [String: Any])
        #expect(unit["state"] as? String == "translated", "\(key) in \(language) is not marked as translated")
        return try #require(unit["value"] as? String)
    }

    @Test("Each string of the picker has a text in all six languages", arguments: keys, languages)
    func hasATextInEveryLanguage(key: String, language: String) throws {
        let text = try Self.value(of: key, in: language)

        #expect(!text.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    @Test("Each string of the picker is translated, not copied from English", arguments: keys, ["de", "es", "fr", "it", "pt"])
    func isNotEnglish(key: String, language: String) throws {
        let english = try Self.value(of: key, in: "en")

        #expect(try Self.value(of: key, in: language) != english)
    }
}
