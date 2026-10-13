import Testing
import Foundation
@testable import PrestoCVCore

// MARK: - Catalog and source tree

/// The string catalog of the app, read from the source tree.
private struct LocalizationCatalog {
    static let languages = ["de", "en", "es", "fr", "it", "pt"]
    static let translatedLanguages = ["de", "es", "fr", "it", "pt"]

    let strings: [String: [String: Any]]

    static func load() throws -> LocalizationCatalog {
        let data = try Data(contentsOf: SourceTree.root.appendingPathComponent("PrestoCV/Localizable.xcstrings"))
        let catalog = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return LocalizationCatalog(strings: try #require(catalog["strings"] as? [String: [String: Any]]))
    }

    var keys: [String] { strings.keys.sorted() }

    /// The state and the texts of a key in a language. A key with plural forms has one text per form.
    func localization(of key: String, in language: String) -> (state: String?, texts: [String])? {
        guard let localizations = strings[key]?["localizations"] as? [String: Any],
              let localization = localizations[language] as? [String: Any] else {
            return nil
        }
        if let unit = localization["stringUnit"] as? [String: Any], let value = unit["value"] as? String {
            return (unit["state"] as? String, [value])
        }
        let forms = ((localization["variations"] as? [String: Any])?["plural"] as? [String: Any]) ?? [:]
        let units = forms.keys.sorted().compactMap { forms[$0] as? [String: Any] }.compactMap { $0["stringUnit"] as? [String: Any] }
        guard !units.isEmpty else { return nil }
        return (units.first?["state"] as? String, units.compactMap { $0["value"] as? String })
    }

    func texts(of key: String, in language: String) -> [String]? {
        localization(of: key, in: language)?.texts
    }
}

private enum SourceTree {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The Swift sources whose text reaches the user: the app, and the legacy packages it links.
    static let shippedFolders = [
        "PrestoCV", "PrestoCVCore/Sources/PrestoCVCore", "CVPDFExporter/Sources/CVPDFExporter", "CVGeneratorAI/Sources/CVGeneratorAI",
    ]

    struct SwiftFile {
        let path: String
        /// The code that ships: without comment lines, and without the previews at the end of the file.
        let code: String
    }

    static func swiftFiles(in folders: [String]) -> [SwiftFile] {
        var files: [SwiftFile] = []
        for folder in folders {
            let url = root.appendingPathComponent(folder)
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in enumerator where file.pathExtension == "swift" {
                guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                files.append(SwiftFile(path: String(file.path.dropFirst(root.path.count + 1)), code: shippedCode(of: text)))
            }
        }
        return files.sorted { $0.path < $1.path }
    }

    private static func shippedCode(of text: String) -> String {
        var end = text.endIndex
        for marker in ["PreviewProvider", "#Preview"] {
            if let range = text.range(of: marker), range.lowerBound < end { end = range.lowerBound }
        }
        return text[..<end]
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }
}

private extension String {
    /// The captures of a group of a regular expression, for every match.
    func matches(of pattern: String, group: Int = 1) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: self, range: NSRange(startIndex..., in: self)).compactMap { match in
            Range(match.range(at: group), in: self).map { String(self[$0]) }
        }
    }

    /// The key a text with values in it is looked up under: `"\(title). \(message)"` is `"%@. %@"`.
    var asFormatKey: String { replacingValues(with: "%@") }

    /// The same key when the values are numbers: `"\(count) CVs"` is `"%lld CVs"`.
    var asNumberFormatKey: String { replacingValues(with: "%lld") }

    private func replacingValues(with placeholder: String) -> String {
        replacingOccurrences(of: #"\\\((?:[^()]|\([^()]*\))*\)"#, with: placeholder, options: .regularExpression)
    }
}

/// A string literal: its text may hold escaped characters and values.
private let stringLiteral = #""((?:[^"\\\n]|\\.)*)""#

// MARK: - Defects

private enum Defect: Equatable {
    case missing(language: String)
    case notMarkedTranslated(language: String)
    case copiedFromEnglish(language: String)
    case otherPlaceholders(language: String)
    case unused
}

// MARK: - Localization Catalog Tests

@Suite("Localization catalog")
struct LocalizationCatalogTests {

    // MARK: Exemptions

    /// Texts that read the same in every language: symbols, abbreviations, formats.
    fileprivate static let sameInEveryLanguage: Set<String> = [
        "%@. %@", "common.ok", "export.font_preview_sample", "field.url", "format.required_indicator",
    ]

    /// Words that happen to be written the same in English and in these languages.
    fileprivate static let sameInSomeLanguages: [String: Set<String>] = [
        "common.error": ["es"],
        "error.subject.cv": ["es", "fr", "it"],
        "export.color.minimal": ["de"],
        "export.color.modern": ["de"],
        "export.file_name": ["es", "fr", "it"],
        "export.font.modern": ["de"],
        "field.description": ["fr"],
        "section.certifications": ["fr"],
        "section.details": ["de"],
    ]

