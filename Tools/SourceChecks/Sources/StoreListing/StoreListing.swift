import Foundation

/// The texts of docs/release/store-listing.md: one section for each App Store localization, and the notes for App Review.
///
/// A text is the fenced ```text block under a field heading (`### Name`) of a locale section (`## German, de-DE`), or under
/// `## Notes for App Review`. Characters are Unicode scalars of NFC text; keywords are counted in UTF-8 bytes.
struct Listing: Equatable {
    var locales: [LocaleTexts]
    var notes: String?

    subscript(code: String) -> LocaleTexts? {
        get { locales.first { $0.code == code } }
        set {
            guard let index = locales.firstIndex(where: { $0.code == code }), let newValue else { return }
            locales[index] = newValue
        }
    }
}

/// The texts of one locale, by field name. A field has one text; more than one is an error the checks report.
struct LocaleTexts: Equatable {
    let code: String
    var fields: [String: [String]]
}

/// A retired word: a text that matches `regex` names a feature the app lacks.
struct RetiredEntry {
    let regex: NSRegularExpression
    let languages: [String]
    let allowedIn: [String]
    let onlyIn: [String]?
    let reason: String
}

struct RetiredWords {
    var entries: [RetiredEntry]
    /// The locales still written for 1.0: a baseline that may only shrink.
    var pendingLocales: [String]

    private struct File: Decodable {
        struct Entry: Decodable {
            let pattern: String
            let languages: [String]
            let ignoreCase: Bool?
            let allowedIn: [String]?
            let onlyIn: [String]?
            let reason: String
        }
        let entries: [Entry]
        let pendingLocales: [String]
    }

    static func load(from data: Data) throws -> RetiredWords {
        let file = try JSONDecoder().decode(File.self, from: data)
        let entries = try file.entries.map { entry in
            RetiredEntry(regex: try NSRegularExpression(pattern: entry.pattern, options: entry.ignoreCase == true ? [.caseInsensitive] : []),
                         languages: entry.languages, allowedIn: entry.allowedIn ?? [], onlyIn: entry.onlyIn, reason: entry.reason)
        }
        return RetiredWords(entries: entries, pendingLocales: file.pendingLocales)
    }
}

enum StoreListingRules {
    static let fields = ["Name", "Subtitle", "Keywords", "Promotional text", "Description", "Screenshot captions", "What's New"]
    static let limits = ["Name": 30, "Subtitle": 30, "Promotional text": 170, "Description": 4000, "What's New": 4000]
    static let keywordBytes = 100
    static let notesLimit = 4000
    /// One caption for each of the six screenshots: the composer puts the nth caption on the nth capture.
    static let captionCount = 6
    /// A caption is "Title | Line below". The limits keep the title on one or two lines of the screenshot, at its large size.
    static let captionTitleLimit = 30
    static let captionLineLimit = 80
    /// Guideline 2.3.7: no prices in the name, the subtitle, the keywords or the screenshots.
    static let priceWords: Set<String> = ["free", "gratis", "kostenlos", "gratuit", "gratuite", "gratuito", "gratuita", "gratuitos", "price",
                                          "preis", "prezzo", "precio", "prix", "preco"]
    static let pricedFields = ["Name", "Subtitle", "Keywords", "Screenshot captions"]
    static let notes = "Notes for App Review"
    static let notesLanguage = "en"
    static let countsStart = "<!-- counts:start -->"
    static let countsEnd = "<!-- counts:end -->"

    private static let localeHeading = try! NSRegularExpression(pattern: #"^## .+, ([a-z]{2}(?:-[A-Z]{2})?)$"#)
    private static let wordPattern = try! NSRegularExpression(pattern: #"\w+"#)
    private static let pricePattern = try! NSRegularExpression(pattern: "[$\u{20AC}\u{A3}]")

    // MARK: Reading

    static func parse(_ lines: [String]) -> Listing {
        var listing = Listing(locales: [], notes: nil)
        var section: String?
        var field: String?
        var block: [String]?
        for line in lines {
            if block != nil {
                if line.unicodeScalars.elementsEqual("```".unicodeScalars) {
                    let text = block!.joined(separator: "\n")
                    if section == notes {
                        listing.notes = text
                    } else if let code = section, let field, let index = listing.locales.firstIndex(where: { $0.code == code }) {
                        listing.locales[index].fields[field, default: []].append(text)
                    }
                    block = nil
                } else {
                    block!.append(line)
                }
            } else if line == "```text" {
                block = []
            } else if let code = localeCode(of: line) {
                section = code
                field = nil
                if let index = listing.locales.firstIndex(where: { $0.code == code }) {
                    listing.locales[index].fields = [:]
                } else {
                    listing.locales.append(LocaleTexts(code: code, fields: [:]))
                }
            } else if line.hasPrefix("## ") {
                section = String(line.dropFirst(3))
                field = nil
            } else if line.hasPrefix("### ") {
                field = String(line.dropFirst(4))
            }
        }
        return listing
    }

    private static func localeCode(of line: String) -> String? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = localeHeading.firstMatch(in: line, range: range), let code = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[code])
    }

