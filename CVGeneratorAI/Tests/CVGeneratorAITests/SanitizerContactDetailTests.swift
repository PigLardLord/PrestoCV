import Testing
import Foundation
@testable import CVGeneratorAI

/// What an AI draft may say about how to reach the person: only a contact detail the description gives in full.
@Suite("Sanitizer: contact details must be the person's own, in full")
struct SanitizerContactDetailTests {
    private let sanitizer = CVDataSanitizer()

    private func kept(_ info: PersonalInfo, from description: String) throws -> PersonalInfo {
        try sanitizer.sanitize(CVData(personalInfo: info), against: description).personalInfo
    }

    // MARK: - Email

    @Test("An email the description gives is kept, whatever its case or the punctuation after it")
    func emailGivenInTheDescription() throws {
        let description = "Write to me at Mario.Rossi@Example.com."

        #expect(try kept(PersonalInfo(email: "mario.rossi@example.com"), from: description).email == "mario.rossi@example.com")
    }

    @Test("An email the description does not give is dropped")
    func inventedEmail() throws {
        #expect(try kept(PersonalInfo(email: "mario@invented.com"), from: "Write to me at mario.rossi@example.com").email == nil)
        #expect(try kept(PersonalInfo(email: "mario.rossi@example.com"), from: "I have no email address").email == nil)
    }

    @Test("Someone else's email is dropped when it only ends, starts or continues like the person's",
          arguments: [
            // (what the description gives, what the draft claims)
            ("joanna@example.com", "anna@example.com"),
            ("anna@example.com", "joanna@example.com"),
            ("anna@example.com", "anna@example.co"),
            ("anna@example.com", "anna@example.com.au"),
            ("anna@mail.example.com", "anna@example.com"),
            ("anna@example.com", "anna@mail.example.com"),
            ("anna.rossi@example.com", "anna@example.com"),
          ] as [(String, String)])
    func emailThatIsPartOfAnother(given: String, claimed: String) throws {
        #expect(try kept(PersonalInfo(email: claimed), from: "My email is \(given), write any time.").email == nil)
    }

    @Test("An email is never taken out of a larger token")
    func emailInsideALargerToken() throws {
        #expect(try kept(PersonalInfo(email: "anna@example.com"), from: "Contact: sam!anna@example.com").email == nil)
        #expect(try kept(PersonalInfo(email: "anna@example.com"), from: "Mail sam!anna@example.com today").email == nil)
        #expect(try kept(PersonalInfo(email: "anna@example.com"), from: "mailto:anna@example.com").email == nil)
        #expect(try kept(PersonalInfo(email: "anna@example.com"), from: "email:anna@example.com").email == nil)
        #expect(try kept(PersonalInfo(email: "sam@example.com"), from: "Write to sam@example.com,anna@example.com").email == nil)
    }

    @Test("An email with the punctuation an address may hold is kept whole, and not in parts")
    func emailWithLocalPartPunctuation() throws {
        let description = "My email is first.last+cv@example.com."

        #expect(try kept(PersonalInfo(email: "first.last+cv@example.com"), from: description).email == "first.last+cv@example.com")
        #expect(try kept(PersonalInfo(email: "last+cv@example.com"), from: description).email == nil)
        #expect(try kept(PersonalInfo(email: "cv@example.com"), from: description).email == nil)
        #expect(try kept(PersonalInfo(email: "first.last@example.com"), from: description).email == nil)
    }

    @Test("An email in brackets or quotes is the same email", arguments: [
        "(mario@example.com)", "[mario@example.com]", "<mario@example.com>", "\"mario@example.com\"",
        "\u{201C}mario@example.com\u{201D}", "\u{00AB}mario@example.com\u{00BB}", "'mario@example.com'",
        "mario@example.com;", "mario@example.com!",
    ])
    func emailInBrackets(written: String) throws {
        #expect(try kept(PersonalInfo(email: "mario@example.com"), from: "Write to me: \(written) any time").email == "mario@example.com")
    }

    @Test("An email with a digit of another script is never the email with the ASCII digit, nor kept at all",
          arguments: ["\u{0661}", "\u{FF11}", "\u{06F1}"])  // Arabic-Indic, full-width, Extended Arabic-Indic one
    func unicodeDigitInEmail(one: String) throws {
        let written = "alice\(one)@example.com"

        #expect(try kept(PersonalInfo(email: "alice1@example.com"), from: "Mail \(written) please").email == nil)
        #expect(try kept(PersonalInfo(email: written), from: "Mail alice1@example.com please").email == nil)
        #expect(try kept(PersonalInfo(email: written), from: "Mail \(written) please").email == nil, "Not an ASCII address, so ambiguous")
    }

