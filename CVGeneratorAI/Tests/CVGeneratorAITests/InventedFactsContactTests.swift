import Testing
import Foundation
import CVGeneratorAI

// A phone number is the person's own only when the draft gives all of it: the same digits, or the same number with the
// country code written or left out. A piece of a number, or a run of digits that is a date or a range of years, is not
// proof. An address is the person's own when the description gives an address of that shape (a web address, a domain or
// a handle); a word that merely occurs in the description is a doubt at best.

@Suite("Invented facts: a phone number or an address needs the whole of it in the description")
struct InventedFactsContactTests {
    static let description = """
        I am Mario Rossi, a warehouse supervisor. Call me on +39 333 123 4567 or at the office on 02 7946 0958. \
        My site is https://mariorossi.dev and my code is at github.com/mrossi, and I am @mrossi_dev on the forum. \
        I worked there from 2014 - 2019, I started on 12.03.2018, I use Excel and I play football. \
        Write to mario@mariorossi.dev.
        """

    // MARK: - Phone

    @Test("A phone number is a quote with the same digits, derived with the country code added or left out, a doubt as a piece of one",
          arguments: PhoneCase.all)
    func phone(_ phone: PhoneCase) {
        let cv = CVData(personalInfo: PersonalInfo(phone: phone.value))

        let finding = InventedFacts.count(cv, description: Self.description).finding(at: "personalInfo.phone")

        #expect(finding?.kind == phone.kind, "\(phone): \(String(describing: finding))")
    }

    @Test("A run of digits that is a date or a range of years is no phone number the description gives")
    func datesAreNoPhones() {
        for value in ["2014 - 2019", "20142019", "12.03.2018", "12032018"] {
            let cv = CVData(personalInfo: PersonalInfo(phone: value))

            let finding = InventedFacts.count(cv, description: Self.description).finding(at: "personalInfo.phone")

            #expect(finding?.kind == .invented, "\(value): \(String(describing: finding))")
        }
    }

    // MARK: - Addresses

    @Test("An address is a quote when the description gives it whole, a doubt when it gives a piece of it or only the word",
          arguments: LinkCase.all)
    func link(_ link: LinkCase) {
        let cv = CVData(personalInfo: link.personalInfo)

        let finding = InventedFacts.count(cv, description: Self.description).finding(at: link.path)

        #expect(finding?.kind == link.kind, "\(link): \(String(describing: finding))")
    }

    @Test("The domain of the person's email, as a web address, is a doubt")
    func domainOfTheEmail() {
        let cv = CVData(personalInfo: PersonalInfo(website: "mariorossi.dev"))

        let finding = InventedFacts.count(cv, description: "Write to mario@mariorossi.dev.").finding(at: "personalInfo.website")

        #expect(finding?.kind == .review, "\(String(describing: finding))")
    }

    @Test("A word the description says, as a web address, is a doubt, not a quote")
    func wordAsAnAddress() {
        let cv = CVData(personalInfo: PersonalInfo(website: "https://Excel", github: "football"))

        let report = InventedFacts.count(cv, description: "I use Excel and I play football.")

        #expect(report.finding(at: "personalInfo.website")?.kind == .review, "\(report.findings)")
        #expect(report.finding(at: "personalInfo.github")?.kind == .review, "\(report.findings)")
    }
}

struct PhoneCase: Sendable, CustomTestStringConvertible {
    let value: String
    let kind: InventedFacts.Class

    var testDescription: String { "\(value) is \(kind)" }

    static let all: [PhoneCase] = [
        // The same digits, in another layout or with the other international prefix.
        PhoneCase(value: "+39 333 123 4567", kind: .quote),
        PhoneCase(value: "+39-333-123-4567", kind: .quote),
        PhoneCase(value: "0039 333 123 4567", kind: .quote),
        PhoneCase(value: "(+39) 333 123 4567", kind: .quote),
        PhoneCase(value: "02 7946 0958", kind: .quote),
        PhoneCase(value: "027946 0958", kind: .quote),
        // The country code left out or added, said explicitly on one side.
        PhoneCase(value: "333 123 4567", kind: .derived),
        PhoneCase(value: "3331234567", kind: .derived),
        PhoneCase(value: "+39 02 7946 0958", kind: .derived),
        // A piece of a number the description gives.
        PhoneCase(value: "123 4567", kind: .review),
        PhoneCase(value: "234567", kind: .review),
        // Another number, another country, or too short to be one.
        PhoneCase(value: "+39 333 999 0000", kind: .invented),
        PhoneCase(value: "+49 333 123 4567", kind: .invented),
        PhoneCase(value: "4567", kind: .invented),
    ]
}

struct LinkCase: Sendable, CustomTestStringConvertible {
    enum Field: String, Sendable { case website, linkedin, github }

    let field: Field
    let value: String
    let kind: InventedFacts.Class

    var testDescription: String { "\(field.rawValue) \(value) is \(kind)" }
    var path: String { "personalInfo.\(field.rawValue)" }

    var personalInfo: PersonalInfo {
        switch field {
        case .website: PersonalInfo(website: value)
        case .linkedin: PersonalInfo(linkedin: value)
        case .github: PersonalInfo(github: value)
        }
    }

    static let all: [LinkCase] = [
        // The address the description gives, with the scheme, the www or the slash changed.
        LinkCase(field: .website, value: "https://mariorossi.dev", kind: .quote),
        LinkCase(field: .website, value: "mariorossi.dev", kind: .quote),
        LinkCase(field: .website, value: "www.mariorossi.dev/", kind: .quote),
        LinkCase(field: .github, value: "github.com/mrossi", kind: .quote),
        LinkCase(field: .github, value: "https://GitHub.com/MRossi/", kind: .quote),
        LinkCase(field: .linkedin, value: "@mrossi_dev", kind: .quote),
        // More than the description gives, or a piece of it.
        LinkCase(field: .website, value: "https://mariorossi.dev/about", kind: .review),
        LinkCase(field: .github, value: "https://github.com/mrossi_dev", kind: .review),
        LinkCase(field: .github, value: "mrossi", kind: .review),
        // A word of the description that is no address.
        LinkCase(field: .website, value: "https://Excel", kind: .review),
        LinkCase(field: .website, value: "excel", kind: .review),
        LinkCase(field: .github, value: "football", kind: .review),
        // An address the description does not give.
        LinkCase(field: .website, value: "https://other.example.org", kind: .invented),
        LinkCase(field: .github, value: "github.com/someoneelse", kind: .invented),
        LinkCase(field: .linkedin, value: "linkedin.com/in/mrossi", kind: .invented),
    ]
}