    /// Keys that a branch that has not landed yet is still rewriting or removing. An entry without a defect left
    /// fails `exemptionsAreStillNeeded`, so each one has to go as soon as its branch has landed.
    fileprivate static let pendingKeys: Set<String> = [
        // The example text of the AI screen, which the AI branch (fix/v1-ai) replaces with `ai.generation.example_text`
        "I'm John Doe, email john@example.com, phone +1 234 567 890, from San Francisco. I'm a senior software engineer with 8 years of experience at Tech Corp building scalable web applications. I have expertise in Python, JavaScript, React, and AWS. I graduated from MIT with a Computer Science degree in 2015. My native language is English and I'm fluent in Spanish.",
    ]

    /// Keys that the code builds from other values, so that no literal names them.
    fileprivate static let dynamicKeyPrefixes = ["language.level."]

    // MARK: Defects

    /// What is wrong with a key, before any exemption.
    fileprivate static func defects(of key: String, in catalog: LocalizationCatalog, usedKeys: Set<String>) -> [Defect] {
        var defects: [Defect] = []
        for language in LocalizationCatalog.languages where catalog.localization(of: key, in: language) == nil {
            defects.append(.missing(language: language))
        }
        if let english = catalog.texts(of: key, in: "en") {
            for language in LocalizationCatalog.translatedLanguages {
                guard let translation = catalog.localization(of: key, in: language) else { continue }
                if translation.state != "translated" {
                    defects.append(.notMarkedTranslated(language: language))
                }
                let mayBeSame = sameInEveryLanguage.contains(key) || (sameInSomeLanguages[key]?.contains(language) ?? false)
                if translation.texts == english && !mayBeSame {
                    defects.append(.copiedFromEnglish(language: language))
                }
                if formatSpecifiers(of: translation.texts) != formatSpecifiers(of: english) {
                    defects.append(.otherPlaceholders(language: language))
                }
            }
        }
        if !usedKeys.contains(key) && !dynamicKeyPrefixes.contains(where: key.hasPrefix) {
            defects.append(.unused)
        }
        return defects
    }

