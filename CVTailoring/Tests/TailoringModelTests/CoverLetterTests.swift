import Testing
import TailoringModel

@Suite("ADR 0013 / R6, R8 · the cover letter, its defaults and the advert")
struct CoverLetterTests {
    private func makeRecipient() throws -> LetterRecipient {
        try LetterRecipient(company: "Globex", contactName: "Grace Hopper", form: .ms, title: "Dr.", surname: "Hopper", role: "Head of Engineering",
                            address: ["1 Main Street", "10115 Berlin"])
    }

    private func makeLetter(recipient: LetterRecipient? = nil, subject: String = "Application", body: [String] = ["First paragraph.", "Second paragraph."],
                        attachments: [String] = ["CV"]) throws -> CoverLetter {
        try CoverLetter(recipient: recipient ?? LetterRecipient(company: "Globex"), reference: "REF-1", position: "Engineer", subject: subject,
                        opening: "Dear Dr. Hopper,", body: body, closing: "Kind regards,", attachments: attachments)
    }

    @Test("a cover letter holds every part as given")
    func built() throws {
        let recipient = try makeRecipient()
        let letter = try makeLetter(recipient: recipient)
        #expect(letter.recipient == recipient)
        #expect(letter.reference == "REF-1")
        #expect(letter.position == "Engineer")
        #expect(letter.subject == "Application")
        #expect(letter.opening == "Dear Dr. Hopper,")
        #expect(letter.body == ["First paragraph.", "Second paragraph."])
        #expect(letter.closing == "Kind regards,")
        #expect(letter.attachments == ["CV"])
    }

    @Test("a recipient is built as written")
    func recipientBuilt() throws {
        let recipient = try makeRecipient()
        #expect(recipient.company == "Globex")
        #expect(recipient.contactName == "Grace Hopper")
        #expect(recipient.form == .ms)
        #expect(recipient.title == "Dr.")
        #expect(recipient.surname == "Hopper")
        #expect(recipient.role == "Head of Engineering")
        #expect(recipient.address == ["1 Main Street", "10115 Berlin"])
    }

    static let forms: [FormOfAddress?] = {
        var forms: [FormOfAddress?] = []
        forms.append(nil)
        forms.append(contentsOf: [FormOfAddress.ms, FormOfAddress.mr, FormOfAddress.neutral])
        return forms
    }()

    @Test("a recipient needs only a company, and a form of address is ms, mr or neutral", arguments: forms)
    func recipientMinimal(form: FormOfAddress?) throws {
        let recipient = try LetterRecipient(company: "Globex", form: form)
        #expect(recipient.form == form)
        #expect(recipient.contactName.isEmpty && recipient.title.isEmpty && recipient.surname.isEmpty && recipient.role.isEmpty)
        #expect(recipient.address.isEmpty)
    }

    static let textFields: [TextFieldCase] = {
        var cases: [TextFieldCase] = []
        cases.append(TextFieldCase(.company) { _ = try LetterRecipient(company: $0) })
        cases.append(TextFieldCase(.contactName) { _ = try LetterRecipient(company: "x", contactName: $0) })
        cases.append(TextFieldCase(.title) { _ = try LetterRecipient(company: "x", title: $0) })
        cases.append(TextFieldCase(.surname) { _ = try LetterRecipient(company: "x", surname: $0) })
        cases.append(TextFieldCase(.role) { _ = try LetterRecipient(company: "x", role: $0) })
        cases.append(TextFieldCase(.addressLine) { _ = try LetterRecipient(company: "x", address: ["ok", $0]) })
        cases.append(TextFieldCase(.reference) { _ = try CoverLetter(recipient: LetterRecipient(company: "x"), reference: $0, position: "", subject: "", opening: "", body: [], closing: "", attachments: []) })
        cases.append(TextFieldCase(.position) { _ = try CoverLetter(recipient: LetterRecipient(company: "x"), reference: "", position: $0, subject: "", opening: "", body: [], closing: "", attachments: []) })
        cases.append(TextFieldCase(.subject) { _ = try CoverLetter(recipient: LetterRecipient(company: "x"), reference: "", position: "", subject: $0, opening: "", body: [], closing: "", attachments: []) })
        cases.append(TextFieldCase(.opening) { _ = try CoverLetter(recipient: LetterRecipient(company: "x"), reference: "", position: "", subject: "", opening: $0, body: [], closing: "", attachments: []) })
        cases.append(TextFieldCase(.paragraph) { _ = try CoverLetter(recipient: LetterRecipient(company: "x"), reference: "", position: "", subject: "", opening: "", body: ["ok", $0], closing: "", attachments: []) })
        cases.append(TextFieldCase(.closing) { _ = try CoverLetter(recipient: LetterRecipient(company: "x"), reference: "", position: "", subject: "", opening: "", body: [], closing: $0, attachments: []) })
        cases.append(TextFieldCase(.attachment) { _ = try CoverLetter(recipient: LetterRecipient(company: "x"), reference: "", position: "", subject: "", opening: "", body: [], closing: "", attachments: ["ok", $0]) })
        cases.append(TextFieldCase(.salaryExpectation) { _ = try LetterDefaults(salaryExpectation: $0) })
        cases.append(TextFieldCase(.startDate) { _ = try LetterDefaults(startDate: $0) })
        cases.append(TextFieldCase(.note) { _ = try LetterDefaults(note: $0) })
        return cases
    }()

