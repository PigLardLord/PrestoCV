import Foundation

// The string checks as a function of a catalog and the sources that look its keys up. The catalog tests of the legacy
// app and of the new app both call it, and so does the self-test that plants a defect of each kind.

// MARK: - Findings and rules

/// What the checks found in a catalog and its sources, one list per kind of defect. Each entry names the key, and the
/// language or the file when that is what differs.
struct StringFindings: Equatable {
    var missingLanguage: [String] = []
    /// A text that is empty, or whose state is not `translated`, in any of the six languages.
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
    /// Literals handed to a view that are deliberately not a key, each with the reason: a name, a format, a file name.
    /// A literal without a letter pair (a number, a symbol, values only) needs no entry.
    var nonKeyLiterals: [String: String] = [:]
    /// The placeholder of each value (`%@`, `%lld`, in order) of the literals with values that are looked up or handed to
    /// a view, keyed by the literal as written (`shell.numbered \(title) \(number)`), each with its reason. The checks
    /// cannot see the type of a value, so the key the app asks for at run time is declared here: a literal with values
    /// that has no entry is reported, and an entry that fits no literal of the sources is stale. Two literals with the
    /// same text share one entry.
    var valueTypes: [String: ValueTypes] = [:]
    /// Views of the app's own design system that take a key as their first argument, besides the views of SwiftUI.
    var extraViews: [String] = []
    /// The folders (relative to the repository root) whose views are read for literals; all the sources when nil. The legacy
    /// app reads its own views only: the exporter package it links is standalone and its demo button is not localized.
    var viewFolders: [String]?
    /// Labels of arguments that take a key, on any view: `ErrorStateView(title: "failed.title")`.
    var extraArguments: [String] = []
    /// Read every string literal with words in the view folders, wherever it stands (a ternary, a local, a multiline or raw
    /// literal, a member call), instead of the literals handed straight to a view. A literal then passes only as a key, a
    /// lookup, a `nonKeyLiterals` entry or the argument of one of `nonTextArguments`.
    var everyLiteralInViews = false
    /// The arguments (the text before the literal) that take something other than text to translate, each with its reason.
    var nonTextArguments: [String: String] = [
        "verbatim:": "text shown as it is, by definition",
        "accessibilityIdentifier(": "an identifier for the UI tests, never shown",
        "actionIdentifier:": "an identifier for the UI tests, handed to a notice of the design system (InlineNotice), never shown",
        "systemName:": "the name of an SF Symbol",
        "systemImage:": "the name of an SF Symbol",
        "symbol:": "the name of an SF Symbol, handed to a view of the design system (EmptyStateView)",
        "named:": "the name of an image or a color in the asset catalog",
    ]
}

/// The placeholders of the values of one literal, in order, with the reason for their types.
struct ValueTypes: Sendable {
    let placeholders: [String]
    let reason: String

    init(_ placeholders: [String], _ reason: String) {
        self.placeholders = placeholders
        self.reason = reason
    }
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
        guard !forms.isEmpty else { return nil }
        // Every form counts, in sorted order: a form with no text reads as an empty one, and the state is `translated`
        // only when every form is.
        var state: String? = "translated"
        var texts: [String] = []
        for name in forms.keys.sorted() {
            let unit = (forms[name] as? [String: Any])?["stringUnit"] as? [String: Any]
            texts.append(unit?["value"] as? String ?? "")
            let formState = unit?["value"] is String ? unit?["state"] as? String : "no text"
            if state == "translated" { state = formState }
        }
        return (state, texts)
    }

    func texts(of key: String, in language: String) -> [String]? {
        localization(of: key, in: language)?.texts
    }

    /// Whether the catalog has a key under which the app finds this literal at run time (`SwiftLiteral.runtimeKeys`).
    func isLookedUp(_ literal: SwiftLiteral, valueTypes: [String: ValueTypes]) -> Bool {
        literal.runtimeKeys(valueTypes).contains { strings[$0] != nil }
    }
}

// MARK: - Sources

