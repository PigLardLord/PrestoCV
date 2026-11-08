import Foundation

// The string checks as a function of a catalog and the sources that look its keys up. The catalog tests of the legacy
// app and of the new app both call it, and so does the self-test that plants a defect of each kind.

// MARK: - Findings and rules

/// What the checks found in a catalog and its sources, one list per kind of defect. Each entry names the key, and the
/// language or the file when that is what differs.
struct StringFindings: Equatable {
    var missingLanguage: [String] = []
    var notTranslated: [String] = []
    var copiedFromEnglish: [String] = []
    var otherPlaceholders: [String] = []
    var availabilityPromises: [String] = []
    var titleCase: [String] = []
    var unused: [String] = []
    var lookedUpButMissing: [String] = []

    /// Whether any entry is about `key`.
    func mentions(_ key: String) -> Bool {
        let perKey = missingLanguage + notTranslated + copiedFromEnglish + otherPlaceholders + unused
        return perKey.contains { $0 == key || $0.hasPrefix(key + " (") }
    }
}

/// The exemptions of one catalog, each a list that gives its reason where it is declared.
struct StringRules: Sendable {
    /// Texts that read the same in every language: symbols, abbreviations, formats.
    var sameInEveryLanguage: Set<String> = []
    /// Words that happen to be written the same in English and in these languages.
    var sameInSomeLanguages: [String: Set<String>] = [:]
    /// Keys that a branch that has not landed yet is still rewriting or removing. An entry without a defect left is stale.
    var pendingKeys: Set<String> = []
    /// Keys that the code builds from other values, so that no literal names them.
    var dynamicKeyPrefixes: [String] = []
    /// Names that keep their capital letter inside a sentence.
    var properNames: Set<String> = []
    /// Keys whose text is the name of a person in every language.
    var personNames: Set<String> = []
    /// Proper names that the text of one key keeps capitalised inside a sentence.
    var properNamesOfKey: [String: Set<String>] = [:]
    /// Only the keys with this prefix are checked for a promise of availability; all keys when nil.
    var promiseKeyPrefix: String?
}

// MARK: - Catalog

/// A string catalog, read from a file.
struct LocalizationCatalog {
    static let languages = ["de", "en", "es", "fr", "it", "pt"]
    static let translatedLanguages = ["de", "es", "fr", "it", "pt"]

    let strings: [String: [String: Any]]

    init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let catalog = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = catalog["strings"] as? [String: [String: Any]] else {
            throw CatalogError.notACatalog(url.path)
        }
        self.strings = strings
    }

    enum CatalogError: Error { case notACatalog(String) }

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

    /// Whether a literal of the code is looked up under this key, with its values read as text or as numbers.
    func isLookedUp(_ literal: String) -> Bool {
        strings[literal] != nil || strings[literal.asFormatKey] != nil || strings[literal.asNumberFormatKey] != nil
    }
}

// MARK: - Sources

/// A Swift file as the checks read it.
struct SwiftSource {
    let path: String
    /// The code that ships: without comment lines, and without the previews at the end of the file.
    let code: String

    init(url: URL) throws {
        let root = Repository.root.path + "/"
        path = url.path.hasPrefix(root) ? String(url.path.dropFirst(root.count)) : url.lastPathComponent
        code = SwiftSource.shippedCode(of: try String(contentsOf: url, encoding: .utf8))
    }

