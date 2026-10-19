import Testing
import Foundation

@Suite("ExportFileName Tests")
struct ExportFileNameTests {

    // MARK: - Catalog

    @Test("every language of the catalog has a title pattern with the name in it")
    func catalogPatternsContainTheName() throws {
        let catalogURL = Repository.root.appendingPathComponent("PrestoCV/Localizable.xcstrings")
        let catalog = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        )
        let strings = try #require(catalog["strings"] as? [String: Any])
        let entry = try #require(strings["export.file_name"] as? [String: Any])
        let localizations = try #require(entry["localizations"] as? [String: [String: Any]])

        #expect(Set(localizations.keys) == ["de", "en", "es", "fr", "it", "pt"])
        for (language, localization) in localizations {
            let unit = localization["stringUnit"] as? [String: Any]
            let value = unit?["value"] as? String
            #expect(value?.contains("%@") == true, "\(language) pattern should contain %@")
        }
    }
}
