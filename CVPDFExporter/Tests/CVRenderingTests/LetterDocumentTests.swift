import Testing
import Foundation
@testable import CVDocumentModel

/// A letter that populates every field of `LetterDocument`, in Italian.
let letterFixture = LetterDocument(
    language: "it",
    sender: Person(name: "Ada Lovelace", professionalTitle: "Analista", email: "ada@example.com", phone: "+39 06 1234567",
                   location: "Via Roma 1, 00100 Roma", website: "https://ada.example"),
    recipient: LetterRecipient(formOfAddress: .feminine, name: "Maria Rossi", familyName: "Rossi", company: "Babbage & Co",
                               address: ["Via Milano 2", "20100 Milano"]),
    place: "Roma",
    date: LetterDate(year: 2026, month: 10, day: 4),
    reference: "REF-2026-14",
    subject: "Candidatura per la posizione di Analista",
    body: ["Scrivo per candidarmi alla posizione di Analista presso Babbage & Co.", "In allegato trova il mio curriculum, che racconta {{title}} <b>letteralmente</b>."],
    closing: "Resto a disposizione per un colloquio.",
    name: "Ada Lovelace",
    attachments: ["Curriculum vitae", "Certificato di laurea"])

/// Every text field of a `LetterDocument`, one entry per value, so that a test can put something hostile into each of them.
/// `fieldsAreComplete` fails when the model gains a field that is not listed here.
struct LetterTextField: Sendable, CustomTestStringConvertible {
    /// What kind of rule a field follows. The letter's own lines are one line and trimmed; a paragraph and the closing may hold
    /// line breaks; the sender is a `Person`, held to the rule that `CVDocumentValidator` applies to one: line breaks allowed, no
    /// trimming, and the CV's bound.
    enum Kind: Sendable { case line, paragraph, person }
    let name: String
    /// What the validator calls the field in its reasons.
    let what: String
    let kind: Kind
    let set: @Sendable (inout LetterDocument, String) -> Void
    var testDescription: String { name }
    var multiline: Bool { kind != .line }
    var trimmed: Bool { kind == .line }
    var maxBytes: Int { kind == .person ? CVDocumentValidator.maxTextBytes : LetterDocumentValidator.maxTextBytes }

    static let all: [LetterTextField] = {
        var all: [LetterTextField] = []
        func add(_ name: String, _ what: String, _ kind: Kind = .line, _ set: @escaping @Sendable (inout LetterDocument, String) -> Void) {
            all.append(LetterTextField(name: name, what: what, kind: kind, set: set))
        }
        add("sender.name", "the sender's name", .person) { $0.sender.name = $1 }
        add("sender.professionalTitle", "the sender's title", .person) { $0.sender.professionalTitle = $1 }
        add("sender.email", "the sender's email", .person) { $0.sender.email = $1 }
        add("sender.phone", "the sender's phone", .person) { $0.sender.phone = $1 }
        add("sender.location", "the sender's location", .person) { $0.sender.location = $1 }
        add("sender.website", "the sender's website", .person) { $0.sender.website = $1 }
        add("recipient.name", "the recipient's name") { $0.recipient.name = $1 }
        add("recipient.familyName", "the recipient's family name") { $0.recipient.familyName = $1 }
        add("recipient.company", "the recipient's company") { $0.recipient.company = $1 }
        add("recipient.address[0]", "an address line") { $0.recipient.address[0] = $1 }
        add("recipient.address[1]", "an address line") { $0.recipient.address[1] = $1 }
        add("place", "the place") { $0.place = $1 }
        add("reference", "the reference") { $0.reference = $1 }
        add("subject", "the subject") { $0.subject = $1 }
        add("body[0]", "a paragraph", .paragraph) { $0.body[0] = $1 }
        add("body[1]", "a paragraph", .paragraph) { $0.body[1] = $1 }
        add("closing", "the closing", .paragraph) { $0.closing = $1 }
        add("name", "the name") { $0.name = $1 }
        add("attachments[0]", "an attachment") { $0.attachments[0] = $1 }
        add("attachments[1]", "an attachment") { $0.attachments[1] = $1 }
        return all
    }()
}