/// A Swift file as the checks read it.
struct SwiftSource {
    let path: String
    /// The code that ships: without the previews at the end of the file. The lexer skips the comments.
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
        return String(text[..<end])
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
}

// MARK: - The checks

enum StringChecks {
    /// Checks `catalog` against the Swift files in `sources`.
    static func run(catalog url: URL, sources urls: [URL], rules: StringRules = StringRules()) throws -> StringFindings {
        let catalog = try LocalizationCatalog(contentsOf: url)
        let sources = try urls.map(SwiftSource.init(url:))
        let used = usedKeys(in: catalog, sources: sources, rules: rules)
        var findings = StringFindings()
        for key in catalog.keys where !rules.pendingKeys.contains(key) {
            check(key, in: catalog, used: used, rules: rules, into: &findings)
        }
        findings.titleCase = try titleCaseTexts(in: catalog, rules: rules)
        findings.availabilityPromises = availabilityPromises(in: catalog, rules: rules)
        findings.lookedUpButMissing = lookedUpButMissing(from: catalog, in: sources, rules: rules) + notKeys(handedToViews: sources, catalog: catalog, rules: rules)
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
        let handed = Set(viewLiterals(in: try urls.map(SwiftSource.init(url:)), rules: rules).map(\.literal.text))
        for literal in rules.nonKeyLiterals.keys.sorted() where !handed.contains(literal) {
            stale.append("\"\(literal)\" is handed to no view: remove it from nonKeyLiterals")
        }
        stale += staleValueTypes(catalog: catalog, sources: try urls.map(SwiftSource.init(url:)), rules: rules)
        return stale
    }

    /// The entries of `valueTypes` that fit no format with values of the sources, or build a key the catalog lacks.
    private static func staleValueTypes(catalog: LocalizationCatalog, sources: [SwiftSource], rules: StringRules) -> [String] {
        let formats = sources.flatMap { StringLiteralLexer.literals(in: $0.code) }.filter { $0.hasValue && $0.lookup != .builtText }
        var stale: [String] = []
        for (text, declared) in rules.valueTypes.sorted(by: { $0.key < $1.key }) {
            guard let literal = formats.first(where: { $0.text == text }) else {
                stale.append("\"\(text)\" is in no checked source as a format with values: remove it from valueTypes")
                continue
            }
            guard let key = literal.formatKey(declared.placeholders) else {
                let values = literal.valueCount
                stale.append("\"\(text)\" declares \(declared.placeholders.count) placeholders for its \(values) value\(values == 1 ? "" : "s"): correct it in valueTypes")
                continue
            }
            if let wrong = declared.placeholders.first(where: { !SwiftLiteral.placeholders.contains($0) }) {
                stale.append("\"\(text)\" declares \(wrong), which is not a placeholder: correct it in valueTypes")
            } else if catalog.strings[key] == nil {
                stale.append("\"\(text)\" builds the key \(key), which the catalog lacks: correct it in valueTypes")
            }
        }
        return stale
    }

    // MARK: Per key

    private static func check(_ key: String, in catalog: LocalizationCatalog, used: Set<String>, rules: StringRules, into findings: inout StringFindings) {
        for language in LocalizationCatalog.languages where catalog.localization(of: key, in: language) == nil {
            findings.missingLanguage.append("\(key) (\(language))")
        }
        for language in LocalizationCatalog.languages {
            guard let found = catalog.localization(of: key, in: language) else { continue }
            if found.state != "translated" || found.texts.contains(where: \.isEmpty) {
                findings.notTranslated.append("\(key) (\(language))")
            }
        }
        if let english = catalog.texts(of: key, in: "en") {
            for language in LocalizationCatalog.translatedLanguages {
                guard let translation = catalog.localization(of: key, in: language) else { continue }
                let mayBeSame = rules.sameInEveryLanguage.contains(key) || (rules.sameInSomeLanguages[key]?.contains(language) ?? false)
                if translation.texts == english && !mayBeSame {
                    findings.copiedFromEnglish.append("\(key) (\(language))")
                }
                let types = placeholderTypes(of: translation.texts)
                if types == nil || types != placeholderTypes(of: english) {
                    findings.otherPlaceholders.append("\(key) (\(language))")
                }
            }
            if placeholderTypes(of: english) == nil { findings.otherPlaceholders.append("\(key) (en)") }
        }
        if !used.contains(key) && !rules.dynamicKeyPrefixes.contains(where: key.hasPrefix) {
            findings.unused.append(key)
        }
    }

