import Testing
import Foundation

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
    static let root = Repository.root

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
        "%@. %@", "ai.generation.character_count", "common.ok", "export.font_preview_sample", "field.url", "format.required_indicator",
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
    fileprivate static let pendingKeys: Set<String> = []

    /// Keys that the code builds from other values, so that no literal names them.
    fileprivate static let dynamicKeyPrefixes = ["language.level."]

    /// Names that keep their capital letter inside a sentence: Apple Intelligence, Siri and the Settings app.
    fileprivate static let properNames: Set<String> = ["Apple", "Intelligence", "Siri", "Ajustes", "Réglages", "Impostazioni"]

    /// Keys whose text is the name of a person in every language.
    fileprivate static let personNames: Set<String> = ["export.font_preview_name"]

    /// Proper names that the text of one key keeps capitalised inside a sentence: the person, the city, the school and
    /// the degree of the example description on the AI screen.
    fileprivate static let properNamesOfKey: [String: Set<String>] = [
        "ai.generation.example_text": [
            "Maria", "Rossi", "Don", "Milani", "Bologna", "Bolonia", "Bologne", "Bolonha",
            "Ciencias", "Educación", "Universidad", "Scienze", "Formazione", "Ciências", "Educação", "Universidade",
        ],
    ]

    /// The languages whose texts are written in sentence case.
    fileprivate static let sentenceCaseLanguages = ["es", "fr", "it", "pt"]

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

    /// The words of a text that start with a capital letter as in an English title: inside a sentence, and neither
    /// an abbreviation nor a proper name. "Crea Tu CV Perfecto" has "Tu" and "Perfecto".
    fileprivate static func titleCaseWords(in text: String) throws -> [String] {
        let sentenceBreaks: Set<Character> = [".", "!", "?", ":", "-", "–", "—", "(", "«", "“", "\""]
        let words = try NSRegularExpression(pattern: #"\S+"#)
        var titleCase: [String] = []
        for match in words.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text), range.lowerBound > text.startIndex else { continue }
            let before = text[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            if let last = before.last, sentenceBreaks.contains(last) || last.isNewline { continue }
            let word = text[range].trimmingCharacters(in: .punctuationCharacters)
            guard let first = word.first, first.isUppercase else { continue }
            let isAbbreviation = word.filter(\.isUppercase).count > 1 || word.contains(where: \.isNumber)
            if !isAbbreviation && !properNames.contains(word) { titleCase.append(word) }
        }
        return titleCase
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

    @Test("Spanish, French, Italian and Portuguese texts are written in sentence case, not in English title case")
    func noEnglishTitleCase() throws {
        let catalog = try LocalizationCatalog.load()
        var titleCase: [String] = []
        for key in catalog.keys where !Self.personNames.contains(key) {
            let names = Self.properNamesOfKey[key] ?? []
            for language in Self.sentenceCaseLanguages {
                for text in catalog.texts(of: key, in: language) ?? [] {
                    if try !Self.titleCaseWords(in: text).allSatisfy(names.contains) {
                        titleCase.append("\(key) (\(language)): \(text)")
                    }
                }
            }
        }

        #expect(titleCase.isEmpty, "Texts with capitals of an English title: \(titleCase)")
    }

    @Test("The German texts call a CV a Lebenslauf, as the rest of the German app does")
    func germanTextsSayLebenslauf() throws {
        let catalog = try LocalizationCatalog.load()
        let cv = try NSRegularExpression(pattern: #"\bCVs?\b"#)

        let english = catalog.keys.filter { key in
            (catalog.texts(of: key, in: "de") ?? []).contains { text in
                cv.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
            }
        }

        #expect(english.isEmpty, "German texts that say CV: \(english)")
    }

    @Test("A capital letter is expected at the start of a sentence, in an abbreviation and in a proper name")
    func titleCaseWordsSkipsLegitimateCapitals() throws {
        #expect(try Self.titleCaseWords(in: "Crea Tu CV Perfecto") == ["Tu", "Perfecto"])
        #expect(try Self.titleCaseWords(in: "Crea tu CV perfecto").isEmpty)
        #expect(try Self.titleCaseWords(in: "Impossibile creare il PDF. Riprova.").isEmpty)
        #expect(try Self.titleCaseWords(in: "C1 - Avanzado").isEmpty)
        #expect(try Self.titleCaseWords(in: "O Apple Intelligence está desativado. Abra Ajustes.").isEmpty)
    }

    @Test("Every key of the catalog is used by the code")
    func noKeyIsUnused() throws {
        let unused = try keys { $0 == .unused }

        #expect(unused.isEmpty, "Keys that no code uses: \(unused)")
    }

    @Test("The product is called PrestoCV in every language")
    func productIsCalledPrestoCV() throws {
        let catalog = try LocalizationCatalog.load()

        for language in LocalizationCatalog.languages {
            let welcome = catalog.texts(of: "welcome.title", in: language) ?? []
            #expect(welcome.count == 1 && welcome[0].contains("PrestoCV"), "welcome.title does not name PrestoCV in \(language)")
        }
    }

    @Test("The welcome speaks to everyone, not to a man or to a woman")
    func welcomeIsGenderNeutral() throws {
        let catalog = try LocalizationCatalog.load()
        // A welcome that opens with the adjective agrees with the person: "Benvenuto", "Bienvenida". The noun inside
        // a sentence speaks to everyone ("Ti diamo il benvenuto", "Te damos la bienvenida"), and so does the French
        // "Bienvenue" that opens one, where "Bienvenu" is the adjective of a man.
        let gendered = [
            "es": #"^Bienvenid[oa]s?\b"#,
            "fr": #"^Bienvenus?\b"#,
            "it": #"^Benvenut[oaie]\b"#,
            "pt": #"^Bem-vind[oa]s?\b"#,
        ]

        for (language, pattern) in gendered {
            let form = try NSRegularExpression(pattern: pattern)
            for text in catalog.texts(of: "welcome.title", in: language) ?? [] {
                let match = form.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
                #expect(match == nil, "welcome.title speaks to a man or to a woman in \(language): \(text)")
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
        for (key, names) in Self.properNamesOfKey {
            let capitalised = try Set(Self.sentenceCaseLanguages.flatMap { language in
                try (catalog.texts(of: key, in: language) ?? []).flatMap(Self.titleCaseWords(in:))
            })
            #expect(names.isSubset(of: capitalised), "\(key) no longer capitalises \(names.subtracting(capitalised)): remove it from properNamesOfKey")
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

    @Test("An error message is looked up in the catalog, not written in the code")
    func errorMessagesAreNotWrittenInTheCode() throws {
        let violations = Self.hardCodedErrorMessages(catalog: try LocalizationCatalog.load())

        #expect(violations.isEmpty, "Files that write the message of an error in the code: \(violations)")
    }
}
