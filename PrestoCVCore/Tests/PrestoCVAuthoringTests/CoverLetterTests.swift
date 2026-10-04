import Testing
import Foundation
import PrestoCVDomain
import PrestoCVCoreTestSupport

private func recipient(company: String? = nil, contact: String? = nil, title: String? = nil, surname: String? = nil, role: String? = nil,
                       address: [String] = []) throws -> LetterRecipient {
    try LetterRecipient(company: company, contactName: contact, formOfAddress: .ms, title: title, surname: surname, role: role, address: address)
}

private func letter(reference: String? = nil, position: String? = nil, subject: String? = nil, opening: String? = nil, paragraphs: [String] = [],
                    closing: String? = nil, attachments: [String] = []) throws -> CoverLetter {
    try CoverLetter(recipient: try recipient(), reference: reference, position: position, subject: subject, opening: opening,
                    paragraphs: paragraphs, closing: closing, attachments: attachments)
}

/// Each text of a letter with the field it is refused for, and the way to build a letter around it.
private let lineFields: [(ApplicationField, @Sendable (String) throws -> Void)] = {
    var fields: [(ApplicationField, @Sendable (String) throws -> Void)] = []
    fields.append((.recipientCompany, { _ = try recipient(company: $0) }))
    fields.append((.recipientContactName, { _ = try recipient(contact: $0) }))
    fields.append((.recipientTitle, { _ = try recipient(title: $0) }))
    fields.append((.recipientSurname, { _ = try recipient(surname: $0) }))
    fields.append((.recipientRole, { _ = try recipient(role: $0) }))
    fields.append((.recipientAddress, { _ = try recipient(address: [$0]) }))
    fields.append((.reference, { _ = try letter(reference: $0) }))
    fields.append((.position, { _ = try letter(position: $0) }))
    fields.append((.subject, { _ = try letter(subject: $0) }))
    fields.append((.attachment, { _ = try letter(attachments: [$0]) }))
    return fields
}()

private let paragraphFields: [(ApplicationField, @Sendable (String) throws -> Void)] = {
    var fields: [(ApplicationField, @Sendable (String) throws -> Void)] = []
    fields.append((.opening, { _ = try letter(opening: $0) }))
    fields.append((.paragraph, { _ = try letter(paragraphs: [$0]) }))
    fields.append((.closing, { _ = try letter(closing: $0) }))
    return fields
}()

