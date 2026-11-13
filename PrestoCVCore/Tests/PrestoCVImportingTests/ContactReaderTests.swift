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

    @Test("A period in the middle of a line is no phone number, and reading it is safe wherever it stands")
    func periodAfterOtherText() {
        for text in ["Kassel · 03/2019 – 05/2021", "Beispiel GmbH, Kassel 03/2019 - 05/2021", "Tel. 0561 123456 · 03/2019 – 05/2021"] {
            let phones = ContactReader.read(piece(text)).phones.map(\.value.value)
            #expect(!phones.contains { $0.contains("2021") }, "\(text)")
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

    @Test("A link is a profile only on the platform's own domain or a subdomain of it; any other host is a website", arguments: [
        ("tobiasrenn.github.io", ImportedLink.Kind.website),
        ("https://tobiasrenn.github.io/blog", .website),
        ("github.com/tobiasrenn", .gitHub),
        ("www.github.com/tobiasrenn", .gitHub),
        ("https://GitHub.com/tobiasrenn", .gitHub),
        ("https://github.com:443/tobiasrenn", .gitHub),
        ("https://github.com./tobiasrenn", .gitHub),
        ("https://github.com?tab=repositories", .gitHub),
        ("https://github.com#tobiasrenn", .gitHub),
        ("https://tobiasrenn.github.io?ref=cv", .website),
        ("linkedin.com/in/tobiasrenn", .linkedIn),
        ("de.linkedin.com/in/tobiasrenn", .linkedIn),
        ("https://www.linkedin.com/in/tobiasrenn", .linkedIn),
        ("www.xing.com/profile/Tobias_Renn", .xing),
        ("linkedin.example.org", .website),
        ("github.example.dev/tobiasrenn", .website),
        ("xing.tobiasrenn.dev", .website),
        ("mygithub.com/tobiasrenn", .website),
        ("github.com.example.org/tobiasrenn", .website),
        ("tobiasrenn.dev/github.com", .website),
    ])
    func profileByDomain(link: String, kind: ImportedLink.Kind) {
        let contacts = ContactReader.read(piece(link))
        #expect(contacts.links.map(\.kind) == [kind])
    }

    @Test("A head with a LinkedIn profile, a GitHub profile and a site on GitHub Pages keeps the site as a website")
    func gitHubPagesSiteInAHead() {
        let contacts = ContactReader.read(piece("linkedin.com/in/tobiasrenn · github.com/tobiasrenn · tobiasrenn.github.io"))
        #expect(contacts.links.map(\.address.value.value) == [
            "https://linkedin.com/in/tobiasrenn", "https://github.com/tobiasrenn", "https://tobiasrenn.github.io",
        ])
        #expect(contacts.links.map(\.kind) == [.linkedIn, .gitHub, .website])
    }

    @Test("An address cut short, a legal form and a domain inside an e-mail address are no contacts")
    func notContacts() {
        let contacts = ContactReader.read(piece("clara.weiss@ · Acme S.p.A. · Beispiel GmbH"))
        #expect(contacts.emails.isEmpty)
        #expect(contacts.links.isEmpty)
        #expect(ContactReader.read(piece("anna@example.com")).links.isEmpty)
    }

    // MARK: Phone numbers as they are written elsewhere

    @Test("Numbers written with dashes, dots or no separator, as in the United States and Brazil", arguments: [
        ("555-555-5555", "555-555-5555"), ("555.555.5555", "555.555.5555"), ("5555555555", "5555555555"),
        ("(555) 555-5555", "(555) 555-5555"), ("1-555-555-5555", "1-555-555-5555"), ("(11) 91234-5678", "(11) 91234-5678"),
        ("Jane Rowe · 555-555-5555 · jane@example.com", "555-555-5555"),
    ])
    func dashedPhones(text: String, number: String) {
        #expect(ContactReader.read(piece(text)).phones.map(\.value.value) == [number])
    }

    @Test("A number is the phone when its label says so, whatever its shape")
    func labelHintsTheShape() {
        let hinted = ContactReader.read(piece("555-0142"), label: .phone)
        #expect(hinted.phones.map(\.value.value) == ["555-0142"])
        #expect(ContactReader.read(piece("555-0142")).phones.isEmpty, "Without the label it is seven digits and a dash")
        #expect(ContactReader.read(piece("01010-000"), label: .phone).phones.map(\.value.value) == ["01010-000"])
    }

    @Test("A postcode is no phone number, with the phone next to it still read", arguments: [
        "01010-000", "Rua das Flores, 45, São Paulo - SP, 01010-000", "1000-001 Lisboa", "12345-6789 Springfield", "Lisboa 1000-001",
    ])
    func postcodes(text: String) {
        #expect(ContactReader.read(piece(text)).phones.isEmpty, "\(text)")
        #expect(ContactReader.read(piece(text + " · (11) 91234-5678")).phones.map(\.value.value) == ["(11) 91234-5678"], "\(text)")
    }

    @Test("A figure in a sentence is no phone number")
    func figures() {
        for text in ["Revenue of 2023000123 euro", "Team of 12, budget 1,200,000", "ISO 9001-2015", "Version 10.2.3", "Rank 1.234.567"] {
            #expect(ContactReader.read(piece(text)).phones.isEmpty, "\(text)")
        }
    }

    // MARK: Labels

    @Test("The labels of a contact in the six languages are labels, not values", arguments: [
        "Email address", "E-mail address", "Phone number", "Mobile number", "Telephone number", "Cell phone",
        "Dirección de correo electrónico", "Número de teléfono", "Teléfono móvil", "Endereço de correio electrónico",
        "Endereço de e-mail", "Número de telefone", "Número de telemóvel", "Indirizzo e-mail", "Numero di telefono",
        "Adresse e-mail", "Adresse électronique", "Numéro de téléphone", "E-Mail-Adresse", "Telefonnummer", "Handynummer",
        "Tel.", "Handy", "Work", "Mobile", "Website", "LinkedIn",
    ])
    func knownLabels(label: String) {
        #expect(ContactReader.isContactLabel(label), "\(label)")
        #expect(ContactReader.isContactLabel(label + ":"), "\(label):")
    }

    @Test("A place or a title is no contact label")
    func notLabels() {
        for text in ["Torino", "Nurse", "Address", "Location", "Akron, OH"] {
            #expect(!ContactReader.isContactLabel(text), "\(text)")
        }
    }

    @Test("A known label before a contact is dropped; the rest of the line is what was around it")
    func labelBeforeAContact() {
        for text in ["Email address: jane@example.com", "Dirección de correo electrónico: jane@example.com",
                     "Endereço de correio electrónico: jane@example.com"] {
            let contacts = ContactReader.read(piece(text))
            #expect(contacts.emails.map(\.value.value) == ["jane@example.com"], "\(text)")
            #expect(contacts.rest.isEmpty, "\(text)")
            #expect(contacts.unknownLabels.isEmpty, "\(text)")
        }
    }

    @Test("A word and a colon before a contact is its label, never a place; an unknown one stays visible")
    func unknownLabelBeforeAContact() {
        let contacts = ContactReader.read(piece("Torino · Contact via: jane@example.com"))
        #expect(contacts.emails.map(\.value.value) == ["jane@example.com"])
        #expect(contacts.rest.map(\.text) == ["Torino"])
        #expect(contacts.unknownLabels.map(\.text) == ["Contact via"])
        let phone = ContactReader.read(piece("Reach me on: 555-555-5555"))
        #expect(phone.phones.map(\.value.value) == ["555-555-5555"])
        #expect(phone.rest.isEmpty)
        #expect(phone.unknownLabels.map(\.text) == ["Reach me on"])
    }

    @Test("A sentence before a contact is not a label")
    func sentenceBeforeAContact() {
        let contacts = ContactReader.read(piece("Available for remote work and relocation. Mail: jane@example.com"))
        #expect(contacts.unknownLabels.isEmpty)
        #expect(contacts.rest.map(\.text) == ["Available for remote work and relocation."])
    }
}