    /// The type of the value each argument position takes in a language, over all its forms: an unnumbered specifier takes
    /// the next position of its text, and `%2$@` takes the position 2. A form may omit a value that another form uses
    /// (a plural "one"). Nil when two specifiers want different types for one position, which no argument list can meet.
    static func placeholderTypes(of texts: [String]) -> [Int: String]? {
        var types: [Int: String] = [:]
        for text in texts {
            var next = 1
            for specifier in text.matches(of: #"%%|%(?:\d+\$)?(?:@|lld|d|f)"#, group: 0) where specifier != "%%" {
                let numbered = specifier.dropFirst().split(separator: "$", maxSplits: 1)
                let position = numbered.count == 2 ? Int(numbered[0]) ?? next : next
                let type = String(numbered.count == 2 ? numbered[1] : specifier.dropFirst())
                if numbered.count < 2 { next += 1 }
                if let known = types[position], known != type { return nil }
                types[position] = type
            }
        }
        return types
    }

    /// Every key of the catalog under which the app can find a string literal of the sources at run time.
    private static func usedKeys(in catalog: LocalizationCatalog, sources: [SwiftSource], rules: StringRules) -> Set<String> {
        let keys = Set(catalog.keys)
        var used: Set<String> = []
        for file in sources {
            for literal in StringLiteralLexer.literals(in: file.code) {
                for name in literal.runtimeKeys(rules.valueTypes) where keys.contains(name) { used.insert(name) }
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

    /// The keys that the sources look up and the catalog lacks, with the file. A lookup (`SwiftLiteral.lookup`) is
    /// checked whatever the form of its literal (plain, raw, multiline, with values) and wherever it stands, nested in a
    /// value of another literal too, under the keys its kind of lookup asks for at run time.
    private static func lookedUpButMissing(from catalog: LocalizationCatalog, in sources: [SwiftSource], rules: StringRules) -> [String] {
        sources.flatMap { file in
            StringLiteralLexer.literals(in: file.code)
                .filter { $0.lookup != nil && !catalog.isLookedUp($0, valueTypes: rules.valueTypes) }
                .map { missing($0, in: file.path, rules: rules) }
        }
    }

    /// A literal the catalog lacks, as a line to read. A format with values whose types are not declared says so.
    private static func missing(_ literal: SwiftLiteral, in path: String, rules: StringRules) -> String {
        literal.hasValue && literal.lookup != .builtText && rules.valueTypes[literal.text] == nil
            ? "\(literal.text) (\(path)): declare the type of each value in valueTypes"
            : "\(literal.text) (\(path))"
    }

    // MARK: Literals handed to views

    private static let swiftUIViews = "Text|Label|Button|Section|Toggle|TextField|SecureField|Picker|Menu|NavigationLink|DisclosureGroup|LabeledContent|ProgressView|Link"
    private static let swiftUIModifiers = "navigationTitle|accessibilityLabel|accessibilityHint|accessibilityValue|help|badge"

    /// Every literal that a source hands to a view as its text, with the file. `Text(verbatim:)` is not one. With
    /// `everyLiteralInViews`, every literal of the view folders that is not a lookup or the argument of a non-text parameter.
    private static func viewLiterals(in sources: [SwiftSource], rules: StringRules) -> [(literal: SwiftLiteral, path: String)] {
        let read = sources.filter { file in rules.viewFolders.map { folders in folders.contains { file.path.hasPrefix($0 + "/") } } ?? true }
        if rules.everyLiteralInViews {
            return read.flatMap { file in
                StringLiteralLexer.literals(in: file.code)
                    .filter { $0.lookup == nil && !rules.nonTextArguments.keys.contains(where: $0.before.hasSuffix) }
                    .map { (literal: $0, path: file.path) }
            }
        }
        let views = ([swiftUIViews] + rules.extraViews.map(NSRegularExpression.escapedPattern(for:))).joined(separator: "|")
        var handedTo = ["\\b(?:\(views))\\($", "\\.(?:\(swiftUIModifiers))\\($"]
        if !rules.extraArguments.isEmpty {
            handedTo.append("\\b(?:\(rules.extraArguments.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|"))):$")
        }
        return read.flatMap { file in
            StringLiteralLexer.literals(in: file.code)
                .filter { literal in literal.lookup == nil && handedTo.contains { literal.before.range(of: $0, options: .regularExpression) != nil } }
                .map { (literal: $0, path: file.path) }
        }
    }

    /// The literals handed to a view that are neither a key of the catalog nor a deliberate non-key. A typo in a key
    /// shows the raw key on screen, and English written in a view is not translated (#24). A text of values and
    /// symbols only, such as "\(a) / \(b)", has nothing to translate.
    private static func notKeys(handedToViews sources: [SwiftSource], catalog: LocalizationCatalog, rules: StringRules) -> [String] {
        viewLiterals(in: sources, rules: rules).compactMap { literal, path in
            guard literal.hasWords, !catalog.isLookedUp(literal, valueTypes: rules.valueTypes), rules.nonKeyLiterals[literal.text] == nil else { return nil }
            return missing(literal, in: path, rules: rules)
        }
    }

    /// The words written as the message of an `AppError`, by file. The message is shown to the user.
    static func hardCodedErrorMessages(catalog: LocalizationCatalog, sources: [URL]) throws -> [String: [String]] {
        let errors = "unknown|invalidData|notFound|networkError|validationError|decodingError|encodingError|fileSystemError"
        var found: [String: [String]] = [:]
        for file in try sources.map(SwiftSource.init(url:)) {
            for literal in StringLiteralLexer.literals(in: file.code)
            where literal.before.range(of: "\\bAppError\\.(?:\(errors))\\($", options: .regularExpression) != nil {
                if literal.hasWords && catalog.strings[literal.text] == nil { found[file.path, default: []].append(literal.text) }
            }
        }
        return found
    }
}

// MARK: - The lexer

/// A string literal of Swift code.
struct SwiftLiteral: Equatable {
    /// The content, with the escapes decoded and the indentation of a multiline literal removed. A value stays as
    /// `\(expression)`, for a raw literal too.
    let text: String
    /// The text with each value as `%@`: what the checks read for words.
    let key: String
    /// The literal's format cut at its values: one part more than it has values.
    let formatParts: [String]
    /// The last characters of the code before the literal, without trailing white space: the call or the argument label
    /// it is the argument of, or the operator that joins it to other code.
    let before: String
    /// The first characters of the code after the literal.
    let after: String