    /// The Swift files that git tracks under `folders`, which are relative to the repository root.
    static func trackedFiles(in folders: [String]) throws -> [URL] {
        let files = try Repository.presentFiles()
        return files
            .filter { path in path.hasSuffix(".swift") && folders.contains { path.hasPrefix($0 + "/") } }
            .sorted()
            .map { Repository.root.appendingPathComponent($0) }
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

extension String {
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
let stringLiteral = #""((?:[^"\\\n]|\\.)*)""#

// MARK: - The checks

enum StringChecks {
    /// Checks `catalog` against the Swift files in `sources`.
    static func run(catalog url: URL, sources urls: [URL], rules: StringRules = StringRules()) throws -> StringFindings {
        let catalog = try LocalizationCatalog(contentsOf: url)
        let sources = try urls.map(SwiftSource.init(url:))
        let used = usedKeys(in: catalog, sources: sources)
        var findings = StringFindings()
        for key in catalog.keys where !rules.pendingKeys.contains(key) {
            check(key, in: catalog, used: used, rules: rules, into: &findings)
        }
        findings.titleCase = try titleCaseTexts(in: catalog, rules: rules)
        findings.availabilityPromises = availabilityPromises(in: catalog, rules: rules)
        findings.lookedUpButMissing = lookedUpButMissing(from: catalog, in: sources)
        return findings
    }

    /// The exemptions that no longer exempt anything, as lines to read.
    static func staleExemptions(catalog url: URL, sources urls: [URL], rules: StringRules) throws -> [String] {
        let catalog = try LocalizationCatalog(contentsOf: url)
        var withoutPending = rules
        withoutPending.pendingKeys = []
        let findings = try run(catalog: url, sources: urls, rules: withoutPending)
        var stale: [String] = []
        for key in rules.pendingKeys.sorted() where !findings.mentions(key) {
            stale.append("\(key) has no defect left: remove it from pendingKeys")
        }
        for key in rules.sameInEveryLanguage.sorted() {
            for language in LocalizationCatalog.translatedLanguages where catalog.texts(of: key, in: language) != catalog.texts(of: key, in: "en") {
                stale.append("\(key) differs in \(language): remove it from sameInEveryLanguage")
            }
        }
        for (key, languages) in rules.sameInSomeLanguages.sorted(by: { $0.key < $1.key }) {
            for language in languages.sorted() where catalog.texts(of: key, in: language) != catalog.texts(of: key, in: "en") {
                stale.append("\(key) differs in \(language): remove it from sameInSomeLanguages")
            }
        }
        for (key, names) in rules.properNamesOfKey.sorted(by: { $0.key < $1.key }) {
            let capitalised = try Set(sentenceCaseLanguages.flatMap { language in
                try (catalog.texts(of: key, in: language) ?? []).flatMap { try titleCaseWords(in: $0, properNames: rules.properNames) }
            })
            if !names.isSubset(of: capitalised) {
                stale.append("\(key) no longer capitalises \(names.subtracting(capitalised).sorted()): remove it from properNamesOfKey")
            }
        }
        return stale
    }

    // MARK: Per key

    private static func check(_ key: String, in catalog: LocalizationCatalog, used: Set<String>, rules: StringRules, into findings: inout StringFindings) {
        for language in LocalizationCatalog.languages where catalog.localization(of: key, in: language) == nil {
            findings.missingLanguage.append("\(key) (\(language))")
        }
        if let english = catalog.texts(of: key, in: "en") {
            for language in LocalizationCatalog.translatedLanguages {
                guard let translation = catalog.localization(of: key, in: language) else { continue }
                if translation.state != "translated" {
                    findings.notTranslated.append("\(key) (\(language))")
                }
                let mayBeSame = rules.sameInEveryLanguage.contains(key) || (rules.sameInSomeLanguages[key]?.contains(language) ?? false)
                if translation.texts == english && !mayBeSame {
                    findings.copiedFromEnglish.append("\(key) (\(language))")
                }
                if formatSpecifiers(of: translation.texts) != formatSpecifiers(of: english) {
                    findings.otherPlaceholders.append("\(key) (\(language))")
                }
            }
        }
        if !used.contains(key) && !rules.dynamicKeyPrefixes.contains(where: key.hasPrefix) {
            findings.unused.append(key)
        }
    }

    private static func formatSpecifiers(of texts: [String]) -> [String] {
        texts.flatMap { $0.matches(of: #"%(?:\d+\$)?(?:@|lld|d|f)"#, group: 0) }.sorted()
    }

    /// Every key of the catalog that a string literal of the sources names.
    private static func usedKeys(in catalog: LocalizationCatalog, sources: [SwiftSource]) -> Set<String> {
        let keys = Set(catalog.keys)
        var used: Set<String> = []
        for file in sources {
            for literal in file.code.matches(of: stringLiteral) {
                if keys.contains(literal) { used.insert(literal) }
                for format in [literal.asFormatKey, literal.asNumberFormatKey] where keys.contains(format) { used.insert(format) }
            }
        }
        return used
    }

    // MARK: Sentence case

    /// The languages whose texts are written in sentence case.
    static let sentenceCaseLanguages = ["es", "fr", "it", "pt"]

    private static func titleCaseTexts(in catalog: LocalizationCatalog, rules: StringRules) throws -> [String] {
        var found: [String] = []
        for key in catalog.keys where !rules.personNames.contains(key) {
            let names = rules.properNamesOfKey[key] ?? []
            for language in sentenceCaseLanguages {
                for text in catalog.texts(of: key, in: language) ?? [] {
                    if try !titleCaseWords(in: text, properNames: rules.properNames).allSatisfy(names.contains) {
                        found.append("\(key) (\(language)): \(text)")
                    }
                }
            }
        }
        return found
    }

    /// The words of a text that start with a capital letter as in an English title: inside a sentence, and neither
    /// an abbreviation nor a proper name. "Crea Tu CV Perfecto" has "Tu" and "Perfecto".
    static func titleCaseWords(in text: String, properNames: Set<String>) throws -> [String] {
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

    // MARK: Availability

    /// Words that promise future availability or readiness, by language: that a feature, a model or its data will be
    /// there soon, in a moment, later, or not yet. Nothing tells when they will be ready, and the owner decided that the
    /// texts promise no availability the app cannot deliver now (#255, #270). The expected duration of a task that is
    /// already running is not such a promise.
    static let availabilityPromiseWords: [String: [String]] = [
        "en": ["soon", "shortly", "in a moment", "coming", "yet", "later"],
        "de": ["bald", "gleich", "demnächst", "in Kürze", "noch nicht", "später"],
        "es": ["pronto", "en un momento", "en breve", "todavía no", "aún no", "más tarde"],
        "fr": ["bientôt", "dans un instant", "sous peu", "pas encore", "plus tard"],
        "it": ["presto", "tra un attimo", "fra poco", "a breve", "non ancora", "più tardi"],
        "pt": ["em breve", "em instantes", "logo", "ainda não", "mais tarde"],
    ]

    /// The promise of future availability or readiness in a text, if it makes one.
    static func availabilityPromise(in text: String, language: String) -> String? {
        (availabilityPromiseWords[language] ?? []).first { promise in
            text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: promise))\\b", options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func availabilityPromises(in catalog: LocalizationCatalog, rules: StringRules) -> [String] {
        var promises: [String] = []
        for key in catalog.keys where rules.promiseKeyPrefix.map(key.hasPrefix) ?? true {
            for language in LocalizationCatalog.languages {
                for text in catalog.texts(of: key, in: language) ?? [] {
                    if let promise = availabilityPromise(in: text, language: language) {
                        promises.append("\(key) (\(language)): \"\(promise)\" in \(text)")
                    }
                }
            }
        }
        return promises
    }

    // MARK: Lookups

    private static let lookups = [
        "(\(stringLiteral))\\s*\\.(?:localized|asLoclizedKey|localizedWithArgs)\\b",
        #"String\(\s*localized:\s*"([^"\\\n]+)""#,
        #"LocalizedStringKey\(\s*"([^"\\\n]+)""#,
    ]

    /// The keys that the sources look up and the catalog lacks, with the file.
    private static func lookedUpButMissing(from catalog: LocalizationCatalog, in sources: [SwiftSource]) -> [String] {
        var missing: [String] = []
        for file in sources {
            for pattern in lookups {
                for literal in file.code.matches(of: pattern, group: pattern == lookups[0] ? 2 : 1) where catalog.strings[literal] == nil {
                    missing.append("\(literal) (\(file.path))")
                }
            }
        }
        return missing
    }

    /// The words written as the message of an `AppError`, by file. The message is shown to the user.
    static func hardCodedErrorMessages(catalog: LocalizationCatalog, sources: [URL]) throws -> [String: [String]] {
        let errors = "unknown|invalidData|notFound|networkError|validationError|decodingError|encodingError|fileSystemError"
        var found: [String: [String]] = [:]
        for file in try sources.map(SwiftSource.init(url:)) {
            for literal in file.code.matches(of: "AppError\\.(?:\(errors))\\(\\s*\(stringLiteral)") {
                let hasWords = literal.asFormatKey.replacingOccurrences(of: "%@", with: "").range(of: #"\p{L}{2,}"#, options: .regularExpression) != nil
                if hasWords && catalog.strings[literal] == nil { found[file.path, default: []].append(literal) }
            }
        }
        return found
    }
}
