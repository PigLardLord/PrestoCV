import Foundation
import PrestoCVDomain

/// Identities for tests: a UUID whose sixteen bytes are all the same, so `repeating(0x11)` is `11111111-1111-…-111111111111`.
public enum FixtureID {
    /// - Parameter byte: The value of every byte of the identifier.
    public static func repeating(_ byte: UInt8) -> CVID {
        CVID(UUID(uuid: (byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte, byte)))
    }
}

/// A CV with every field populated, so completeness tests (mappers, persistence) see every leaf.
public enum FixtureCV {
    /// - Parameter id: The identity of the CV. By default `11111111-1111-1111-1111-111111111111`.
    public static func full(id: CVID = FixtureID.repeating(0x11)) -> CV {
        CV(id: id, title: "iOS roles", personal: personalDetails(), sections: sections(),
           design: DesignChoice(design: "modern", palette: "ocean", fonts: "classic"), language: DocumentLanguage("it"))
    }

    private static func personalDetails() -> PersonalDetails {
        PersonalDetails(fullName: "Ada Lovelace", professionalTitle: "iOS Engineer", email: EmailAddress("ada@example.com"),
                        phone: PhoneNumber("+39 06 1234567"), location: "Roma", website: link("https://ada.example"),
                        summary: "Builds careful software.")
    }

    private static func sections() -> CVSections {
        CVSections(experiences: [experience()], education: [education()], skills: skills(), languages: languages(),
                   certifications: [certification()], profiles: [ProfileLink(platform: "GitHub", link: link("https://github.com/ada"))],
                   interests: Interests(["Chess", "Running"]))
    }

    private static func experience() -> Experience {
        let current = Period(start: PartialDate(year: 2019, month: 3)!, end: .current)!
        return Experience(role: "Engineer", company: "Analytical", location: "London", period: current, description: "Engines")
    }

    private static func education() -> Education {
        let ended = Period(start: PartialDate(year: 2012, month: 9)!, end: .date(PartialDate(year: 2015, month: 7)!))!
        return Education(degree: "Mathematics", school: "Home", period: ended, description: "Tutored")
    }

    private static func skills() -> [Skill] {
        [Skill(name: "Swift", level: SkillLevel(5)), Skill(name: "Git", level: SkillLevel(3))]
    }

    private static func languages() -> [LanguageSkill] {
        [LanguageSkill(language: "Italian", proficiency: .native), LanguageSkill(language: "English", proficiency: .c1)]
    }

    private static func certification() -> Certification {
        Certification(name: "Swift Certified", issuer: "Apple", issued: PartialDate(year: 2021, month: 6),
                      link: link("https://cert.example/1"), description: "Concurrency")
    }

    private static func link(_ address: String) -> WebLink { WebLink(address)! }
}