    /// Whether the text has words to translate, once the values are taken out.
    var hasWords: Bool { key.replacingOccurrences(of: "%@", with: "").range(of: #"\p{L}{2,}"#, options: .regularExpression) != nil }

    /// The placeholders a value can have in a catalog key.
    static let placeholders: Set<String> = ["%@", "%lld", "%llu", "%ld", "%lu", "%d", "%u", "%lf", "%f"]

    /// The number of values (`\(expression)`) the literal holds.
    var valueCount: Int { formatParts.count - 1 }

    /// Whether the literal holds a value (`\(expression)`).
    var hasValue: Bool { valueCount > 0 }

    /// The catalog key of the literal's format with these placeholders, in order; nil when their number is not the
    /// number of values.
    func formatKey(_ placeholders: [String]) -> String? {
        guard placeholders.count == valueCount else { return nil }
        return zip(formatParts, placeholders + [""]).map { $0 + $1 }.joined()
    }

    /// How the code looks the literal up in the catalog, or nil when it does not: then the literal is shown as written,
    /// or handed to SwiftUI, which reads a literal with values as a format key. The lookup check reads a lookup, and the
    /// every-literal rule does not.
    var lookup: LiteralLookup? {
        if after.range(of: #"^\s*\.(?:localized|asLoclizedKey|localizedWithArgs)\b"#, options: .regularExpression) != nil { return .builtText }
        if before.range(of: #"(?:String\(\s*localized:|LocalizedStringKey\(|LocalizedStringResource\()$"#, options: .regularExpression) != nil { return .format }
        return nil
    }

    /// The keys under which the app can find the literal at run time. A String extension asks for the text with its
    /// values filled in, which no catalog key can match, so a literal with a value has none. An initializer or a view
    /// that reads the interpolation asks for the format with a placeholder for each value by its type, which the checks
    /// cannot see: only the key that `valueTypes` declares for the literal, and none when it declares none.
    func runtimeKeys(_ valueTypes: [String: ValueTypes]) -> [String] {
        switch lookup {
        case .builtText?: return hasValue ? [] : [text]
        case .format?, nil:
            guard hasValue else { return [text] }
            return valueTypes[text].flatMap { formatKey($0.placeholders) }.map { [$0] } ?? []
        }
    }
}

/// How the app finds a literal in the catalog at run time.
enum LiteralLookup: Equatable {
    /// `String(localized:`, `LocalizedStringKey(`, `LocalizedStringResource(`: the initializer reads the literal's
    /// interpolation, so each value is a placeholder by its type and the key is the format (`Hello %@`, `%lld items`),
    /// as `StringRules.valueTypes` declares it.
    case format
    /// A String extension of the legacy app (`.localized`, `.localizedWithArgs`, `.asLoclizedKey`): it receives the
    /// String already built, each value filled in, so its key is the text as written, and a literal with a value is
    /// never found.
    case builtText
}

/// The one reader of string literals of the string checks: single-line, multiline (`"""`) and raw (`#"` with any number of
/// pound signs) literals, with their escapes and values, and every literal nested in a value at any depth. Comments (`//`
/// and nested `/* */`) are skipped, and a comment marker inside a literal is text.
struct StringLiteralLexer {
    private let chars: [Unicode.Scalar]
    private var index = 0
    private var found: [(range: Range<Int>, text: String, format: String)] = []

    /// A character that stands for a decoded `\n`, so that the indentation of a multiline literal is removed only after
    /// the lines that really end.
    private static let decodedNewline = Unicode.Scalar(0xE000)!
    /// A character that stands for a value in the format of a literal, until a placeholder is chosen for it.
    private static let valueMarker = Unicode.Scalar(0xE001)!

    static func literals(in code: String) -> [SwiftLiteral] {
        var lexer = StringLiteralLexer(chars: Array(code.unicodeScalars))
        lexer.scan(untilClosingParenthesis: false)
        return lexer.found.sorted { $0.range.lowerBound < $1.range.lowerBound }.map { range, text, format in
            let parts = format.split(separator: Character(valueMarker), omittingEmptySubsequences: false).map(String.init)
            return SwiftLiteral(
                text: text, key: parts.joined(separator: "%@"), formatParts: parts,
                before: lexer.string(max(0, range.lowerBound - 80)..<range.lowerBound).trimmingCharacters(in: .whitespacesAndNewlines),
                after: lexer.string(range.upperBound..<min(lexer.chars.count, range.upperBound + 40)))
        }
    }

    private init(chars: [Unicode.Scalar]) { self.chars = chars }

    private func string(_ range: Range<Int>) -> String {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: chars[range])
        return String(view)
    }

    private func hasPrefix(_ prefix: String, at position: Int) -> Bool {
        let scalars = Array(prefix.unicodeScalars)
        return position + scalars.count <= chars.count && Array(chars[position..<position + scalars.count]) == scalars
    }

    /// Reads code from `index`, recording the literals; stops after the parenthesis that closes a value of a literal.
    private mutating func scan(untilClosingParenthesis nested: Bool) {
        var depth = 0
        while index < chars.count {
            let c = chars[index]
            if hasPrefix("//", at: index) {
                while index < chars.count && chars[index] != "\n" { index += 1 }
            } else if hasPrefix("/*", at: index) {
                var comments = 0
                repeat {
                    if hasPrefix("/*", at: index) { comments += 1; index += 2 }
                    else if hasPrefix("*/", at: index) { comments -= 1; index += 2 }
                    else { index += 1 }
                } while comments > 0 && index < chars.count
            } else if c == "#" || c == "\"" {
                var hashes = 0
                while index + hashes < chars.count && chars[index + hashes] == "#" { hashes += 1 }
                guard index + hashes < chars.count, chars[index + hashes] == "\"" else { index += hashes; continue }
                readLiteral(hashes: hashes)
            } else if nested && c == "(" {
                depth += 1
                index += 1
            } else if nested && c == ")" {
                if depth == 0 { return }
                depth -= 1
                index += 1
            } else {
                index += 1
            }
        }
    }

    /// Reads the literal that opens at `index`, and records it.
    private mutating func readLiteral(hashes: Int) {
        let start = index
        let pounds = String(repeating: "#", count: hashes)
        let isMultiline = hasPrefix("\"\"\"", at: start + hashes)
        let closing = (isMultiline ? "\"\"\"" : "\"") + pounds
        index = start + hashes + (isMultiline ? 3 : 1)
        var text = String.UnicodeScalarView(), format = String.UnicodeScalarView()
        func append(_ scalar: Unicode.Scalar) { text.append(scalar); format.append(scalar) }
        func append(_ string: String) { string.unicodeScalars.forEach(append) }
        while index < chars.count {
            if hasPrefix(closing, at: index) { index += closing.unicodeScalars.count; break }
            let c = chars[index]
            if c == "\\" && hasPrefix("\\" + pounds, at: index) {
                let afterEscape = index + 1 + hashes
                if afterEscape < chars.count && chars[afterEscape] == "(" {
                    index = afterEscape + 1
                    let expressionStart = index
                    scan(untilClosingParenthesis: true)
                    text.append(contentsOf: "\\(".unicodeScalars + chars[expressionStart..<index] + ")".unicodeScalars)
                    format.append(Self.valueMarker)
                    index = min(index + 1, chars.count)
                    continue
                }
                index = afterEscape
                guard index < chars.count else { break }
                switch chars[index] {
                case "n": append(Self.decodedNewline)
                case "t": append("\t")
                case "r": append("\r")
                case "0": append(Unicode.Scalar(0))
                case "u" where index + 1 < chars.count && chars[index + 1] == "{":
                    var end = index + 2
                    while end < chars.count && chars[end] != "}" && chars[end] != "\n" { end += 1 }
                    if end < chars.count, chars[end] == "}", let value = UInt32(string(index + 2..<end), radix: 16), let scalar = Unicode.Scalar(value) {
                        append(scalar)
                        index = end
                    } else {
                        append("u")
                    }
                case "\n", "\r": break   // a line continuation in a multiline literal
                default: append(chars[index])
                }
                index += 1
                continue
            }
            if !isMultiline && c == "\n" { break }
            append(c)
            index += 1
        }
        let decode = { (view: String.UnicodeScalarView) -> String in
            let content = isMultiline ? Self.withoutIndentation(String(view)) : String(view)
            return content.replacingOccurrences(of: String(Self.decodedNewline), with: "\n")
        }
        found.append((start..<index, decode(text), decode(format)))
    }

    /// The content of a multiline literal: without the line break after the opening quotes, and without the last line
    /// break and the indentation of the closing quotes, which every line loses.
    private static func withoutIndentation(_ content: String) -> String {
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 2, lines[0].trimmingCharacters(in: .whitespaces).isEmpty,
              let indentation = lines.last, indentation.trimmingCharacters(in: .whitespaces).isEmpty else {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        lines.removeFirst()
        lines.removeLast()
        return lines.map { $0.hasPrefix(indentation) ? String($0.dropFirst(indentation.count)) : $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
    }
}