    private static func formatSpecifiers(of texts: [String]) -> [String] {
        texts.flatMap { $0.matches(of: #"%(?:\d+\$)?(?:@|lld|d|f)"#, group: 0) }.sorted()
    }

    /// Every key of the catalog that a string literal of the shipped code names.
    fileprivate static func usedKeys(in catalog: LocalizationCatalog) -> Set<String> {
        let keys = Set(catalog.keys)
        var used: Set<String> = []
        for file in SourceTree.swiftFiles(in: SourceTree.shippedFolders) {
            for literal in file.code.matches(of: stringLiteral) {
                if keys.contains(literal) { used.insert(literal) }
                for format in [literal.asFormatKey, literal.asNumberFormatKey] where keys.contains(format) { used.insert(format) }
            }
        }
        return used
    }

    /// The words written as the message of an `AppError`, by file. The message is shown to the user.
    fileprivate static func hardCodedErrorMessages(catalog: LocalizationCatalog) -> [String: [String]] {
        let errors = "unknown|invalidData|notFound|networkError|validationError|decodingError|encodingError|fileSystemError"
        var found: [String: [String]] = [:]
        for file in SourceTree.swiftFiles(in: SourceTree.shippedFolders) {
            for literal in file.code.matches(of: "AppError\\.(?:\(errors))\\(\\s*\(stringLiteral)") {
                let hasWords = literal.asFormatKey.replacingOccurrences(of: "%@", with: "").range(of: #"\p{L}{2,}"#, options: .regularExpression) != nil
                if hasWords && catalog.strings[literal] == nil { found[file.path, default: []].append(literal) }
            }
        }
        return found
    }

    /// The keys with a defect of one kind, outside the exemptions.
    private func keys(withDefect matches: (Defect) -> Bool) throws -> [String] {
        let catalog = try LocalizationCatalog.load()
        let used = Self.usedKeys(in: catalog)
        return catalog.keys.filter { key in
            !Self.pendingKeys.contains(key) && Self.defects(of: key, in: catalog, usedKeys: used).contains(where: matches)
        }
    }

    // MARK: Tests

    @Test("Every key that the code looks up is in the catalog")
    func everyLookedUpKeyIsInTheCatalog() throws {
        let catalog = try LocalizationCatalog.load()
        let lookups = [
            "(\(stringLiteral))\\s*\\.(?:localized|asLoclizedKey|localizedWithArgs)\\b",
            #"String\(\s*localized:\s*"([^"\\\n]+)""#,
            #"LocalizedStringKey\(\s*"([^"\\\n]+)""#,
        ]
        var missing: [String] = []
        for file in SourceTree.swiftFiles(in: SourceTree.shippedFolders) {
            for pattern in lookups {
                for literal in file.code.matches(of: pattern, group: pattern == lookups[0] ? 2 : 1) where catalog.strings[literal] == nil {
                    missing.append("\(literal) (\(file.path))")
                }
            }
        }

        #expect(missing.isEmpty, "Keys that are looked up but missing from the catalog: \(missing)")
    }

    @Test("Every key has a text in each language, marked as translated")
    func everyKeyHasATextInEveryLanguage() throws {
        let incomplete = try keys { defect in
            switch defect {
            case .missing, .notMarkedTranslated: return true
            default: return false
            }
        }

        #expect(incomplete.isEmpty, "Keys without a translated text in every language: \(incomplete)")
    }

    @Test("No text is copied from English, except those that read the same")
    func noTextIsCopiedFromEnglish() throws {
        let copied = try keys { defect in
            if case .copiedFromEnglish = defect { return true }
            return false
        }

        #expect(copied.isEmpty, "Keys with a text copied from English: \(copied)")
    }

    @Test("Each text keeps the placeholders of the English text")
    func textsKeepThePlaceholders() throws {
        let mismatched = try keys { defect in
            if case .otherPlaceholders = defect { return true }
            return false
        }

        #expect(mismatched.isEmpty, "Keys whose placeholders differ from English: \(mismatched)")
    }

    @Test("Every key of the catalog is used by the code")
    func noKeyIsUnused() throws {
        let unused = try keys { $0 == .unused }

        #expect(unused.isEmpty, "Keys that no code uses: \(unused)")
    }

    @Test("The levels of a language have a text in each language")
    func languageLevelsAreInTheCatalog() throws {
        let catalog = try LocalizationCatalog.load()

        for level in LanguageProficiencyLevel.allCases {
            for language in LocalizationCatalog.languages {
                #expect(catalog.texts(of: level.localizationKey, in: language) != nil, "\(level.localizationKey) has no \(language) text")
            }
        }
    }

    @Test("No exemption outlives its defect")
    func exemptionsAreStillNeeded() throws {
        let catalog = try LocalizationCatalog.load()
        let used = Self.usedKeys(in: catalog)

        for key in Self.pendingKeys {
            #expect(!Self.defects(of: key, in: catalog, usedKeys: used).isEmpty, "\(key) has no defect left: remove it from pendingKeys")
        }
        for key in Self.sameInEveryLanguage {
            for language in LocalizationCatalog.translatedLanguages {
                #expect(catalog.texts(of: key, in: language) == catalog.texts(of: key, in: "en"), "\(key) differs in \(language): remove it from sameInEveryLanguage")
            }
        }
        for (key, languages) in Self.sameInSomeLanguages {
            for language in languages {
                #expect(catalog.texts(of: key, in: language) == catalog.texts(of: key, in: "en"), "\(key) differs in \(language): remove it from sameInSomeLanguages")
            }
        }
    }

    @Test("The text of a view is looked up in the catalog, not written in the code")
    func viewsHaveNoHardCodedText() throws {
        let catalog = try LocalizationCatalog.load()
        let views = "Text|Label|Button|Section|Toggle|TextField|SecureField|Picker|Menu|NavigationLink|DisclosureGroup|LabeledContent|ProgressView|Link"
        let modifiers = "navigationTitle|accessibilityLabel|accessibilityHint|accessibilityValue|help|badge"
        let patterns = [
            "\\b(?:\(views))\\(\\s*\(stringLiteral)",
            "\\.(?:\(modifiers))\\(\\s*\(stringLiteral)",
        ]
        var hardCoded: [String] = []
        for file in SourceTree.swiftFiles(in: ["PrestoCV"]) {
            for pattern in patterns {
                for literal in file.code.matches(of: pattern) {
                    let format = literal.asFormatKey
                    let isLookedUp = catalog.strings[literal] != nil || catalog.strings[format] != nil
                        || catalog.strings[literal.asNumberFormatKey] != nil
                    // A text of values and symbols only, such as "\(a) / \(b)", has nothing to translate.
                    let hasWords = format.replacingOccurrences(of: "%@", with: "").range(of: #"\p{L}{2,}"#, options: .regularExpression) != nil
                    if !isLookedUp && hasWords {
                        hardCoded.append("\"\(literal)\" (\(file.path))")
                    }
                }
            }
        }

        #expect(hardCoded.isEmpty, "Text written in the code instead of the catalog: \(hardCoded)")
    }

    @Test("A failure to start the app is described in words, with the reason")
    func dependencyErrorIsDescribed() {
        let reason = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "no space left"])

        let description = DependencyError.serviceCreationFailed("StorageService", reason).errorDescription

        #expect(description?.contains("no space left") == true)
        #expect(description?.contains("error.dependency_failed") == false)
        #expect(description?.contains("StorageService") == false)
    }

    @Test("An error message is looked up in the catalog, not written in the code")
    func errorMessagesAreNotWrittenInTheCode() throws {
        let violations = Self.hardCodedErrorMessages(catalog: try LocalizationCatalog.load())

        #expect(violations.isEmpty, "Files that write the message of an error in the code: \(violations)")
    }

    @Test("A sample that cannot be read is reported without English of its own")
    func unreadableSampleIsReportedWithoutEnglish() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("l10n_sample_\(UUID().uuidString).json")
        try Data("not json".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        do {
            _ = try await JSONTemplateLoader().loadTemplate(from: file)
            Issue.record("A file that is not JSON should not load")
        } catch AppError.decodingError(let message) {
            #expect(message.hasPrefix(file.lastPathComponent))
            #expect(message.contains("Failed to decode") == false)
        }
    }
}
