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
    let name: String
    let set: @Sendable (inout LetterDocument, String) -> Void
    var testDescription: String { name }

    static let all: [LetterTextField] = {
        var all: [LetterTextField] = []
        func add(_ name: String, _ set: @escaping @Sendable (inout LetterDocument, String) -> Void) { all.append(LetterTextField(name: name, set: set)) }
        add("sender.name") { $0.sender.name = $1 }
        add("sender.professionalTitle") { $0.sender.professionalTitle = $1 }
        add("sender.email") { $0.sender.email = $1 }
        add("sender.phone") { $0.sender.phone = $1 }
        add("sender.location") { $0.sender.location = $1 }
        add("sender.website") { $0.sender.website = $1 }
        add("recipient.name") { $0.recipient.name = $1 }
        add("recipient.familyName") { $0.recipient.familyName = $1 }
        add("recipient.company") { $0.recipient.company = $1 }
        add("recipient.address[0]") { $0.recipient.address[0] = $1 }
        add("recipient.address[1]") { $0.recipient.address[1] = $1 }
        add("place") { $0.place = $1 }
        add("reference") { $0.reference = $1 }
        add("subject") { $0.subject = $1 }
        add("body[0]") { $0.body[0] = $1 }
        add("body[1]") { $0.body[1] = $1 }
        add("closing") { $0.closing = $1 }
        add("name") { $0.name = $1 }
        add("attachments[0]") { $0.attachments[0] = $1 }
        add("attachments[1]") { $0.attachments[1] = $1 }
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

/// Control characters (a line break included: no field can carry one, so none is accepted and then printed as a space),
/// bidirectional controls that reorder what is printed, and invisible characters that hide text or tell nothing.
let hostileLetterText: [String] = [
    "\u{0007}", "a\u{0000}b", "line\nbreak", "tab\there", "carriage\rreturn", "\u{001B}[31m", "\u{007F}", "x\u{0085}y",
    "\u{202E}evil", "a\u{2066}b", "x\u{202A}y", "x\u{202B}y", "x\u{202C}y", "x\u{202D}y", "x\u{2067}y", "x\u{2068}y", "x\u{2069}y",
    "x\u{200E}y", "x\u{200F}y", "x\u{061C}y",
    "x\u{200B}y", "x\u{200C}y", "x\u{200D}y", "x\u{2060}y", "\u{FEFF}x", "x\u{00AD}y", "x\u{E0041}y", "x\u{2028}y", "x\u{2029}y",
]

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
        field.set(&letter, String(repeating: "x", count: LetterDocumentValidator.maxTextBytes + 1))
        #expect(invalid(letter) == "a field is too long, the letter is too large, or it has control or hidden characters")
        field.set(&letter, String(repeating: "x", count: LetterDocumentValidator.maxTextBytes))
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

    @Test("the whole letter has a budget, not only each field")
    func letterBudget() {
        var letter = letterFixture
        let paragraph = String(repeating: "x", count: LetterDocumentValidator.maxTextBytes)
        letter.body = Array(repeating: paragraph, count: LetterDocumentValidator.maxDocumentTextBytes / LetterDocumentValidator.maxTextBytes + 1)
        #expect(letter.body.count <= LetterDocumentValidator.maxParagraphs)
        #expect(invalid(letter) != nil)
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

    @Test("control, bidirectional and invisible characters are refused in every field", arguments: LetterTextField.all, hostileLetterText)
    func hostileCharacters(field: LetterTextField, text: String) {
        var letter = letterFixture
        field.set(&letter, text)
        #expect(invalid(letter) == "a field is too long, the letter is too large, or it has control or hidden characters", "\(field.name) accepted \(text.unicodeScalars.map(\.value))")
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
        ("body", "a paragraph is required"), ("familyName", "the recipient's family name is required"),
    ]

    @Test("what a letter cannot do without is refused: the signature, the sender's name, a paragraph and a family name to address",
          arguments: requiredCases)
    func required(what: String, reason: String) {
        var letter = letterFixture
        switch what {
        case "name": letter.name = " \t "
        case "sender": letter.sender.name = ""
        case "body": letter.body = ["", "  "]
        default: letter.recipient.familyName = nil
        }
        #expect(invalid(letter) == reason)
        if what == "familyName" {
            letter.recipient.formOfAddress = .neutral
            #expect(invalid(letter) == nil)          // a neutral salutation names nobody
        }
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
