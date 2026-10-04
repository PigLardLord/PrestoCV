import Foundation
import CVDocumentModel

/// One value for each form of address.
struct ByForm<Value: Sendable & Equatable>: Sendable, Equatable {
    let masculine: Value, feminine: Value, neutral: Value
    subscript(form: FormOfAddress) -> Value {
        switch form {
        case .masculine: masculine
        case .feminine: feminine
        case .neutral: neutral
        }
    }
}

/// A text with named holes, read once from the data ("Dear Mr {name},"). Filling is one pass over the pieces, so a value that
/// itself looks like a hole is text and is never read again.
struct LetterTemplate: Sendable, Equatable {
    enum Hole: String, Sendable { case name, day, month, year, place, date }
    enum Piece: Sendable, Equatable { case text(String), hole(Hole) }
    let pieces: [Piece]

    /// nil when the text has a hole outside `holes`, a hole that is not there exactly once, or a brace that opens or closes no hole.
    init?(_ text: String, holes: Set<Hole>) {
        var pieces: [Piece] = [], literal = String.UnicodeScalarView(), seen: [Hole] = []
        var scalars = text.unicodeScalars[...]
        while let scalar = scalars.popFirst() {
            switch scalar {
            case "{":
                var name = "", closed = false
                while let next = scalars.popFirst() {
                    if next == "}" { closed = true; break }
                    name.unicodeScalars.append(next)
                }
                guard closed, let hole = Hole(rawValue: name), holes.contains(hole) else { return nil }
                if !literal.isEmpty { pieces.append(.text(String(literal))); literal = String.UnicodeScalarView() }
                pieces.append(.hole(hole)); seen.append(hole)
            case "}": return nil
            default: literal.append(scalar)
            }
        }
        guard Set(seen) == holes, seen.count == holes.count else { return nil }
        if !literal.isEmpty { pieces.append(.text(String(literal))) }
        self.pieces = pieces
    }

    /// nil when a hole has no value.
    func fill(_ values: [Hole: String]) -> String? {
        var out = ""
        for piece in pieces {
            switch piece {
            case .text(let t): out += t
            case .hole(let h):
                guard let value = values[h] else { return nil }
                out += value
            }
        }
        return out
    }
}

/// How one language writes a letter (R13, ADR 0019): the date, the salutation and the valediction for each form of
/// address, and the labels of the page, in the regional variant that its file names. It is read from the language's
/// JSON file, never from the layout.
struct LetterConventions: Sendable, Equatable {
    static let maxFileBytes = 16_384, maxValueBytes = 200

    /// The regional convention the table is written in, a language and a region (`pt-PT`). A regional tag such as `pt-BR`
    /// reads its language's table, so every reader of a language gets the one variant that its table names.
    let variant: String
    private let dateFormat: LetterTemplate, months: [String], withPlace: LetterTemplate, withoutPlace: LetterTemplate
    /// How the language writes day 1 where it is not the number ("1er"); nil where it is.
    private let firstDay: String?
    private let salutations: ByForm<LetterTemplate>, valedictions: ByForm<String>
    let referenceLabel: String, attachmentsLabel: String

    func monthName(_ month: Int) -> String? { months.indices.contains(month - 1) ? months[month - 1] : nil }

    /// The date in the language's format; nil when the month does not exist.
    func dateText(_ date: LetterDate) -> String? {
        guard let month = monthName(date.month) else { return nil }
        let day = date.day == 1 ? firstDay ?? "1" : String(date.day)
        return dateFormat.fill([.day: day, .month: month, .year: String(date.year)])
    }

