import Foundation
import PrestoCVDomain

/// Every field of a CV populated with a value of its own, so that a value found in the document can only come from its
/// field. No two values of the whole CV are equal (`MirrorCompletenessTests` checks it) and no integer is 1, the document's
/// schema version. The free text carries white space around it, which the mapper trims.
enum Fixtures {
    static let id = CVID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)

    static func date(_ year: Int, _ month: Int? = nil) -> PartialDate {
        guard let date = PartialDate(year: year, month: month) else { preconditionFailure("fixture date") }
        return date
    }

    static func period(_ start: PartialDate, _ end: PeriodEnd) -> Period {
        guard let period = Period(start: start, end: end) else { preconditionFailure("fixture period") }
        return period
    }

    /// A value with white space around it, as typed.
    static func padded(_ value: String) -> String { " \(value) " }

    static func link(_ raw: String) -> WebLink {
        guard let link = WebLink(raw) else { preconditionFailure("fixture link") }
        return link
    }

    static func fullCV() -> CV {
        guard let email = EmailAddress("ada@example.com"), let phone = PhoneNumber("+44 20 7946 0958"),
              let level4 = SkillLevel(4), let level2 = SkillLevel(2),
              let design = DesignChoice(design: "clean", palette: "navy", fonts: "serif"),
              let language = DocumentLanguage("it") else { preconditionFailure("fixture values") }
        let personal = PersonalDetails(fullName: padded("Ada Lovelace"), professionalTitle: padded("Analytical Engineer"), email: email, phone: phone,
                                       location: padded("London"), website: link("https://ada.example"),
                                       summary: padded("Wrote the first program for the Analytical Engine."))
        let sections = CVSections(
            experiences: [
                Experience(role: padded("Analyst"), company: padded("Babbage & Co"), location: "Cambridge", period: period(date(2019, 3), .current),
                           description: padded("Programmed the Engine")),
                Experience(role: "Clerk", company: "Old Firm", location: "Bath", period: period(date(2015), .unknown), description: "Kept ledgers"),
                Experience(role: "Tutor", company: "Home", location: "Oxford", period: period(date(2012, 5), .date(date(2014, 8))),
                           description: "Taught mathematics"),
            ],
            education: [Education(degree: padded("Mathematics"), school: padded("University"), period: period(date(2008, 9), .date(date(2011, 6))), description: "Honours")],
            skills: [Skill(name: padded("Swift"), level: level4), Skill(name: padded("Git"), level: level2)],
            languages: [LanguageSkill(language: padded("English"), proficiency: .native), LanguageSkill(language: "Italiano", proficiency: .b2)],
            certifications: [Certification(name: padded("Swift Certified"), issuer: padded("Apple"), issued: date(2021, 11), link: link("https://cert.example/one"),
                                           description: "Concurrency")],
            profiles: [ProfileLink(platform: padded("GitHub"), link: link("https://github.com/ada"))],
            interests: ["Poetry", "Chess"]
        )
        return CV(id: id, title: "My private list name", personal: personal, sections: sections, design: design, language: language)
    }
}
