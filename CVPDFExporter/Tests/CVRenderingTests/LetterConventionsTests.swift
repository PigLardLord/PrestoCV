import Testing
import Foundation
import CVDocumentModel
@testable import CVRendering

enum LetterData {
    /// The letter's data in the repository: this file is CVPDFExporter/Tests/CVRenderingTests/….
    static var directory: URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root.appendingPathComponent("Sources/CVRendering/Resources/Letters")
    }

    static func raw(_ language: String) throws -> [String: Any] {
        let data = try Data(contentsOf: directory.appendingPathComponent("\(language).json"))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

/// The language data of the cover letter (R13, ADR 0019): the date format, the salutations, the valedictions and the
/// labels of the page, one JSON file per language and an index, as package resources.
@Suite("ADR 0019 · the letter's conventions come from data, for each of the six languages")
struct LetterConventionsTests {
    static let languages = ["en", "it", "de", "es", "fr", "pt"]

    /// What the files must say. Changing a row is changing the letter's wording, and is reviewed like code.
    /// (language, the variant it is written in, the date of 4 October 2026 with the place "Roma", the date alone, the date of 1 October 2026
    ///  with the place, masculine, feminine and neutral salutations to "Rossi", masculine, feminine and neutral valedictions, the
    ///  reference and attachments labels)
    struct Expected: Sendable, CustomTestStringConvertible {
        let language: String, variant: String, dateLine: String, date: String, firstDateLine: String
        let salutations: [String], valedictions: [String], labels: [String]
        var testDescription: String { language }
    }
    static let expected: [Expected] = [
        Expected(language: "en", variant: "en-GB", dateLine: "Roma, 4 October 2026", date: "4 October 2026", firstDateLine: "Roma, 1 October 2026",
                 salutations: ["Dear Mr Rossi,", "Dear Ms Rossi,", "Dear Sir or Madam,"],
                 valedictions: ["Yours sincerely,", "Yours sincerely,", "Yours faithfully,"], labels: ["Reference", "Enclosures"]),
        Expected(language: "it", variant: "it-IT", dateLine: "Roma, 4 ottobre 2026", date: "4 ottobre 2026", firstDateLine: "Roma, 1 ottobre 2026",
                 salutations: ["Gentile Sig. Rossi,", "Gentile Sig.ra Rossi,", "Gentili Signore e Signori,"],
                 valedictions: ["Distinti saluti,", "Distinti saluti,", "Distinti saluti,"], labels: ["Riferimento", "Allegati"]),
        Expected(language: "de", variant: "de-DE", dateLine: "Roma, 4. Oktober 2026", date: "4. Oktober 2026", firstDateLine: "Roma, 1. Oktober 2026",
                 salutations: ["Sehr geehrter Herr Rossi,", "Sehr geehrte Frau Rossi,", "Sehr geehrte Damen und Herren,"],
                 valedictions: ["Mit freundlichen Grüßen", "Mit freundlichen Grüßen", "Mit freundlichen Grüßen"], labels: ["Bezug", "Anlagen"]),
        Expected(language: "es", variant: "es-ES", dateLine: "Roma, 4 de octubre de 2026", date: "4 de octubre de 2026", firstDateLine: "Roma, 1 de octubre de 2026",
                 salutations: ["Estimado Sr. Rossi:", "Estimada Sra. Rossi:", "Estimados señores y señoras:"],
                 valedictions: ["Atentamente,", "Atentamente,", "Atentamente,"], labels: ["Referencia", "Anexos"]),
        Expected(language: "fr", variant: "fr-FR", dateLine: "Roma, le 4 octobre 2026", date: "4 octobre 2026", firstDateLine: "Roma, le 1er octobre 2026",
                 salutations: ["Monsieur Rossi,", "Madame Rossi,", "Madame, Monsieur,"],
                 valedictions: ["Je vous prie d’agréer, Monsieur, l’expression de mes salutations distinguées.",
                                "Je vous prie d’agréer, Madame, l’expression de mes salutations distinguées.",
                                "Je vous prie d’agréer, Madame, Monsieur, l’expression de mes salutations distinguées."],
                 labels: ["Référence", "Pièces jointes"]),
        Expected(language: "pt", variant: "pt-PT", dateLine: "Roma, 4 de outubro de 2026", date: "4 de outubro de 2026", firstDateLine: "Roma, 1 de outubro de 2026",
                 salutations: ["Exmo. Senhor Rossi,", "Exma. Senhora Rossi,", "Exmos. Senhores,"],
                 valedictions: ["Com os melhores cumprimentos,", "Com os melhores cumprimentos,", "Com os melhores cumprimentos,"],
                 labels: ["Referência", "Anexos"]),
    ]
    static let forms = FormOfAddress.allCases
    static let day = LetterDate(year: 2026, month: 10, day: 4)
    static let firstDay = LetterDate(year: 2026, month: 10, day: 1)

    @Test("the index lists the six languages, which are the ones the document model accepts")
    func index() throws {
        let supported = try LetterConventionsCatalog.supportedLanguages()
        #expect(supported == Self.languages)
        #expect(Set(supported) == Set(LetterDocument.supportedLanguages) && supported.count == LetterDocument.supportedLanguages.count)
    }

    @Test("every language has a file, and no file is outside the index")
    func filesMatchTheIndex() throws {
        let names = try FileManager.default.contentsOfDirectory(atPath: LetterData.directory.path).map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
        #expect(Set(names) == Set(Self.languages).union(["index"]) && names.count == Self.languages.count + 1)
    }

    @Test("every language's file has exactly the keys of the schema, and every value is filled", arguments: languages)
    func completeTables(language: String) throws {
        let object = try LetterData.raw(language)
        #expect(Set(object.keys) == ["variant", "date", "salutations", "valedictions", "labels"], "\(language) top level")
        let variant = try #require(object["variant"] as? String)
        #expect(variant.fullyMatches("\(language)-[A-Z]{2}"), "\(language) is written in \(variant)")
        let date = try #require(object["date"] as? [String: Any])
        // Only a language that writes the first of the month differently has the optional key.
        #expect(Set(date.keys) == (language == "fr" ? ["format", "months", "withPlace", "withoutPlace", "firstDay"] : ["format", "months", "withPlace", "withoutPlace"]), "\(language) date")
        #expect(Set(try #require(object["salutations"] as? [String: Any]).keys) == ["masculine", "feminine", "neutral"], "\(language) salutations")
        #expect(Set(try #require(object["valedictions"] as? [String: Any]).keys) == ["masculine", "feminine", "neutral"], "\(language) valedictions")
        #expect(Set(try #require(object["labels"] as? [String: Any]).keys) == ["reference", "attachments"], "\(language) labels")
        let months = try #require(date["months"] as? [String])
        #expect(months.count == 12 && Set(months).count == 12 && !months.contains { $0.isEmpty })
        _ = try LetterConventionsCatalog.conventions(for: language)      // and the strict reader accepts it
    }

    @Test("each language writes the date, the salutation, the valediction and the labels of its own convention", arguments: expected)
    func writtenText(expected: Expected) throws {
        let conventions = try LetterConventionsCatalog.conventions(for: expected.language)
        #expect(conventions.variant == expected.variant)
        #expect(conventions.dateText(Self.day) == expected.date)
        #expect(conventions.dateLine(place: "Roma", date: Self.day) == expected.dateLine)
        #expect(conventions.dateLine(place: "Roma", date: Self.firstDay) == expected.firstDateLine)
        #expect(conventions.dateLine(place: nil, date: Self.day) == expected.date)
        #expect(conventions.dateLine(place: "", date: Self.day) == expected.date)
        for (index, form) in Self.forms.enumerated() {
            #expect(conventions.salutation(form, familyName: "Rossi") == expected.salutations[index], "\(expected.language) \(form) salutation")
            #expect(conventions.valediction(form) == expected.valedictions[index], "\(expected.language) \(form) valediction")
        }
        #expect([conventions.referenceLabel, conventions.attachmentsLabel] == expected.labels)
    }

    @Test("all twelve months are named, in order, in every language", arguments: languages)
    func months(language: String) throws {
        let conventions = try LetterConventionsCatalog.conventions(for: language)
        let names = (1...12).compactMap { conventions.monthName($0) }
        #expect(names.count == 12 && Set(names).count == 12)
        #expect(conventions.monthName(0) == nil && conventions.monthName(13) == nil && conventions.monthName(-1) == nil)
        #expect(conventions.dateText(LetterDate(year: 2026, month: 13, day: 1)) == nil)
    }

    @Test("French writes the first of the month as 1er, and no other day as an ordinal")
    func frenchFirst() throws {
        let fr = try LetterConventionsCatalog.conventions(for: "fr")
        #expect(fr.dateText(LetterDate(year: 2026, month: 10, day: 1)) == "1er octobre 2026")
        #expect(fr.dateText(LetterDate(year: 2026, month: 1, day: 1)) == "1er janvier 2026")
        #expect(fr.dateLine(place: "Paris", date: LetterDate(year: 2027, month: 3, day: 1)) == "Paris, le 1er mars 2027")
        for day in [2, 10, 11, 21, 31] { #expect(fr.dateText(LetterDate(year: 2026, month: 10, day: day)) == "\(day) octobre 2026", "day \(day)") }
        #expect(try LetterConventionsCatalog.conventions(for: "en").dateText(LetterDate(year: 2026, month: 10, day: 1)) == "1 October 2026")
    }

    static let regionalCases: [(String, String)] = [("pt-BR", "pt"), ("pt-PT", "pt"), ("de-CH", "de"), ("en-GB", "en"), ("EN-us", "en"), ("fr-CA", "fr"), ("es-419", "es"), ("it-IT", "it")]
    @Test("a regional tag uses its language's conventions: pt-BR reads the European Portuguese of pt-PT", arguments: regionalCases)
    func regionalTags(tag: String, language: String) throws {
        #expect(try LetterConventionsCatalog.conventions(for: tag) == LetterConventionsCatalog.conventions(for: language))
    }

    @Test("an unsupported language is a typed error, never English", arguments: ["ja", "fil", "fi", "nl", "e", "", "en_GB", "en-\n", "../en", "en/../it", "index", "ENGLISH", "-en", "en-"])
    func unsupportedLanguage(tag: String) {
        #expect(throws: LetterConventionsCatalog.Failure.unsupportedLanguage(tag)) { _ = try LetterConventionsCatalog.conventions(for: tag) }
    }

    @Test("a name that looks like a hole in a template is text, never read again")
    func holesInValuesAreText() throws {
        let conventions = try LetterConventionsCatalog.conventions(for: "en")
        #expect(conventions.salutation(.masculine, familyName: "{date} {name}") == "Dear Mr {date} {name},")
        #expect(conventions.dateLine(place: "{date}{place}", date: Self.day) == "{date}{place}, 4 October 2026")
        #expect(conventions.salutation(.neutral, familyName: "Rossi") == "Dear Sir or Madam,")       // a neutral salutation names nobody
    }

    @Test("a salutation that names someone cannot be written without the name")
    func missingName() throws {
        let conventions = try LetterConventionsCatalog.conventions(for: "en")
        #expect(conventions.salutation(.masculine, familyName: nil) == nil && conventions.salutation(.feminine, familyName: nil) == nil)
        #expect(conventions.salutation(.neutral, familyName: nil) == "Dear Sir or Madam,")
    }
}

/// Hostile and broken tables: the reader is strict, bounded and typed (R7, R13).
@Suite("ADR 0019 · a broken or hostile conventions table is a typed error")
struct LetterConventionsReaderTests {
    /// The English table as an editable object.
    func base() throws -> [String: Any] { try LetterData.raw("en") }

    func parse(_ object: [String: Any]) throws -> LetterConventions {
        try LetterConventions.parse(try JSONSerialization.data(withJSONObject: object), language: "en")
    }

    func edited(_ change: (inout [String: Any]) -> Void) throws -> [String: Any] {
        var object = try base()
        change(&object)
        return object
    }

    /// Replaces `key` of the object at `path`.
    func setting(_ path: String, _ key: String, to value: Any?) throws -> [String: Any] {
        try edited { object in
            var inner = object[path] as? [String: Any] ?? [:]
            inner[key] = value
            object[path] = inner
        }
    }

    @Test("the English table, unedited, is accepted")
    func baseline() throws { _ = try parse(try base()) }

    @Test("an unknown key is a corrupt table, at the top and inside every object")
    func unknownKeys() throws {
        var objects: [[String: Any]] = []
        objects.append(try edited { $0["extra"] = "x" })
        objects.append(try setting("date", "extra", to: "x"))
        objects.append(try setting("salutations", "informal", to: "Hi"))
        objects.append(try setting("valedictions", "extra", to: "x"))
        objects.append(try setting("labels", "extra", to: "x"))
        for object in objects {
            #expect(throws: LetterConventionsCatalog.Failure.corruptTable("en")) { _ = try parse(object) }
        }
    }

    static let missingKeys: [(String, String)] = [
        ("date", "format"), ("date", "months"), ("date", "withPlace"), ("date", "withoutPlace"), ("salutations", "masculine"), ("salutations", "feminine"),
        ("salutations", "neutral"), ("valedictions", "masculine"), ("valedictions", "feminine"), ("valedictions", "neutral"), ("labels", "reference"), ("labels", "attachments"),
    ]

    @Test("a missing key names itself", arguments: missingKeys)
    func missingKey(path: String, key: String) throws {
        let object = try setting(path, key, to: nil)
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "\(path).\(key)")) { _ = try parse(object) }
    }

    @Test("a table names the variant it is written in: a missing one is incomplete, and a malformed, foreign or hidden one too",
          arguments: ["", "en", "en-gb", "EN-GB", "en-GBR", "en_GB", "pt-PT", "de-DE", " en-GB", "en-GB\n", "{name}", "en-G\u{200B}B"])
    func badVariant(variant: String) throws {
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "variant")) { _ = try parse(try edited { $0["variant"] = variant }) }
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "variant")) { _ = try parse(try edited { $0["variant"] = nil }) }
        #expect(throws: LetterConventionsCatalog.Failure.corruptTable("en")) { _ = try parse(try edited { $0["variant"] = 3 }) }
    }

    @Test("a table is read for the language it is written in, and no other")
    func tableForAnotherLanguage() throws {
        let data = try JSONSerialization.data(withJSONObject: base())
        _ = try LetterConventions.parse(data, language: "en")
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "de", key: "variant")) { _ = try LetterConventions.parse(data, language: "de") }
    }

    @Test("the first day of the month is optional, and is written where the table gives it")
    func firstDay() throws {
        let without = try parse(try base())
        #expect(without.dateText(LetterDate(year: 2026, month: 10, day: 1)) == "1 October 2026")
        let with = try parse(try setting("date", "firstDay", to: "1st"))
        #expect(with.dateText(LetterDate(year: 2026, month: 10, day: 1)) == "1st October 2026")
        #expect(with.dateText(LetterDate(year: 2026, month: 10, day: 2)) == "2 October 2026")
        #expect(with != without)
    }

    @Test("a first day over the bound, or with a hidden character, is incomplete", arguments: [String(repeating: "x", count: 201), "1\u{200B}er", "1\ner", "\u{202E}1er"])
    func badFirstDay(text: String) throws {
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "date.firstDay")) { _ = try parse(try setting("date", "firstDay", to: text)) }
    }

    @Test("a missing section names itself", arguments: ["date", "salutations", "valedictions", "labels"])
    func missingSection(path: String) throws {
        let object = try edited { $0[path] = nil }
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: path)) { _ = try parse(object) }
    }

    static let emptyValues: [(String, String, String)] = [
        ("date", "firstDay", ""), ("date", "firstDay", " "),
        ("date", "format", ""), ("salutations", "neutral", ""), ("salutations", "masculine", " \t "), ("valedictions", "feminine", ""), ("labels", "reference", " "),
        ("labels", "attachments", ""), ("date", "withoutPlace", ""),
    ]

    @Test("an empty or blank value is incomplete", arguments: emptyValues)
    func emptyValue(path: String, key: String, value: String) throws {
        let object = try setting(path, key, to: value)
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "\(path).\(key)")) { _ = try parse(object) }
    }

    @Test("the months are twelve, each named", arguments: [0, 1, 11, 13, 40])
    func monthCount(count: Int) throws {
        let object = try setting("date", "months", to: (0..<count).map { "month\($0)" })
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "date.months")) { _ = try parse(object) }
        let blank = try setting("date", "months", to: (0..<12).map { $0 == 5 ? "" : "month\($0)" })
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "date.months")) { _ = try parse(blank) }
    }

    /// A JSON value that is not what the schema asks for.
    enum Wrong: Sendable {
        case number, string, strings, bool, numbers
        var value: Any {
            switch self {
            case .number: 3
            case .string: "January"
            case .strings: ["Dear"]
            case .bool: true
            case .numbers: [1, 2, 3]
            }
        }
    }

    static let wrongTypes: [(String, String, Wrong)] = [
        ("date", "format", Wrong.number), ("date", "firstDay", .number), ("date", "firstDay", .strings), ("date", "months", .string), ("salutations", "neutral", .strings), ("labels", "reference", .bool), ("date", "months", .numbers),
    ]

    @Test("a value of the wrong type is a corrupt table", arguments: wrongTypes)
    func wrongType(path: String, key: String, value: Wrong) throws {
        #expect(throws: LetterConventionsCatalog.Failure.corruptTable("en")) { _ = try parse(try setting(path, key, to: value.value)) }
    }

    @Test("a section that is not an object is a corrupt table", arguments: ["date", "salutations", "valedictions", "labels"])
    func sectionNotAnObject(path: String) throws {
        #expect(throws: LetterConventionsCatalog.Failure.corruptTable("en")) { _ = try parse(try edited { $0[path] = "x" }) }
    }

    @Test("what is not an object, or not JSON, is a corrupt table", arguments: ["[]", "null", "\"en\"", "not json", "", "{", "3"])
    func notAnObject(json: String) {
        #expect(throws: LetterConventionsCatalog.Failure.corruptTable("en")) { _ = try LetterConventions.parse(Data(json.utf8), language: "en") }
    }

    @Test("a file over the bound is corrupt before it is read as JSON")
    func oversized() throws {
        let padded = try JSONSerialization.data(withJSONObject: base()) + Data(repeating: 0x20, count: LetterConventions.maxFileBytes)
        #expect(throws: LetterConventionsCatalog.Failure.corruptTable("en")) { _ = try LetterConventions.parse(padded, language: "en") }
    }

    @Test("a value over the bound is incomplete, and one at the bound is accepted")
    func longValue() throws {
        let over = String(repeating: "x", count: LetterConventions.maxValueBytes + 1)
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "labels.reference")) { _ = try parse(try setting("labels", "reference", to: over)) }
        _ = try parse(try setting("labels", "reference", to: String(repeating: "x", count: LetterConventions.maxValueBytes)))
        // Bytes, not characters.
        let wide = String(repeating: "é", count: LetterConventions.maxValueBytes / 2 + 1)
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "labels.reference")) { _ = try parse(try setting("labels", "reference", to: wide)) }
    }

    @Test("control, bidirectional and invisible characters are refused in a value", arguments: ["a\u{0007}b", "a\nb", "\u{202E}x", "x\u{200B}", "x\u{2066}y", "x\u{FEFF}y", "x\u{2028}y"])
    func hiddenCharacters(text: String) throws {
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "valedictions.neutral")) { _ = try parse(try setting("valedictions", "neutral", to: text)) }
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "date.months")) {
            _ = try parse(try setting("date", "months", to: (0..<12).map { $0 == 3 ? text : "month\($0)" }))
        }
    }

    static let badTemplates: [(String, String, String)] = [
        ("date", "firstDay", "{day}"), ("date", "firstDay", "1{year}"),
        ("date", "format", "{day} {month}"), ("date", "format", "{day} {month} {year} {year}"), ("date", "format", "{day} {month} {year} {name}"),
        ("date", "format", "{day} {month} {yeer}"), ("date", "format", "{day {month} {year}"), ("date", "format", "{day} {month} {year}}"), ("date", "format", "{}{day}{month}{year}"),
        ("date", "withPlace", "{place}"), ("date", "withPlace", "{date}"), ("date", "withPlace", "{place}, {date} {date}"), ("date", "withoutPlace", "{place}"),
        ("date", "withoutPlace", "today"), ("salutations", "masculine", "Dear Sir,"), ("salutations", "feminine", "Dear {name} {name},"),
        ("salutations", "neutral", "Dear {name},"), ("salutations", "masculine", "Dear {Name},"), ("salutations", "masculine", "Dear { name },"),
    ]

    @Test("a template has the holes its place needs, once each, and no other", arguments: badTemplates)
    func templateHoles(path: String, key: String, template: String) throws {
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "\(path).\(key)")) { _ = try parse(try setting(path, key, to: template)) }
    }

    @Test("a valediction and a label are plain text: a hole in them is refused")
    func noHolesInPlainText() throws {
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "valedictions.masculine")) { _ = try parse(try setting("valedictions", "masculine", to: "Yours, {name}")) }
        #expect(throws: LetterConventionsCatalog.Failure.incomplete(language: "en", key: "labels.reference")) { _ = try parse(try setting("labels", "reference", to: "{date}")) }
    }
}
