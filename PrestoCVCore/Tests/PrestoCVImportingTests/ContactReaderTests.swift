import Testing
@testable import PrestoCVImporting

@Suite("Reading contacts")
struct ContactReaderTests {

    private func piece(_ text: String) -> Piece {
        Piece(text: text, span: SourceSpan(100, 100 + text.unicodeScalars.count))
    }

    @Test("A header line gives its e-mail address, phone number and web address, and keeps the rest")
    func headerLine() {
        let contacts = ContactReader.read(piece("Torino, Italia · +39 333 000 0000 · giulia.bianchi@example.com · linkedin.com/in/giulia-bianchi-example"))
        #expect(contacts.emails.map(\.value.value) == ["giulia.bianchi@example.com"])
        #expect(contacts.phones.map(\.value.value) == ["+39 333 000 0000"])
        #expect(contacts.links.map(\.address.value.value) == ["https://linkedin.com/in/giulia-bianchi-example"])
        #expect(contacts.links.map(\.kind) == [.linkedIn])
        #expect(contacts.links.first?.address.reading == .webAddress)
        #expect(contacts.rest.map(\.text) == ["Torino, Italia"])
    }

    @Test("Each value points to the span it was read from")
    func spans() throws {
        let contacts = ContactReader.read(piece("Mail: lena@example.org"))
        let email = try #require(contacts.emails.first)
        #expect(email.spans == [SourceSpan(106, 122)])
        #expect(email.reading == nil)
    }

    @Test("Phone numbers with a label, an international prefix or a leading zero", arguments: [
        ("Tel.: 0341 123456", "0341 123456"), ("Handy 0170 0000000", "0170 0000000"), ("+49 (0)341 1234567", "+49 (0)341 1234567"),
        ("Cellulare: 333 0000000", "333 0000000"), ("Telemóvel: 912 000 000", "912 000 000"), ("📞 +33 6 00 00 00 00", "+33 6 00 00 00 00"),
    ])
    func phones(text: String, number: String) {
        #expect(ContactReader.read(piece(text)).phones.map(\.value.value) == [number])
    }

    @Test("Periods, postal codes and years are no phone numbers")
    func notPhones() {
        for text in ["2016 – 2020", "10115 Berlin", "03/2019 – 05/2021", "12.03.1990", "Team of 12, 3500 patients"] {
            #expect(ContactReader.read(piece(text)).phones.isEmpty, "\(text)")
        }
    }

    @Test("A web address with its scheme is kept as written; GitHub and XING are told apart")
    func links() {
        let contacts = ContactReader.read(piece("https://github.com/example-dev | www.xing.com/profile/Lena_Example | https://example.com/portfolio"))
        #expect(contacts.links.map(\.address.value.value) == [
            "https://github.com/example-dev", "https://www.xing.com/profile/Lena_Example", "https://example.com/portfolio",
        ])
        #expect(contacts.links.map(\.kind) == [.gitHub, .xing, .website])
        #expect(contacts.links.first?.address.reading == nil)
    }

    @Test("An address cut short, a legal form and a domain inside an e-mail address are no contacts")
    func notContacts() {
        let contacts = ContactReader.read(piece("clara.weiss@ · Acme S.p.A. · Beispiel GmbH"))
        #expect(contacts.emails.isEmpty)
        #expect(contacts.links.isEmpty)
        #expect(ContactReader.read(piece("anna@example.com")).links.isEmpty)
    }
}
