import Testing
import Foundation

/// The strings of the export flow: each key the code uses exists in the six languages, no key is left over,
/// and a translation is a translation and not the English text copied.
@Suite("Export strings Tests")
struct ExportStringsTests {

    private static let languages: Set<String> = ["de", "en", "es", "fr", "it", "pt"]

    /// Translations that are the English text in that language too: a symbol, a pattern with no words to translate,
    /// and the words that German shares with English
    private static let sameAsEnglish: [String: Set<String>] = [
        "export.color.minimal": ["de"],
        "export.color.modern": ["de"],
        "export.font.modern": ["de"],
        "export.font_preview_sample": ["de", "es", "fr", "it", "pt"],
        "export.file_name": ["es", "fr", "it"]
    ]

    // MARK: - Reading the project

    private static var projectRoot: URL { Repository.root }

    /// The catalog's entries of the export flow: key, and the value of each language
    private static func catalogValues() throws -> [String: [String: String]] {
        let data = try Data(contentsOf: projectRoot.appendingPathComponent("PrestoCV/Localizable.xcstrings"))
        let catalog = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])
        var result: [String: [String: String]] = [:]
        for (key, entry) in strings where key.hasPrefix("export.") {
            let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
            result[key] = localizations.compactMapValues { ($0["stringUnit"] as? [String: Any])?["value"] as? String }
        }
        return result
    }

    /// The `export.` keys written as string literals in the app's Swift files
    private static func keysUsedInCode() throws -> Set<String> {
        let sources = projectRoot.appendingPathComponent("PrestoCV")
        let enumerator = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        let literal = try NSRegularExpression(pattern: #""(export\.[a-z_.]+)""#)
        var keys: Set<String> = []
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in literal.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let range = Range(match.range(at: 1), in: text) {
                    keys.insert(String(text[range]))
                }
            }
        }
        return keys
    }

    private static func placeholders(in value: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: #"%(\d+\$)?[@dfs]"#)
        return pattern.matches(in: value, range: NSRange(value.startIndex..., in: value)).compactMap { match in
            Range(match.range, in: value).map { String(value[$0]) }
        }.sorted()
    }

    // MARK: - Tests

    @Test("the code uses export keys at all, so that the checks below mean something")
    func codeUsesExportKeys() throws {
        let used = try Self.keysUsedInCode()

        #expect(used.count >= 20)
        #expect(used.contains("export.templates.tab"))
        #expect(used.contains("export.share"))
    }

    @Test("every export key used in the code has a value in all six languages")
    func usedKeysExistInAllLanguages() throws {
        let catalog = try Self.catalogValues()

        for key in try Self.keysUsedInCode().sorted() {
            let values = try #require(catalog[key], "\(key) is used in the code but missing from the catalog")
            #expect(Set(values.keys) == Self.languages, "\(key) needs all six languages, has \(values.keys.sorted())")
            for (language, value) in values {
                #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "\(key) in \(language) is empty")
            }
        }
    }

    @Test("every export key of the catalog is used in the code, so that no dead string is kept")
    func catalogHasNoUnusedExportKeys() throws {
        let unused = Set(try Self.catalogValues().keys).subtracting(try Self.keysUsedInCode())

        #expect(unused.isEmpty, "Unused export keys: \(unused.sorted())")
    }

    @Test("a translation is not the English text copied, except where the word is the same in that language")
    func translationsDifferFromEnglish() throws {
        for (key, values) in try Self.catalogValues().sorted(by: { $0.key < $1.key }) {
            let english = try #require(values["en"], "\(key) has no English text")
            for (language, value) in values where language != "en" {
                let mayMatch = Self.sameAsEnglish[key]?.contains(language) == true
                #expect(mayMatch || value != english, "\(key) in \(language) is still the English text: \(value)")
            }
        }
    }

    @Test("the allowed copies of the English text are real: each one is still a copy")
    func allowedCopiesAreStillCopies() throws {
        let catalog = try Self.catalogValues()

        for (key, languages) in Self.sameAsEnglish {
            let values = try #require(catalog[key], "\(key) is allowed to match English but is not in the catalog")
            for language in languages {
                #expect(values[language] == values["en"], "\(key) in \(language) differs from English: remove it from the allowed copies")
            }
        }
    }

    @Test("every language has the same placeholders as the English text")
    func placeholdersAgreeAcrossLanguages() throws {
        for (key, values) in try Self.catalogValues() {
            let english = Self.placeholders(in: values["en"] ?? "")
            for (language, value) in values {
                #expect(Self.placeholders(in: value) == english, "\(key) in \(language) has other placeholders than the English text")
            }
        }
    }

    @Test("the tab labels are words, not the keys they were looked up by")
    func tabLabelsAreWords() throws {
        let catalog = try Self.catalogValues()

        for key in ["export.templates.tab", "export.fonts.tab", "export.colors.tab"] {
            for (language, value) in try #require(catalog[key]) {
                #expect(!value.contains("export."), "\(key) in \(language) shows its key")
                #expect(!value.contains(" "), "\(key) in \(language) is too long for a tab label: \(value)")
            }
        }
    }
}
