import Testing
import Foundation

@Suite("ExportErrorMessage Tests")
struct ExportErrorMessageTests {

    // MARK: - Catalog

    @Test("every message exists in the six languages, and the translations differ from the English text")
    func catalogHasTheMessagesInAllLanguages() throws {
        let catalogURL = Repository.root.appendingPathComponent("PrestoCV/Localizable.xcstrings")
        let catalog = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        )
        let strings = try #require(catalog["strings"] as? [String: Any])
        let keys = [
            "export.error.too_many_pages", "export.error.missing_name_email", "export.error.template_unavailable",
            "export.error.failed", "export.error.preview_failed", "export.error.no_templates"
        ]

        for key in keys {
            let entry = try #require(strings[key] as? [String: Any], "\(key) is missing")
            let localizations = try #require(entry["localizations"] as? [String: [String: Any]])
            #expect(Set(localizations.keys) == ["de", "en", "es", "fr", "it", "pt"], "\(key) languages")

            let values = localizations.mapValues { ($0["stringUnit"] as? [String: Any])?["value"] as? String ?? "" }
            let english = try #require(values["en"])
            for (language, value) in values {
                #expect(!value.isEmpty, "\(key) in \(language) is empty")
                if language != "en" {
                    #expect(value != english, "\(key) in \(language) is still the English text")
                }
            }
            if key == "export.error.too_many_pages" {
                for (language, value) in values {
                    #expect(value.contains("%1$d") && value.contains("%2$d"), "\(key) in \(language) needs both numbers")
                }
            }
        }
    }
}