/// The String values of a value, found by reflection, in declaration order.
func stringLeaves(of value: Any) -> [String] {
    if let s = value as? String { return [s] }
    return Mirror(reflecting: value).children.flatMap { child -> [String] in
        let inner = Mirror(reflecting: child.value)
        if inner.displayStyle == .optional { return inner.children.first.map { stringLeaves(of: $0.value) } ?? [] }
        return stringLeaves(of: child.value)
    }
}

func invalid(_ document: LetterDocument) -> String? {
    do { try LetterDocumentValidator.validate(document); return nil } catch { return error.reason }
}

/// Refused in every field, as in a CV's text: control characters, and the bidirectional embeddings, overrides and isolates that
/// reorder what is printed.
let hostileLetterText: [String] = [
    "\u{0007}", "a\u{0000}b", "tab\there", "carriage\rreturn", "a\r\nb", "a\u{000B}b", "a\u{000C}b", "\u{001B}[31m", "\u{007F}", "x\u{0085}y",
    "\u{202E}evil", "a\u{2066}b", "x\u{202A}y", "x\u{202B}y", "x\u{202C}y", "x\u{202D}y", "x\u{2067}y", "x\u{2068}y", "x\u{2069}y",
]

/// Accepted in every field, as in a CV's text, because Authoring keeps them: the joiners of emoji sequences and of scripts, the
/// soft hyphen, the zero-width and direction marks, tag sequences (the flag of England), and the line and paragraph separators.
let keptLetterText: [String] = [
    "x\u{200B}y", "x\u{200C}y", "x\u{200D}y", "👩\u{200D}💻 and 👨\u{200D}👩\u{200D}👧", "x\u{2060}y", "x\u{FEFF}y", "co\u{00AD}operate",
    "x\u{E0041}y", "🏴\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}", "x\u{2028}y", "x\u{2029}y", "x\u{200E}y", "x\u{200F}y", "x\u{061C}y",
]

/// A line break: accepted in a paragraph and in the closing, refused in a field that holds one line.
let lineBreakLetterText: [String] = ["a\nb", "a\n\nb", "first\nsecond\nthird", "\nleading", "trailing\n"]