    // MARK: Text

    /// Lower case without diacritics, so "Currículum" and "curriculum" are one word, as the App Store matches them.
    static func fold(_ text: String) -> String {
        let stripped = String(String.UnicodeScalarView(text.decomposedStringWithCompatibilityMapping.unicodeScalars
            .filter { $0.properties.canonicalCombiningClass == .notReordered }))
        return stripped.lowercased().replacingOccurrences(of: "\u{DF}", with: "ss")
    }

    static func words(_ text: String) -> Set<String> {
        let folded = fold(text)
        let matches = wordPattern.matches(in: folded, range: NSRange(folded.startIndex..., in: folded))
        return Set(matches.compactMap { Range($0.range, in: folded).map { String(folded[$0]) } })
    }

    /// The length the App Store counts: Unicode scalars.
    static func length(_ text: String) -> Int { text.unicodeScalars.count }

    /// Swift compares strings by canonical equivalence, so NFC is checked on the scalars.
    private static func isNFC(_ text: String) -> Bool {
        text.unicodeScalars.elementsEqual(text.precomposedStringWithCanonicalMapping.unicodeScalars)
    }

    private static func names(aPriceIn text: String) -> Bool {
        !words(text).isDisjoint(with: priceWords) || pricePattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    // MARK: Checks

    static func check(_ listing: Listing, retired: RetiredWords) -> [String] {
        var errors: [String] = []
        if let notes = listing.notes {
            if length(notes) > notesLimit { errors.append("\(Self.notes): \(length(notes)) characters, limit \(notesLimit)") }
        } else {
            errors.append("no text under '## \(notes)'")
        }
        for locale in listing.locales {
            let code = locale.code
            for name in fields where locale.fields[name]?.count != 1 {
                errors.append("\(code): needs exactly one text under '### \(name)'")
            }
            guard fields.allSatisfy({ locale.fields[$0]?.count == 1 }) else { continue }
            let text = Dictionary(uniqueKeysWithValues: fields.map { ($0, locale.fields[$0]![0]) })
            for name in fields {
                let value = text[name]!
                if !isNFC(value) { errors.append("\(code) \(name): not in NFC") }
                if let limit = limits[name], length(value) > limit { errors.append("\(code) \(name): \(length(value)) characters, limit \(limit)") }
            }
            errors += keywordErrors(code, text)
            errors += captionErrors(code, text["Screenshot captions"]!)
            for name in pricedFields where names(aPriceIn: text[name]!) {
                errors.append("\(code) \(name): names a price (guideline 2.3.7)")
            }
        }
        return errors + checkRetired(listing, retired: retired)
    }

    private static func keywordErrors(_ code: String, _ text: [String: String]) -> [String] {
        var errors: [String] = []
        let keywords = text["Keywords"]!
        if keywords.utf8.count > keywordBytes { errors.append("\(code) Keywords: \(keywords.utf8.count) bytes, limit \(keywordBytes)") }
        let listed = keywords.components(separatedBy: ",")
        let named = words(text["Name"]!).union(words(text["Subtitle"]!))
        for keyword in listed {
            if keyword != keyword.trimmingCharacters(in: .whitespacesAndNewlines) || length(keyword) <= 2 {
                errors.append("\(code) Keywords: '\(keyword)' needs more than two characters and no surrounding space")
            }
            if !words(keyword).isDisjoint(with: named) {
                errors.append("\(code) Keywords: '\(keyword)' repeats a word of the name or the subtitle")
            }
        }
        if Set(listed.map(fold)).count != listed.count { errors.append("\(code) Keywords: a keyword is listed twice") }
        return errors
    }

    private static func captionErrors(_ code: String, _ captionText: String) -> [String] {
        var errors: [String] = []
        let captions = captionText.components(separatedBy: "\n")
        if captions.count != captionCount || !captions.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            errors.append("\(code) Screenshot captions: needs exactly \(captionCount) non-empty lines, one for each screenshot, and has \(captions.count)")
        }
        for (index, caption) in captions.enumerated() {
            let parts = caption.components(separatedBy: " | ")
            if parts.count != 2 || !parts.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                errors.append("\(code) Screenshot caption \(index + 1): write it as 'Title | Line below'")
            } else if length(parts[0]) > captionTitleLimit || length(parts[1]) > captionLineLimit {
                errors.append("\(code) Screenshot caption \(index + 1): title \(length(parts[0])) characters (limit \(captionTitleLimit)), "
                              + "line below \(length(parts[1])) (limit \(captionLineLimit))")
            }
        }
        return errors
    }

    // MARK: Retired words

    /// Every retired word a locale's texts use, as (field, word, reason). `texts` is {field: text}.
    static func retiredUses(locale: String, texts: [String: String], entries: [RetiredEntry]) -> [(field: String, word: String, reason: String)] {
        let language = locale.components(separatedBy: "-")[0]
        var found: [(field: String, word: String, reason: String)] = []
        for field in texts.keys.sorted() {
            let text = texts[field]!
            for entry in entries {
                guard entry.languages.contains(language) || entry.languages.contains("*"), !entry.allowedIn.contains(field) else { continue }
                if let only = entry.onlyIn, !only.contains(field) { continue }
                for match in entry.regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    if let range = Range(match.range, in: text) { found.append((field, String(text[range]), entry.reason)) }
                }
            }
        }
        return found
    }

    /// The errors of the retired words. A pending locale is expected to fail: one that passes must leave the baseline.
    static func checkRetired(_ listing: Listing, retired: RetiredWords) -> [String] {
        var errors: [String] = []
        var subjects = listing.locales.map { locale in
            (name: locale.code, texts: locale.fields.compactMapValues(\.first))
        }
        subjects.append((name: "notes", texts: [notes: listing.notes ?? ""]))
        let known = Set(subjects.map(\.name))
        for name in retired.pendingLocales where !known.contains(name) {
            errors.append("retired words: pending '\(name)' is not a locale of the listing")
        }
        for subject in subjects {
            let found = retiredUses(locale: subject.name == "notes" ? notesLanguage : subject.name, texts: subject.texts, entries: retired.entries)
            if retired.pendingLocales.contains(subject.name) {
                if found.isEmpty { errors.append("retired words: \(subject.name) uses none of them: remove it from pendingLocales") }
                continue
            }
            errors += found.map { "\(subject.name) \($0.field): '\($0.word)' names a feature 1.1 lacks (\($0.reason))" }
        }
        return errors
    }

    /// The error when the pending locales grew compared with the target branch's list.
    static func pendingGrowth(pending: [String], base: [String]) -> [String] {
        let grown = Set(pending).subtracting(base).sorted()
        return grown.isEmpty ? [] : ["retired words: pendingLocales grew compared with the target branch: \(grown.joined(separator: ", "))"]
    }

    // MARK: Counts table

    /// The longest title and the longest line below, as "27 / 72 (6 captions)".
    private static func captionLengths(_ captions: [String]) -> String {
        let parts = captions.map { caption -> (Int, Int) in
            guard let range = caption.range(of: " | ") else { return (length(caption), 0) }
            return (length(String(caption[..<range.lowerBound])), length(String(caption[range.upperBound...])))
        }
        return "\(parts.map(\.0).max() ?? 0) / \(parts.map(\.1).max() ?? 0) (\(captions.count) captions)"
    }

    static func countsTable(_ listing: Listing) -> [String] {
        var rows = ["| Locale | Name (30) | Subtitle (30) | Keywords (100 bytes) | Promotional text (170) | Description (4000) "
                    + "| Captions (longest title / line) | What's New (4000) |",
                    "|---|---|---|---|---|---|---|---|"]
        for locale in listing.locales {
            let text = Dictionary(uniqueKeysWithValues: fields.map { ($0, locale.fields[$0]?.first ?? "") })
            let cells: [String] = [String(length(text["Name"]!)), String(length(text["Subtitle"]!)), String(text["Keywords"]!.utf8.count),
                                   String(length(text["Promotional text"]!)), String(length(text["Description"]!)),
                                   captionLengths(text["Screenshot captions"]!.components(separatedBy: "\n")), String(length(text["What's New"]!))]
            rows.append("| " + ([locale.code] + cells).joined(separator: " | ") + " |")
        }
        rows += ["", "\(notes): \(length(listing.notes ?? "")) characters (\(notesLimit))."]
        return rows
    }

    /// The lines of the document with the counts table replaced, or nil when the markers are missing.
    static func replacingCounts(in lines: [String], with table: [String]) -> [String]? {
        guard let start = lines.firstIndex(of: countsStart), let end = lines.firstIndex(of: countsEnd), start < end else { return nil }
        return Array(lines[...start]) + table + Array(lines[end...])
    }
}