    @Test("Digits in a link's path and query are exact",
          arguments: ["\u{0661}", "\u{FF11}", "\u{06F1}"])
    func unicodeDigitInLink(one: String) throws {
        let description = "My pages: example.com/user\(one) and example.org/?id=\(one)"

        #expect(try kept(PersonalInfo(website: "example.com/user1"), from: description).website == nil)
        #expect(try kept(PersonalInfo(website: "example.org/?id=1"), from: description).website == nil)
        #expect(try kept(PersonalInfo(website: "example.com/user\(one)"), from: description).website == "example.com/user\(one)")
        #expect(try kept(PersonalInfo(website: "example.org/?id=\(one)"), from: description).website == "example.org/?id=\(one)")
        #expect(try kept(PersonalInfo(website: "example.com/user\(one)"), from: "My page: example.com/user1").website == nil)
    }

    @Test("A sentence with an address whose digits only look the same is dropped")
    func unicodeDigitInProse() throws {
        let sanitizer = CVDataSanitizer()
        let description = "I'm a nurse. Write to alice\u{0661}@example.com or see example.com/user\u{0661}."

        func summary(_ text: String) throws -> String? {
            try sanitizer.sanitize(CVData(summary: text), against: description).summary
        }

        #expect(try summary("A nurse. Write to alice1@example.com.") == "A nurse.")
        #expect(try summary("A nurse. See example.com/user1.") == "A nurse.")
        #expect(try summary("A nurse. Write to alice\u{0661}@example.com.") == "A nurse.", "Not an ASCII address, so ambiguous")
    }

    @Test("A sentence with another script's digit in an address is dropped even when the description has the ASCII one")
    func unicodeDigitInProseAgainstAsciiDescription() throws {
        let sanitizer = CVDataSanitizer()
        let description = "I'm a nurse. Write to alice1@example.com or see example.com/user1."

        func summary(_ text: String) throws -> String? {
            try sanitizer.sanitize(CVData(summary: text), against: description).summary
        }

        #expect(try summary("A nurse. Write to alice\u{0661}@example.com.") == "A nurse.")
        #expect(try summary("A nurse. See example.com/user\u{0661}.") == "A nurse.")
        #expect(try summary("A nurse. Write to alice1@example.com.") == "A nurse. Write to alice1@example.com.")
    }

    // MARK: - Links

    @Test("A link the description gives is kept, whatever its scheme, \"www.\", case or trailing slash")
    func linkGivenInTheDescription() throws {
        let description = "My site is mariorossi.dev, my profile https://www.linkedin.com/in/mario-rossi/ and github.com/mrossi"
        let info = PersonalInfo(
            website: "https://www.MarioRossi.dev/",
            linkedin: "linkedin.com/in/mario-rossi",
            github: "http://github.com/mrossi/"
        )

        let result = try kept(info, from: description)

        #expect(result.website == "https://www.MarioRossi.dev/")
        #expect(result.linkedin == "linkedin.com/in/mario-rossi")
        #expect(result.github == "http://github.com/mrossi/")
    }

    @Test("Someone else's link is dropped when it only starts or continues like the person's",
          arguments: [
            ("github.com/alice-smith", "github.com/alice"),
            ("github.com/alice", "github.com/alice-smith"),
            ("github.com/alice", "github.com/alice/secret-project"),
            ("github.com/alice/project", "github.com/alice"),
            ("github.com/alice", "gitlab.com/alice"),
            ("mariorossi.dev", "blog.mariorossi.dev"),
            ("blog.mariorossi.dev", "mariorossi.dev"),
            ("mariorossi.dev/cv", "mariorossi.dev/cv?draft=1"),
          ] as [(String, String)])
    func linkThatIsPartOfAnother(given: String, claimed: String) throws {
        #expect(try kept(PersonalInfo(github: claimed), from: "Find me on \(given) any time.").github == nil)
    }

