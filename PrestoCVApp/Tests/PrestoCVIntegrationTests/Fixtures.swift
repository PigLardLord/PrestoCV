import Foundation
import PrestoCVDomain

/// Every field of a CV populated with a value of its own, so that a value found in the document can only come from its
/// field. The integers are distinct and none is 1, the document's schema version.
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

    static func link(_ raw: String) -> WebLink {
        guard let link = WebLink(raw) else { preconditionFailure("fixture link") }
        return link
    }

    static func fullCV() -> CV {
        guard let email = EmailAddress("ada@example.com"), let phone = PhoneNumber("+44 20 7946 0958"),
              let level4 = SkillLevel(4), let level3 = SkillLevel(3),
              let design = DesignChoice(design: "clean", palette: "navy", fonts: "serif"),
              let language = DocumentLanguage("it") else { preconditionFailure("fixture values") }
        let personal = PersonalDetails(fullName: "Ada Lovelace", professionalTitle: "Analytical Engineer", email: email, phone: phone,
                                       location: "London", website: link("https://ada.example"),
                                       summary: "Wrote the first program for the Analytical Engine.")
        let sections = CVSections(
            experiences: [
                Experience(role: "Analyst", company: "Babbage & Co", location: "Cambridge", period: period(date(2019, 3), .current),
                           description: "Programmed the Engine"),
                Experience(role: "Clerk", company: "Old Firm", location: "Bath", period: period(date(2015), .unknown), description: "Kept ledgers"),
                Experience(role: "Tutor", company: "Home", location: "Oxford", period: period(date(2012, 5), .date(date(2014, 8))),
                           description: "Taught mathematics"),
            ],
            education: [Education(degree: "Mathematics", school: "University", period: period(date(2008, 9), .date(date(2011, 6))), description: "Honours")],
            skills: [Skill(name: "Swift", level: level4), Skill(name: "Git", level: level3)],
            languages: [LanguageSkill(language: "English", proficiency: .native), LanguageSkill(language: "Italiano", proficiency: .b2)],
            certifications: [Certification(name: "Swift Certified", issuer: "Apple", issued: date(2021, 11), link: link("https://cert.example/one"),
                                           description: "Concurrency")],
            profiles: [ProfileLink(platform: "GitHub", link: link("https://github.com/ada"))],
            interests: ["Poetry", "Chess"]
        )
        return CV(id: id, title: "My private list name", personal: personal, sections: sections, design: design, language: language)
    }
}