    /// The place and the date as the language writes them, or the date alone when there is no place.
    func dateLine(place: String?, date: LetterDate) -> String? {
        guard let text = dateText(date) else { return nil }
        guard let place, !place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return withoutPlace.fill([.date: text]) }
        return withPlace.fill([.place: place, .date: text])
    }

    /// nil when the form of address names the recipient and there is no family name to name.
    func salutation(_ form: FormOfAddress, familyName: String?) -> String? {
        let name = familyName.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        return salutations[form].fill(name.map { [.name: $0] } ?? [:])
    }

    func valediction(_ form: FormOfAddress) -> String { valedictions[form] }

    // MARK: Reading

    /// Strict, bounded and typed: the file's size is checked first; an unknown key, a value of the wrong type or something
    /// that is not an object is a corrupt table; a missing key, an empty or over-long value, a hidden character, a month
    /// count other than twelve or a template with the wrong holes is incomplete, and names its key.
    static func parse(_ data: Data, language: String) throws(LetterConventionsCatalog.Failure) -> LetterConventions {
        typealias Failure = LetterConventionsCatalog.Failure
        guard data.count <= maxFileBytes else { throw Failure.corruptTable(language) }
        let parsed: Any
        do { parsed = try JSONSerialization.jsonObject(with: data) } catch { throw Failure.corruptTable(language) }
        guard let root = parsed as? [String: Any] else { throw Failure.corruptTable(language) }

        func object(_ parent: [String: Any], _ key: String, keys: Set<String>, path: String) throws(Failure) -> [String: Any] {
            guard let value = parent[key] else { throw Failure.incomplete(language: language, key: path) }
            guard let inner = value as? [String: Any], Set(inner.keys).isSubset(of: keys) else { throw Failure.corruptTable(language) }
            return inner
        }
        /// Plain text, as the data may hold it: filled, bounded, with no hidden character and no hole.
        func plain(_ s: String, _ path: String) throws(Failure) -> String {
            guard LetterTemplate(s, holes: []) != nil, isFit(s) else { throw Failure.incomplete(language: language, key: path) }
            return s
        }
        func string(_ parent: [String: Any], _ key: String, path: String) throws(Failure) -> String {
            guard let value = parent[key] else { throw Failure.incomplete(language: language, key: path) }
            guard let text = value as? String else { throw Failure.corruptTable(language) }
            return text
        }
        func template(_ parent: [String: Any], _ key: String, path: String, holes: Set<LetterTemplate.Hole>) throws(Failure) -> LetterTemplate {
            let text = try string(parent, key, path: path)
            guard isFit(text), let template = LetterTemplate(text, holes: holes) else { throw Failure.incomplete(language: language, key: path) }
            return template
        }

        guard Set(root.keys).isSubset(of: ["variant", "date", "salutations", "valedictions", "labels"]) else { throw Failure.corruptTable(language) }
        let variant = try string(root, "variant", path: "variant")
        guard variant.hasPrefix(language + "-"), String(variant.dropFirst(language.count + 1)).fullyMatches("[A-Z]{2}") else { throw Failure.incomplete(language: language, key: "variant") }
        let date = try object(root, "date", keys: ["format", "months", "withPlace", "withoutPlace", "firstDay"], path: "date")
        let salutations = try object(root, "salutations", keys: ["masculine", "feminine", "neutral"], path: "salutations")
        let valedictions = try object(root, "valedictions", keys: ["masculine", "feminine", "neutral"], path: "valedictions")
        let labels = try object(root, "labels", keys: ["reference", "attachments"], path: "labels")

        guard let rawMonths = date["months"] else { throw Failure.incomplete(language: language, key: "date.months") }
        guard let monthTexts = rawMonths as? [String] else { throw Failure.corruptTable(language) }
        guard monthTexts.count == 12 else { throw Failure.incomplete(language: language, key: "date.months") }
        var months: [String] = []
        for text in monthTexts { months.append(try plain(text, "date.months")) }
        var firstDay: String?
        if date["firstDay"] != nil { firstDay = try plain(try string(date, "firstDay", path: "date.firstDay"), "date.firstDay") }

        return LetterConventions(
            variant: variant, dateFormat: try template(date, "format", path: "date.format", holes: [.day, .month, .year]), months: months,
            withPlace: try template(date, "withPlace", path: "date.withPlace", holes: [.place, .date]),
            withoutPlace: try template(date, "withoutPlace", path: "date.withoutPlace", holes: [.date]), firstDay: firstDay,
            salutations: ByForm(masculine: try template(salutations, "masculine", path: "salutations.masculine", holes: [.name]),
                                feminine: try template(salutations, "feminine", path: "salutations.feminine", holes: [.name]),
                                neutral: try template(salutations, "neutral", path: "salutations.neutral", holes: [])),
            valedictions: ByForm(masculine: try plain(try string(valedictions, "masculine", path: "valedictions.masculine"), "valedictions.masculine"),
                                 feminine: try plain(try string(valedictions, "feminine", path: "valedictions.feminine"), "valedictions.feminine"),
                                 neutral: try plain(try string(valedictions, "neutral", path: "valedictions.neutral"), "valedictions.neutral")),
            referenceLabel: try plain(try string(labels, "reference", path: "labels.reference"), "labels.reference"),
            attachmentsLabel: try plain(try string(labels, "attachments", path: "labels.attachments"), "labels.attachments"))
    }

    /// Filled, within the bound in bytes, and with no control, bidirectional or invisible character.
    private static func isFit(_ s: String) -> Bool {
        !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && s.utf8.count <= maxValueBytes
            && !s.unicodeScalars.contains(where: LetterDocumentValidator.hidesOrReorders)
    }
}

/// The conventions are package resources, one JSON file per language plus an index, matched by BCP 47: the full tag, then the
/// primary language subtag. An unsupported language is an error, never a silent fallback to English (R13).
public enum LetterConventionsCatalog {
    public enum Failure: Error, Equatable, Sendable {
        case unsupportedLanguage(String), incomplete(language: String, key: String), corruptTable(String)
    }

    /// The languages with conventions, from the package's own index.
    public static func supportedLanguages() throws(Failure) -> [String] {
        guard let url = Bundle.module.url(forResource: "Resources/Letters/index", withExtension: "json") else { throw .corruptTable("index") }
        let languages: [String]
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= LetterConventions.maxFileBytes else { throw Failure.corruptTable("index") }
            languages = try JSONDecoder().decode([String].self, from: data)
        } catch { throw .corruptTable("index") }
        guard Set(languages).count == languages.count, languages.allSatisfy({ $0.fullyMatches("[a-z]{2,3}") }) else { throw .corruptTable("index") }
        return languages
    }

    static func conventions(for language: String) throws(Failure) -> LetterConventions {
        guard language.fullyMatches(#"[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8}){0,3}"#) else { throw .unsupportedLanguage(language) }
        let supported = try supportedLanguages()
        let primary = String(language.prefix { $0 != "-" }).lowercased()
        for candidate in [language.lowercased(), primary] where supported.contains(candidate) { return try table(candidate) }
        throw .unsupportedLanguage(language)
    }

    /// The index lists the language, so a file that is missing or cannot be read is an error (R7).
    private static func table(_ tag: String) throws(Failure) -> LetterConventions {
        guard let url = Bundle.module.url(forResource: "Resources/Letters/\(tag)", withExtension: "json") else { throw .corruptTable(tag) }
        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw .corruptTable(tag) }
        return try LetterConventions.parse(data, language: tag)
    }
}