@Suite("ADR 0019 · LetterDocument is a JSON contract")
struct LetterDocumentContractTests {
    @Test("round trip is lossless, and the JSON names its version and its form of address")
    func roundTrip() throws {
        let data = try JSONEncoder().encode(letterFixture)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains(#""schemaVersion":1"#) && json.contains(#""formOfAddress":"feminine""#))
        #expect(try JSONDecoder().decode(LetterDocument.self, from: data) == letterFixture)
    }

    @Test("the fixture is valid, and populates every text field the tests below attack")
    func fixtureIsValid() throws {
        try LetterDocumentValidator.validate(letterFixture)
        // The language is the one text value that is not a field of the page: the tests attack it on its own.
        #expect(stringLeaves(of: letterFixture).count == LetterTextField.all.count + 1)
    }

    @Test("the six languages are the ones the page has conventions for, and a regional tag counts as its language",
          arguments: ["en", "it", "de", "es", "fr", "pt", "en-GB", "pt-BR", "de-CH", "ES", "es-419"])
    func supportedLanguage(language: String) throws {
        var letter = letterFixture
        letter.language = language
        try LetterDocumentValidator.validate(letter)
    }

    @Test("an unsupported language is refused, never read as English", arguments: ["", "ja", "fil", "e", "english", "en_GB", "en-\n", "en-", "-en", "xx-en", "en-GB-x-a-b-c-d", "it\u{200B}"])
    func unsupportedLanguage(language: String) {
        var letter = letterFixture
        letter.language = language
        #expect(invalid(letter) == "language is not supported")
    }

    @Test("a field that is too long is refused, whichever field it is", arguments: LetterTextField.all)
    func oversizedField(field: LetterTextField) {
        var letter = letterFixture
        field.set(&letter, String(repeating: "x", count: field.maxBytes + 1))
        #expect(invalid(letter) == LetterDocumentValidator.textReason(field.what))
        field.set(&letter, String(repeating: "x", count: field.maxBytes))
        #expect(invalid(letter) == nil)
    }

    @Test("text is bounded in bytes: a letter followed by endless combining marks is one character and is refused")
    func combiningMarks() {
        let zalgo = "a" + String(repeating: "\u{0301}", count: 20_000)
        #expect(zalgo.count == 1)
        var letter = letterFixture
        letter.body[0] = zalgo
        #expect(invalid(letter) != nil)
    }

    /// A letter with every field at its bound: each field is `unit` repeated to exactly the field's bound in bytes, which is the CV's
    /// for the sender's six fields and the letter's own for the rest.
    static func letterAtEveryBound(_ unit: String) -> LetterDocument {
        func fill(_ bytes: Int) -> String { String(repeating: unit, count: bytes / unit.utf8.count) }
        let line = fill(LetterDocumentValidator.maxTextBytes), personal = fill(CVDocumentValidator.maxTextBytes)
        var letter = letterFixture
        letter.sender = Person(name: personal, professionalTitle: personal, email: personal, phone: personal, location: personal, website: personal)
        letter.recipient = LetterRecipient(formOfAddress: .masculine, name: line, familyName: line, company: line,
                                           address: Array(repeating: line, count: LetterDocumentValidator.maxAddressLines))
        letter.place = line; letter.reference = line; letter.subject = line; letter.closing = line; letter.name = line
        letter.body = Array(repeating: line, count: LetterDocumentValidator.maxParagraphs)
        letter.attachments = Array(repeating: line, count: LetterDocumentValidator.maxAttachments)
        return letter
    }

    /// The JSON text of a letter as a producer writes it that escapes every scalar outside ASCII: a scalar of four bytes in
    /// UTF-8 takes twelve bytes, a surrogate pair of escapes, which is the most any scalar takes.
    static func escapingEveryNonASCII(_ json: String) -> String {
        var out = ""
        for scalar in json.unicodeScalars {
            if scalar.isASCII { out.unicodeScalars.append(scalar); continue }
            for unit in String(scalar).utf16 { out += String(format: "\\u%04x", unit) }
        }
        return out
    }

    @Test("a letter with every field at its bound is accepted, however its JSON is written, and the bounds say how large that is")
    func everyFieldAtItsBound() throws {
        let line = LetterDocumentValidator.maxTextBytes, personal = CVDocumentValidator.maxTextBytes
        #expect(line == 10_000 && personal == 16_384)
        // The letter's own fields of one line: the signature, 3 of the recipient, its address lines, the place, the reference and the
        // subject, and the attachments. Its fields of several: the paragraphs and the closing. The sender's 6, as a CV's person has them.
        let lines = 1 + 3 + LetterDocumentValidator.maxAddressLines + 3 + LetterDocumentValidator.maxAttachments
        let several = LetterDocumentValidator.maxParagraphs + 1
        #expect(lines == 35 && several == 22)
        #expect(LetterDocumentValidator.maxLetterTextBytes == (lines + several) * line + 6 * personal && LetterDocumentValidator.maxLetterTextBytes == 668_304)
        for unit in ["x", "🙂"] {
            let letter = Self.letterAtEveryBound(unit)
            #expect(stringLeaves(of: letter).filter { $0 != letter.language }.reduce(0) { $0 + $1.utf8.count } == LetterDocumentValidator.maxLetterTextBytes)
            try LetterDocumentValidator.validate(letter)
            let plain = try JSONEncoder().encode(letter)
            #expect(plain.count <= LetterDocumentValidator.maxJSONBytes)
            #expect(try LetterDocumentValidator.decode(json: plain) == letter)
            let escaped = Data(Self.escapingEveryNonASCII(String(decoding: plain, as: UTF8.self)).utf8)
            #expect(escaped.count <= LetterDocumentValidator.maxJSONBytes, "\(escaped.count) bytes")
            #expect(try LetterDocumentValidator.decode(json: escaped) == letter)
        }
        // The largest letter in JSON is the one of emoji: three times its text, and still within the bound.
        let widest = Data(Self.escapingEveryNonASCII(String(decoding: try JSONEncoder().encode(Self.letterAtEveryBound("🙂")), as: UTF8.self)).utf8)
        #expect(widest.count > 3 * LetterDocumentValidator.maxLetterTextBytes - 1_000 && widest.count <= LetterDocumentValidator.maxJSONBytes)
    }

    @Test("a letter at the bounds that Authoring keeps is accepted: lines and paragraphs of 10,000 bytes, an opening and 20 paragraphs, 20 attachments, 6 address lines")
    func authoringBounds() throws {
        #expect(LetterDocumentValidator.maxTextBytes == 10_000 && LetterDocumentValidator.maxAttachments >= 20)
        #expect(LetterDocumentValidator.maxParagraphs >= 1 + 20 && LetterDocumentValidator.maxAddressLines >= 6)
        let line = String(repeating: "x", count: 10_000)
        let paragraph = String(repeating: "word\n", count: 1_999) + "word"          // 9,995 bytes, multi-line
        var letter = letterFixture
        letter.recipient = LetterRecipient(formOfAddress: .feminine, name: line, familyName: line, company: line, address: Array(repeating: line, count: 6))
        letter.reference = line; letter.subject = line
        letter.body = Array(repeating: paragraph, count: 1 + 20)      // the opening, and the paragraphs
        letter.closing = paragraph
        letter.attachments = Array(repeating: line, count: 20)
        try LetterDocumentValidator.validate(letter)
        #expect(try LetterDocumentValidator.decode(json: try JSONEncoder().encode(letter)) == letter)
    }

    @Test("a line break is accepted in a paragraph and in the closing, and refused in a field that holds one line",
          arguments: LetterTextField.all, lineBreakLetterText)
    func lineBreaks(field: LetterTextField, text: String) {
        var letter = letterFixture
        field.set(&letter, text)
        let reason = LetterDocumentValidator.textReason(field.what)
        #expect(invalid(letter) == (field.multiline ? nil : reason), "\(field.name) with \(text.unicodeScalars.map(\.value))")
    }

    @Test("a line break survives the JSON round trip in a paragraph")
    func lineBreaksInJSON() throws {
        var letter = letterFixture
        letter.body[0] = "First line\nSecond line"
        letter.closing = "Thanks,\nAda"
        #expect(try LetterDocumentValidator.decode(json: try JSONEncoder().encode(letter)) == letter)
    }

    @Test("lists are bounded: paragraphs, address lines and attachments")
    func counts() {
        var letter = letterFixture
        letter.body = Array(repeating: "x", count: LetterDocumentValidator.maxParagraphs + 1)
        #expect(invalid(letter) == "too many paragraphs")
        letter = letterFixture
        letter.recipient.address = Array(repeating: "x", count: LetterDocumentValidator.maxAddressLines + 1)
        #expect(invalid(letter) == "too many address lines")
        letter = letterFixture
        letter.attachments = Array(repeating: "x", count: LetterDocumentValidator.maxAttachments + 1)
        #expect(invalid(letter) == "too many attachments")
        letter = letterFixture
        letter.body = Array(repeating: "x", count: LetterDocumentValidator.maxParagraphs)
        letter.recipient.address = Array(repeating: "x", count: LetterDocumentValidator.maxAddressLines)
        letter.attachments = Array(repeating: "x", count: LetterDocumentValidator.maxAttachments)
        #expect(invalid(letter) == nil)
    }

    @Test("control characters and bidirectional overrides are refused in every field", arguments: LetterTextField.all, hostileLetterText)
    func hostileCharacters(field: LetterTextField, text: String) {
        var letter = letterFixture
        field.set(&letter, text)
        #expect(invalid(letter) == LetterDocumentValidator.textReason(field.what), "\(field.name) accepted \(text.unicodeScalars.map(\.value))")
    }

    @Test("a reason names the field that was refused, in each field", arguments: LetterTextField.all)
    func reasonsNameTheField(field: LetterTextField) {
        var letter = letterFixture
        field.set(&letter, "a\u{0007}b")
        #expect(invalid(letter) == "\(field.what) is too long, or it has control characters or bidirectional overrides")
        #expect(invalid(letter)?.hasPrefix(field.what) == true)
    }

    /// The personal details as Authoring keeps them (the shapes are those of `PersonalDetails` and its fixtures, which this package
    /// cannot import): values are not trimmed, and a location may hold several lines.
    static let savedSenders: [Person] = [
        Person(name: "Ada Lovelace", professionalTitle: "iOS Engineer", email: "ada@example.com", phone: "+39 06 1234567", location: "Roma", website: "https://ada.example"),
        Person(name: "Ada Lovelace", professionalTitle: "iOS Engineer", email: "ada@example.com", phone: "+39 06 1234567", location: "Via Roma 1\n00100 Roma", website: "https://ada.example"),
        Person(name: " Ada Lovelace ", professionalTitle: "iOS Engineer", location: "Via Roma 1\n00100 Roma\nItalia"),
        Person(name: "Ada Lovelace\n", professionalTitle: "  iOS Engineer", email: " ada@example.com", phone: "+39 06 1234567 ", location: "\nRoma\n\n", website: " https://ada.example"),
        Person(name: "A", professionalTitle: "", email: "", phone: "", location: "", website: ""),
    ]

    @Test("a sender that a CV keeps is accepted by the letter validator, in the six fields: the rule is the CV's", arguments: savedSenders)
    func savedSender(person: Person) throws {
        try CVDocumentValidator.validate(CVDocument(language: "en", person: person, sections: []))
        var letter = letterFixture
        letter.sender = person
        try LetterDocumentValidator.validate(letter)
        #expect(try LetterDocumentValidator.decode(json: try JSONEncoder().encode(letter)) == letter)
    }

    @Test("the sender is refused as a CV's person is: a name that says nothing, a text over the CV's bound, a control character")
    func senderIsRefusedAsACVPersonIs() throws {
        for person in [Person(name: " \n "), Person(name: "A", location: String(repeating: "x", count: CVDocumentValidator.maxTextBytes + 1)),
                       Person(name: "A", email: "a\u{0007}b"), Person(name: "A", location: "a\u{202E}b"), Person(name: "A\tB")] {
            #expect(throws: CVDocumentValidator.Invalid.self) { try CVDocumentValidator.validate(CVDocument(language: "en", person: person, sections: [])) }
            var letter = letterFixture
            letter.sender = person
            #expect(invalid(letter) != nil)
        }
        var letter = letterFixture
        letter.sender = Person(name: "\n ")
        #expect(invalid(letter) == "the sender's name is required")
    }

    /// A field of one line that is not trimmed: Authoring trims, so only a JSON client sends one.
    static let untrimmed: [String] = [" x", "x ", "  x  ", "\u{00A0}x", "x\u{3000}", "x\u{2028}", "\u{2029}x"]
    static let oneLineFields: [LetterTextField] = LetterTextField.all.filter(\.trimmed)

    @Test("a field of one line that starts or ends with white space is refused, and says so", arguments: oneLineFields, untrimmed)
    func untrimmedLines(field: LetterTextField, text: String) {
        var letter = letterFixture
        field.set(&letter, text)
        #expect(invalid(letter) == "\(field.what) starts or ends with white space", "\(field.name) with \(text.unicodeScalars.map(\.value))")
    }

    @Test("the place and the family name, which the page prints, are refused when they are not trimmed")
    func placeAndFamilyName() {
        var letter = letterFixture
        letter.place = " Roma"
        #expect(invalid(letter) == "the place starts or ends with white space")
        letter = letterFixture
        letter.recipient.familyName = "Rossi "
        #expect(invalid(letter) == "the recipient's family name starts or ends with white space")
        letter.recipient.familyName = "Rossi"
        #expect(invalid(letter) == nil)
    }

    @Test("what Authoring keeps is accepted in every field: emoji sequences, soft hyphens, zero-width and direction marks, tag sequences, separators",
          arguments: LetterTextField.all, keptLetterText)
    func keptCharacters(field: LetterTextField, text: String) throws {
        var letter = letterFixture
        field.set(&letter, text)
        #expect(invalid(letter) == nil, "\(field.name) refused \(text.unicodeScalars.map(\.value))")
        #expect(try LetterDocumentValidator.decode(json: try JSONEncoder().encode(letter)) == letter)
    }

    /// Scalars from the ranges where controls, separators, joiners, marks and tags are, and from the planes around them.
    static let sweep: [Unicode.Scalar] = {
        var scalars: [Unicode.Scalar] = []
        for range in [0...0x2FFF, 0xE000...0xFFFF, 0xE0000...0xE0FFF, 0x1F000...0x1F2FF] {
            for value in range { if let scalar = Unicode.Scalar(UInt32(value)) { scalars.append(scalar) } }
        }
        return scalars
    }()

    @Test("one rule: the letter's paragraphs refuse exactly the characters that a CV's text refuses, and its lines the same but the line break")
    func theRuleIsTheCVs() {
        var disagreements: [UInt32] = []
        for scalar in Self.sweep {
            let text = "a\(scalar)b"
            let cv = (try? CVDocumentValidator.validate(CVDocument(language: "en", person: Person(name: text), sections: []))) != nil
            var letter = letterFixture
            letter.body[0] = text
            var line = letterFixture
            line.recipient.name = text
            var sender = letterFixture
            sender.sender.location = text
            if cv != (invalid(letter) == nil) { disagreements.append(scalar.value) }
            if cv != (invalid(sender) == nil) { disagreements.append(scalar.value) }          // the sender follows the CV's rule, line breaks included
            if scalar != "\n" && cv != (invalid(line) == nil) { disagreements.append(scalar.value) }
        }
        #expect(disagreements.isEmpty, "\(disagreements.prefix(8))")
        #expect(Self.sweep.count > 20_000)
    }

    @Test("ordinary text in the six languages is accepted: accents, apostrophes, quotes, the euro sign, emoji and CJK names",
          arguments: ["Gràcies, Müller & Søn", "L’équipe d’« Élan »", "Ação — 100 € / mês", "Zażółć gęślą jaźń", "山田 太郎", "Thanks 🙂", "O'Brien"])
    func ordinaryText(text: String) throws {
        var letter = letterFixture
        letter.body[0] = text
        letter.recipient.name = text
        try LetterDocumentValidator.validate(letter)
    }

    static let requiredCases: [(String, String)] = [
        ("name", "the name is required"), ("sender", "the sender's name is required"),
        ("familyName", "the recipient's family name is required"),
    ]

    @Test("what a letter cannot do without is refused: the signature, the sender's name and a family name to address",
          arguments: requiredCases)
    func required(what: String, reason: String) {
        var letter = letterFixture
        switch what {
        case "name": letter.name = " \t "
        case "sender": letter.sender.name = ""
        default: letter.recipient.familyName = nil
        }
        #expect(invalid(letter) == reason)
        if what == "familyName" {
            letter.recipient.formOfAddress = .neutral
            #expect(invalid(letter) == nil)          // a neutral salutation names nobody
        }
    }

    static let emptyBodies: [[String]] = [[], [""], ["", "  "], ["\n"]]

    @Test("a letter with no opening and no paragraphs is a valid document: Authoring can keep one while it is being edited", arguments: emptyBodies)
    func emptyBody(body: [String]) throws {
        var letter = letterFixture
        letter.body = body
        try LetterDocumentValidator.validate(letter)
        #expect(try LetterDocumentValidator.decode(json: try JSONEncoder().encode(letter)) == letter)
        letter.closing = nil
        try LetterDocumentValidator.validate(letter)
    }

    static let impossibleDates: [(Int, Int, Int)] = [
        (1899, 12, 31), (2201, 1, 1), (2026, 0, 1), (2026, 13, 1), (2026, 10, 0), (2026, 10, 32), (2026, 4, 31), (2026, 2, 29), (2100, 2, 29), (-5, 1, 1),
    ]

    @Test("a date must exist on the calendar", arguments: impossibleDates)
    func impossibleDate(year: Int, month: Int, day: Int) {
        var letter = letterFixture
        letter.date = LetterDate(year: year, month: month, day: day)
        #expect(invalid(letter) == "the date does not exist")
    }

    static let possibleDates: [(Int, Int, Int)] = [(2024, 2, 29), (2000, 2, 29), (1900, 1, 1), (2200, 12, 31), (2026, 4, 30), (2026, 12, 31)]
    @Test("leap days and the edges of the range are accepted", arguments: possibleDates)
    func possibleDate(year: Int, month: Int, day: Int) throws {
        var letter = letterFixture
        letter.date = LetterDate(year: year, month: month, day: day)
        try LetterDocumentValidator.validate(letter)
    }

    @Test("an unknown schema version is rejected, and says so", arguments: [0, 2, 99, -1, Int.max])
    func version(version: Int) throws {
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(letterFixture)) as? [String: Any])
        object["schemaVersion"] = version
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) { _ = try JSONDecoder().decode(LetterDocument.self, from: data) }
        #expect(throws: LetterDocumentValidator.Invalid(reason: "unsupported schema version")) { _ = try LetterDocumentValidator.decode(json: data) }
    }

    @Test("a missing or mistyped version is not a letter document", arguments: [#"{"language":"en"}"#, #"{"schemaVersion":"1"}"#, #"{"schemaVersion":null}"#])
    func versionMissing(json: String) {
        #expect(throws: LetterDocumentValidator.Invalid(reason: "not a letter document")) { _ = try LetterDocumentValidator.decode(json: Data(json.utf8)) }
    }

    @Test("JSON is size-checked before it is decoded, and validated after")
    func jsonEntryPoint() throws {
        let data = try JSONEncoder().encode(letterFixture)
        #expect(try LetterDocumentValidator.decode(json: data) == letterFixture)
        // Spaces would fail to decode: only a check made first says the document is too large.
        #expect(throws: LetterDocumentValidator.Invalid(reason: "document is too large")) {
            _ = try LetterDocumentValidator.decode(json: Data(repeating: 0x20, count: LetterDocumentValidator.maxJSONBytes + 1))
        }
        #expect(try LetterDocumentValidator.decode(json: data + Data(repeating: 0x20, count: LetterDocumentValidator.maxJSONBytes - data.count)) == letterFixture)
        for json in ["{}", "[]", "null", "not json", "", #"{"schemaVersion":1}"#] {
            #expect(throws: LetterDocumentValidator.Invalid(reason: "not a letter document")) { _ = try LetterDocumentValidator.decode(json: Data(json.utf8)) }
        }
        var hostile = letterFixture
        hostile.body[0] = "\u{202E}evil"
        #expect(throws: LetterDocumentValidator.Invalid.self) { _ = try LetterDocumentValidator.decode(json: try JSONEncoder().encode(hostile)) }
    }

    @Test("deeply nested JSON, within the size bound, is refused and never crashes the decoder", arguments: [600, 20_000, 380_000])
    func deepNesting(depth: Int) {
        let arrays = String(repeating: "[", count: depth) + String(repeating: "]", count: depth)
        let objects = String(repeating: #"{"a":"#, count: depth) + "1" + String(repeating: "}", count: depth)
        let inside = #"{"schemaVersion":1,"language":"it","sender":{"name":"A","email":"# + arrays + "}}"
        for json in [arrays, objects, inside] where json.utf8.count <= LetterDocumentValidator.maxJSONBytes {
            #expect(throws: LetterDocumentValidator.Invalid(reason: "not a letter document")) { _ = try LetterDocumentValidator.decode(json: Data(json.utf8)) }
        }
        #expect(throws: LetterDocumentValidator.Invalid.self) { _ = try LetterDocumentValidator.decode(json: Data(arrays.utf8)) }
    }

    @Test("a form of address outside the three is not a letter document")
    func formOfAddress() throws {
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(letterFixture)) as? [String: Any])
        var recipient = try #require(object["recipient"] as? [String: Any])
        recipient["formOfAddress"] = "informal"
        object["recipient"] = recipient
        #expect(throws: LetterDocumentValidator.Invalid(reason: "not a letter document")) { _ = try LetterDocumentValidator.decode(json: try JSONSerialization.data(withJSONObject: object)) }
        #expect(FormOfAddress.allCases == [.masculine, .feminine, .neutral])
    }
}