private func expect(_ error: ApplicationError, _ body: () throws -> Void) {
    do { try body(); Issue.record("expected \(error)") } catch let e as ApplicationError { #expect(e == error) } catch { Issue.record("\(error)") }
}

@Suite("ADR 0019 · cover letter")
struct CoverLetterTests {
    @Test("the letter's bounds are wide enough for everything Tailoring's model accepts: a line and a paragraph of 10,000 bytes, 20 attachments")
    func boundsHoldTailoringsBounds() throws {
        #expect(CoverLetter.maxLineBytes == 10_000 && CoverLetter.maxParagraphBytes == 10_000 && CoverLetter.maxAttachments == 20)
        let line = String(repeating: "a", count: 10_000), paragraph = String(repeating: "b", count: 10_000)
        let value = try CoverLetter(recipient: LetterRecipient(company: line, contactName: line, title: line, surname: line, role: line, address: [line]),
                                    reference: line, position: line, subject: line, opening: paragraph, paragraphs: [paragraph], closing: paragraph,
                                    attachments: Array(repeating: line, count: 20))
        #expect(value.attachments.count == 20 && value.opening == paragraph && value.subject == line)
    }

    @Test("the fixture populates every part, so a completeness test over it sees every leaf")
    func fixtureIsComplete() {
        let leaves = FieldLeaves.of(FixtureLetter.full())
        #expect(!leaves.contains(FieldLeaves.missing) && !leaves.contains(FieldLeaves.empty) && !leaves.contains(""))
    }

    @Test("every text is trimmed, and an empty optional text is absent, never an empty string")
    func trimmedAndAbsent() throws {
        let value = try CoverLetter(recipient: recipient(company: "  Acme ", contact: " \n "), reference: " Ref 7 ", subject: "", opening: "  Hello\n",
                                    paragraphs: [" One ", "Two"], closing: nil, attachments: [" CV "])
        #expect(value.recipient.company == "Acme" && value.recipient.contactName == nil && value.reference == "Ref 7" && value.subject == nil)
        #expect(value.opening == "Hello" && value.paragraphs == ["One", "Two"] && value.closing == nil && value.attachments == ["CV"])
    }

    @Test("the form of address defaults to neutral, and the letter holds no salutation and no valediction")
    func noSalutation() throws {
        #expect(try LetterRecipient().formOfAddress == .neutral)
        let names = Mirror(reflecting: FixtureLetter.full()).children.compactMap(\.label)
        #expect(!names.contains { $0.lowercased().contains("salutation") || $0.lowercased().contains("valediction") })
    }

    @Test("a line is bounded in UTF-8 bytes, and the bound is the limit itself", arguments: 0..<10)
    func lineBound(index: Int) throws {
        let (field, build) = lineFields[index]
        try build(String(repeating: "a", count: CoverLetter.maxLineBytes))
        expect(.tooLong(field)) { try build(String(repeating: "a", count: CoverLetter.maxLineBytes + 1)) }
        expect(.tooLong(field)) { try build(String(repeating: "é", count: CoverLetter.maxLineBytes / 2 + 1)) }
    }

    @Test("a paragraph is bounded in UTF-8 bytes, and the bound is the limit itself", arguments: 0..<3)
    func paragraphBound(index: Int) throws {
        let (field, build) = paragraphFields[index]
        try build(String(repeating: "a", count: CoverLetter.maxParagraphBytes))
        expect(.tooLong(field)) { try build(String(repeating: "a", count: CoverLetter.maxParagraphBytes + 1)) }
    }

    @Test("a line holds no line break and no control character; a paragraph may break lines but holds no other control", arguments: 0..<10)
    func characters(index: Int) throws {
        let (field, build) = lineFields[index]
        for text in ["a\nb", "a\u{0000}b", "a\tb", "a\u{202E}b", "a\u{2069}b"] { expect(.forbiddenCharacters(field)) { try build(text) } }
        for (field, build) in paragraphFields {
            try build("one\ntwo")
            for text in ["a\u{0000}b", "a\tb", "a\r\nb", "a\u{202D}b"] { expect(.forbiddenCharacters(field)) { try build(text) } }
        }
    }

    @Test("a list item that says nothing is refused, and each list has its own bound")
    func lists() throws {
        expect(.empty(.paragraph)) { _ = try letter(paragraphs: ["One", "  "]) }
        expect(.empty(.attachment)) { _ = try letter(attachments: [""]) }
        expect(.empty(.recipientAddress)) { _ = try recipient(address: ["Via Roma 1", "\n"]) }
        _ = try letter(paragraphs: Array(repeating: "p", count: CoverLetter.maxParagraphs), attachments: Array(repeating: "a", count: CoverLetter.maxAttachments))
        _ = try recipient(address: Array(repeating: "a", count: CoverLetter.maxAddressLines))
        expect(.tooMany(.paragraph)) { _ = try letter(paragraphs: Array(repeating: "p", count: CoverLetter.maxParagraphs + 1)) }
        expect(.tooMany(.attachment)) { _ = try letter(attachments: Array(repeating: "a", count: CoverLetter.maxAttachments + 1)) }
        expect(.tooMany(.recipientAddress)) { _ = try recipient(address: Array(repeating: "a", count: CoverLetter.maxAddressLines + 1)) }
    }

    @Test("paragraphs keep the order the user wrote them in")
    func order() throws {
        #expect(try letter(paragraphs: ["B", "A", "C"]).paragraphs == ["B", "A", "C"])
    }
}