    @Test("each text of a letter, a recipient or the defaults accepts 10,000 bytes and refuses one more", arguments: textFields)
    func textBounds(field: TextFieldCase) throws {
        try field.build(ascii(10_000))
        #expect(throws: TailoringModelError.tooLarge(field.field)) { try field.build(ascii(10_001)) }
    }

    @Test("an address has at most 6 lines")
    func addressLines() throws {
        #expect(TailoringLimits.maxAddressLines == 6)
        _ = try LetterRecipient(company: "x", address: Array(repeating: "line", count: 6))
        #expect(throws: TailoringModelError.tooMany(.addressLines)) { try LetterRecipient(company: "x", address: Array(repeating: "line", count: 7)) }
    }

    @Test("a letter has at most 20 body paragraphs")
    func paragraphs() throws {
        #expect(TailoringLimits.maxParagraphs == 20)
        _ = try makeLetter(body: Array(repeating: "Paragraph.", count: 20))
        #expect(throws: TailoringModelError.tooMany(.paragraphs)) { try makeLetter(body: Array(repeating: "Paragraph.", count: 21)) }
    }

    @Test("a letter has at most 20 attachments")
    func attachments() throws {
        #expect(TailoringLimits.maxAttachments == 20)
        _ = try makeLetter(attachments: Array(repeating: "CV", count: 20))
        #expect(throws: TailoringModelError.tooMany(.attachments)) { try makeLetter(attachments: Array(repeating: "CV", count: 21)) }
    }

    @Test("a letter may be empty: what it says is for the provenance gate")
    func emptyLetter() throws {
        let letter = try CoverLetter(recipient: LetterRecipient(company: ""), reference: "", position: "", subject: "", opening: "", body: [], closing: "", attachments: [])
        #expect(letter.body.isEmpty && letter.attachments.isEmpty)
    }

    // MARK: Defaults

    @Test("the defaults are what the user wrote, each one optional")
    func defaults() throws {
        let written = try LetterDefaults(salaryExpectation: "55k", startDate: "1 March", note: "Open to relocation.")
        #expect(written.salaryExpectation == "55k")
        #expect(written.startDate == "1 March")
        #expect(written.note == "Open to relocation.")
        let none = try LetterDefaults()
        #expect(none.salaryExpectation == nil && none.startDate == nil && none.note == nil)
    }

    @Test("the note may run over several lines and hold a tab, as the user wrote it")
    func noteIsMultiLine() throws {
        let note = "Open to relocation.\n\tAvailable from March.\r\nThank you."
        #expect(try LetterDefaults(note: note).note == note)
    }

    @Test("the salary expectation and the start date are one line each")
    func otherDefaultsAreOneLine() {
        #expect(throws: TailoringModelError.hiddenCharacter(.salaryExpectation)) { try LetterDefaults(salaryExpectation: "55k\n60k") }
        #expect(throws: TailoringModelError.hiddenCharacter(.startDate)) { try LetterDefaults(startDate: "1 March\n1 April") }
    }

    // MARK: Advert

    @Test("an advert is its text and its language, kept as written")
    func advert() throws {
        let advert = try Advert(text: "  We are hiring.\nApply now.  ", language: .german)
        #expect(advert.text == "  We are hiring.\nApply now.  ")
        #expect(advert.language == .german)
    }

    static let blankAdverts: [String] = {
        var texts: [String] = []
        texts.append(contentsOf: blankStrings)
        return texts
    }()

    @Test("an advert with no text is refused", arguments: blankAdverts)
    func advertWithoutText(text: String) {
        #expect(throws: TailoringModelError.emptyField(.advert)) { try Advert(text: text, language: .english) }
    }

    @Test("an advert of a space with a combining mark is not empty: the mark shows")
    func markedSpaceAdvert() throws {
        #expect(try Advert(text: markedSpace, language: .english).text == markedSpace)
    }

    @Test("an advert holds at most 50,000 UTF-8 bytes")
    func advertBound() throws {
        #expect(TailoringLimits.maxAdvertBytes == 50_000)
        #expect(try Advert(text: ascii(50_000), language: .english).text.utf8.count == 50_000)
        #expect(throws: TailoringModelError.tooLarge(.advert)) { try Advert(text: ascii(50_001), language: .english) }
    }

    @Test("the advert limit counts bytes, not characters")
    func advertBytes() throws {
        #expect(try Advert(text: twoByteCharacters(bytes: 50_000), language: .french).text.count == 25_000)
        #expect(throws: TailoringModelError.tooLarge(.advert)) { try Advert(text: twoByteCharacters(bytes: 50_002), language: .french) }
    }
}
