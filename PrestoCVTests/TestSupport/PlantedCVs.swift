import Foundation
@testable import PrestoCVCore

/// CVs of known size to measure the pagination of the designs with: a short one in every language, long ones with
/// a few very long entries, and realistic ones with many entries of a few bullets. Every entry and bullet carries a
/// marker such as `RealBullet-3-2`, so that a test can find each of them in the PDF.
enum PlantedCVs {

    private static let longParagraph = "Led a cross-functional programme of work covering planning, delivery and review; coordinated %d teams, "
        + "wrote the operating procedures, trained new colleagues, measured outcomes every quarter and reported results to the board. "
        + "Introduced a new rota that reduced overtime by twelve percent and raised satisfaction scores in three consecutive surveys. "

    private static let realisticSentences = [
        "Managed a team of %d people and delivered every milestone on time",
        "Reduced the average processing time by %d percent through process redesign",
        "Introduced weekly reviews that cut escalations and raised customer satisfaction",
        "Trained and mentored new colleagues and documented the standard procedures",
        "Reported monthly results to senior management and proposed improvements"
    ]

    // MARK: - The set of the pagination tests

    /// A planted CV, with what a test needs to find its text again in the PDF
    struct Planted {
        let label: String
        let cv: CVModel
        /// Texts that must be in the PDF, whatever the pagination
        let markers: [String]
        /// The title lines of the entries of a section that is long enough to be cut by a page break, as a regular expression
        let entryTitlePattern: String?
        /// Whether the headings are in English, so that a test can tell where they fall
        let hasEnglishHeadings: Bool
    }