    @Test("A link keeps its query and fragment: \"example.com\" is not found in \"example.com?user=alice\"")
    func linkWithQueryOrFragment() throws {
        let description = "Details at https://example.com?user=alice and at example.org#top"

        #expect(try kept(PersonalInfo(website: "example.com"), from: description).website == nil)
        #expect(try kept(PersonalInfo(website: "https://example.com?user=alice"), from: description).website == "https://example.com?user=alice")
        #expect(try kept(PersonalInfo(website: "example.com?user=alice"), from: description).website == "example.com?user=alice")
        #expect(try kept(PersonalInfo(website: "example.com?user=bob"), from: description).website == nil)
        #expect(try kept(PersonalInfo(website: "example.org"), from: description).website == nil)
        #expect(try kept(PersonalInfo(website: "example.org#top"), from: description).website == "example.org#top")
    }

    @Test("A link is never taken out of a larger token")
    func linkInsideALargerToken() throws {
        #expect(try kept(PersonalInfo(website: "example.com"), from: "See:example.com for more").website == nil)
        #expect(try kept(PersonalInfo(website: "example.com"), from: "See www.example.com/a,example.com").website == nil)
        #expect(try kept(PersonalInfo(website: "example.com"), from: "Write to sam!example.com").website == nil)
    }

    @Test("A link in brackets or quotes, or before a full stop, is the same link", arguments: [
        "(example.com)", "<https://example.com/>", "\"www.example.com\"", "example.com.", "example.com,",
    ])
    func linkInBrackets(written: String) throws {
        #expect(try kept(PersonalInfo(website: "example.com"), from: "My site is \(written) any time").website == "example.com")
    }

    @Test("A link the description does not give is dropped, whichever field it is in")
    func inventedLinks() throws {
        let info = PersonalInfo(website: "invented.dev", linkedin: "linkedin.com/in/invented", github: "github.com/invented")

        let result = try kept(info, from: "I am a nurse and I have no website")

        #expect(result.website == nil)
        #expect(result.linkedin == nil)
        #expect(result.github == nil)
    }

    @Test("A certification link follows the same rule")
    func certificationLink() throws {
        let certifications = [
            Certification(name: "BLS", url: "https://certs.example.org/bls/123"),
            Certification(name: "ACLS", url: "https://certs.example.org/acls/999"),
        ]
        let description = "I hold BLS and ACLS. I hold BLS at certs.example.org/bls/123/"

        let result = try sanitizer.sanitize(CVData(certifications: certifications), against: description)

        #expect(result.certifications.map(\.url) == ["https://certs.example.org/bls/123", nil])
    }

    // MARK: - Phone numbers

    @Test("A phone number the description gives is kept, whatever the separators or a +/00 prefix",
          arguments: ["+39 333 123 4567", "+393331234567", "0039 333-123-4567", "+39 (333) 123.4567", "39 333 1234567"])
    func phoneGivenInTheDescription(claimed: String) throws {
        #expect(try kept(PersonalInfo(phone: claimed), from: "Call me on +39 333 123 4567 any time").phone == claimed)
    }

    @Test("A phone number written without separators matches one written with them")
    func phoneWithoutSeparators() throws {
        #expect(try kept(PersonalInfo(phone: "333 123 4567"), from: "My number is 3331234567.").phone == "333 123 4567")
    }

    @Test("Part of a phone number, or one with other digits, is dropped",
          arguments: [
            "+39 333 123",       // cut short
            "333 123 4567",      // country code left out
            "+39 333 123 456",   // last digit missing
            "+39 333 123 45678", // extra digit
            "+39 333 123 4568",  // different digit
            "123 4567",          // tail of the number
            "+49 333 123 4567",  // other country code
          ])
    func phoneThatIsNotTheWholeNumber(claimed: String) throws {
        #expect(try kept(PersonalInfo(phone: claimed), from: "Call me on +39 333 123 4567 any time").phone == nil)
    }

    @Test("A phone number is dropped when the description has none, or too few digits are given")
    func phoneWithoutSource() throws {
        #expect(try kept(PersonalInfo(phone: "0123456789"), from: "I worked 5 years in 2015").phone == nil)
        #expect(try kept(PersonalInfo(phone: "2015"), from: "I worked in 2015 and later").phone == nil)
        #expect(try kept(PersonalInfo(phone: "123"), from: "Call 0123456789").phone == nil)
    }

    @Test("A phone number beside a year is still found")
    func phoneNextToAYear() throws {
        let description = "Call me on 333 123 4567. 2016 was my first year as a nurse."

        #expect(try kept(PersonalInfo(phone: "3331234567"), from: description).phone == "3331234567")
    }
}