    /// The CVs the pagination tests render: short ones in every language, one with long links, realistic ones of
    /// two to four pages, and ones with entries of about 1,300 characters
    static let paginated: [Planted] = {
        var list = DocumentLanguage.allCases.map { language in
            Planted(label: "short-\(language.rawValue)", cv: short(language: language),
                    markers: ["ProfileText", "ExpDescA", "ExpDescB", "EduDescA", "CertDescA", "Triage", "Pharmacology", "Paediatrics", "Teamwork"],
                    entryTitlePattern: nil, hasEnglishHeadings: language == .english)
        }
        list.append(Planted(label: "links", cv: longLinks(), markers: ["ProfileLinks", "LinkExperience", "Cardiopulmonary", "Swift"],
                            entryTitlePattern: nil, hasEnglishHeadings: true))
        list.append(Planted(label: "contacts", cv: longContacts(), markers: ["ProfileContacts", "ContactExperience", "Swift"],
                            entryTitlePattern: nil, hasEnglishHeadings: true))
        for (experiences, bullets) in [(4, 5), (9, 5), (11, 5)] {
            list.append(Planted(
                label: "real\(experiences)x\(bullets)", cv: realistic(name: "Real \(experiences)", experiences: experiences, bullets: bullets),
                markers: (1...experiences).flatMap { entry in (1...bullets).map { "RealBullet-\(entry)-\($0)" } } + ["ProfileReal"],
                entryTitlePattern: #"^Position \d+"#, hasEnglishHeadings: true))
        }
        let longCVs = [(5, 4, long(name: "Long 5", experiences: 5, paragraphs: 4)), (10, 4, tenLongEntries())]
        for (experiences, paragraphs, cv) in longCVs {
            list.append(Planted(
                label: "long\(experiences)x\(paragraphs)", cv: cv,
                markers: (1...experiences).flatMap { entry in (1...paragraphs).map { "LongBullet-\(entry)-\($0)" } } + ["ProfileLong"],
                entryTitlePattern: #"^Role Number \d+"#, hasEnglishHeadings: true))
        }
        return list
    }()

    // MARK: - Short, in a language

    static func short(language: DocumentLanguage) -> CVModel {
        CVModel(
            name: "Short \(language.rawValue.uppercased())",
            personalInfo: PersonalInfo(
                name: "Maria Rossi", title: "Senior Nurse", location: "Rome, Italy", email: "maria.rossi@example.com",
                phone: "+39 06 1234 5678", portfolio: "https://maria.example.com",
                profile: "ProfileText: dedicated nurse with ten years of ward experience."
            ),
            relevant_experience: [
                Experience(title: "Ward Nurse", company: "Policlinico Gemelli", location: "Rome", period: "2018 - 2024", description: "ExpDescA: cared for forty patients per shift."),
                Experience(title: "Junior Nurse", company: "Ospedale San Camillo", location: "Rome", period: "2014 - 2018", description: "ExpDescB: assisted in emergency care.")
            ],
            education: [
                Education(degree: "MSc Nursing", school: "Sapienza University", period: "2012 - 2014", description: "EduDescA"),
                Education(degree: "BSc Nursing", school: "Tor Vergata University", period: "2009 - 2012", description: "")
            ],
            skills: [Skill(name: "Triage", level: 5), Skill(name: "Pharmacology", level: 4), Skill(name: "Paediatrics", level: 3), Skill(name: "Teamwork", level: 2)],
            languages: [Language(name: "Italian", level: .native), Language(name: "English", level: .c1)],
            certifications: [
                Certification(name: "BLSD Certificate", issuer: "Italian Red Cross", year: 2023, url: "https://cert.example.com/blsd", description: "CertDescA"),
                Certification(name: "ACLS", issuer: "AHA", year: 2021)
            ],
            interests: ["Hiking", "Photography", "Chess"],
            social: [Social(platform: "LinkedIn", url: "https://linkedin.com/in/mariarossi"), Social(platform: "GitHub", url: "https://github.com/mariarossi")],
            documentLanguage: language.rawValue
        )
    }

    // MARK: - Long entries

    /// `experiences` entries of `paragraphs` paragraphs of about 330 characters each
    static func long(name: String, experiences: Int, paragraphs: Int, certifications: Int = 5) -> CVModel {
        let experienceItems = (1...experiences).map { index in
            let description = (1...paragraphs)
                .map { "LongBullet-\(index)-\($0): " + String(format: longParagraph, index) }
                .joined(separator: "\n")
            return Experience(title: "Role Number \(index)", company: "Company \(index)", location: "City \(index)",
                              period: "\(2000 + index) - \(2001 + index)", description: description)
        }
        return CVModel(
            name: name,
            personalInfo: PersonalInfo(
                name: "Long Person", title: "Long Title", location: "Long Town", email: "long@example.com",
                phone: "+1 555 0100", portfolio: "https://long.example.com",
                profile: "ProfileLong: " + String(format: longParagraph, 0) + String(format: longParagraph, 0)
            ),
            relevant_experience: experienceItems,
            education: (1...5).map { Education(degree: "Degree \($0)", school: "School \($0)", period: "\(1990 + $0) - \(1994 + $0)") },
            skills: (1...20).map { Skill(name: "Skill \($0)", level: ($0 % 5) + 1) },
            languages: [Language(name: "English", level: .native), Language(name: "French", level: .b2)],
            certifications: (1...certifications).map { Certification(name: "Certificate \($0)", issuer: "Issuer \($0)", year: 2000 + $0) },
            interests: (1...8).map { "Interest \($0)" },
            social: [Social(platform: "LinkedIn", url: "https://linkedin.com/in/long")],
            documentLanguage: "en"
        )
    }

    // MARK: - Long links and skill names

    static let longLinkWords = [
        "portfolio.example.com/people/link-person/curriculum/2024/senior-engineer-profile",
        "certificates.example.org/verify/credential/ABCD-1234-EFGH-5678-IJKL-9012/senior-engineer/basic-life-support",
        "www.linkedin.com/in/link-person-senior-engineer-with-a-long-profile-name-0123456789abcdef"
    ]

    /// A token of 112 characters with no place to break it
    static let unbreakableToken = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

    /// Links longer than the column they are printed in, and skills with long names
    static func longLinks() -> CVModel {
        CVModel(
            name: "Links",
            personalInfo: PersonalInfo(
                name: "Link Person", title: "Engineer", location: "Berlin, Germany", email: "link.person@example.com",
                phone: "+49 30 1234 5678", portfolio: "https://" + longLinkWords[0] + "?ref=cv&utm=export",
                profile: "ProfileLinks: an engineer who publishes everything online."
            ),
            relevant_experience: [
                Experience(title: "Engineer", company: "Link Company", location: "Berlin", period: "2020 - 2024", description: "LinkExperience: built things.")
            ],
            education: [Education(degree: "MSc Engineering", school: "Technical University", period: "2015 - 2017")],
            skills: [
                Skill(name: "Cardiopulmonary resuscitation and emergency triage", level: 4),
                Skill(name: "Distributed systems", level: 5),
                Skill(name: "Extraordinarily long skill name without any rating at all", level: 0),
                Skill(name: "Go", level: 3), Skill(name: "Swift", level: 5), Skill(name: "Kubernetes operations", level: 2)
            ],
            languages: [Language(name: "German", level: .native)],
            certifications: [
                Certification(name: "Credential With A Link", issuer: "Certifier", year: 2023, url: "https://" + longLinkWords[1]),
                Certification(name: "Credential With A Token", issuer: "Certifier", year: 2022, url: "https://x.example/" + unbreakableToken)
            ],
            interests: ["Climbing"],
            social: [Social(platform: "LinkedIn", url: "https://" + longLinkWords[2])],
            documentLanguage: "en"
        )
    }

    /// Ten entries of about 1,300 characters, with the certificates, languages and links that go after them.
    /// Their number is chosen so that the last page is between 20% and 85% full in each design, on iOS 26.5 and 27.0:
    /// a page nearly empty or nearly full would be one more or fewer on another version of the system.
    private static func tenLongEntries() -> CVModel {
        var cv = long(name: "Long 10", experiences: 10, paragraphs: 4, certifications: 8)
        cv.languages = ["English", "French", "German", "Spanish", "Italian"].map { Language(name: $0, level: .b2) }
        cv.social = (1...4).map { Social(platform: "Network \($0)", url: "https://network\($0).example.com/long") }
        return cv
    }

    // MARK: - Long contact details

    /// A long email, location and address: the contact line of a design has to wrap between its items
    static func longContacts() -> CVModel {
        CVModel(
            name: "Contacts",
            personalInfo: PersonalInfo(
                name: "Contact Person", title: "Engineer", location: "Berlin-Charlottenburg, Germany (Europe/Berlin)",
                email: "contact.person.with.a.very.long.address@subdomain.example-company.com",
                phone: "+49 (0)30 1234 5678 ext. 99", portfolio: "https://contact.example.com/people/contact-person/curriculum/2024/profile",
                profile: "ProfileContacts: an engineer who is easy to reach."
            ),
            relevant_experience: [
                Experience(title: "Engineer", company: "Contact Company", location: "Berlin", period: "2020 - 2024", description: "ContactExperience: built things.")
            ],
            skills: [Skill(name: "Swift", level: 5), Skill(name: "Go", level: 3)],
            documentLanguage: "en"
        )
    }

    // MARK: - Realistic

    /// `experiences` entries of `bullets` one-line bullets, as people write them
    static func realistic(name: String, experiences: Int, bullets: Int) -> CVModel {
        let experienceItems = (1...experiences).map { index in
            let description = (1...bullets).map { bullet in
                let sentence = String(format: realisticSentences[(bullet - 1) % realisticSentences.count], index + bullet)
                return "- RealBullet-\(index)-\(bullet): \(sentence)."
            }.joined(separator: "\n")
            return Experience(title: "Position \(index)", company: "Employer \(index)", location: "Town \(index)",
                              period: "\(2024 - 2 * index) - \(2026 - 2 * index)", description: description)
        }
        return CVModel(
            name: name,
            personalInfo: PersonalInfo(
                name: "Real Person", title: "Operations Manager", location: "Milan, Italy", email: "real@example.com",
                phone: "+39 02 1234 5678", portfolio: "https://real.example.com",
                profile: "ProfileReal: operations manager with a long record of delivering results in complex organisations."
            ),
            relevant_experience: experienceItems,
            education: [
                Education(degree: "MSc Management", school: "Bocconi University", period: "2005 - 2007"),
                Education(degree: "BSc Economics", school: "University of Milan", period: "2002 - 2005")
            ],
            skills: (1...8).map { Skill(name: "Skill \($0)", level: ($0 % 5) + 1) },
            languages: [Language(name: "Italian", level: .native), Language(name: "English", level: .c1)],
            certifications: [Certification(name: "PMP", issuer: "PMI", year: 2015), Certification(name: "Lean Six Sigma", issuer: "ASQ", year: 2012)],
            interests: ["Running", "Cooking", "Reading"],
            social: [Social(platform: "LinkedIn", url: "https://linkedin.com/in/real")],
            documentLanguage: "en"
        )
    }
}
