import Foundation
import CVDocumentModel

/// An invented CV for the reading check (#121): three roles that run back in time, two degrees, and every other section,
/// in the language the headings are printed in. The names, employers and contacts are made up.
public enum AtsFixture {
    public static let languages = ["en", "it", "es", "fr", "de", "pt"]

    public static func document(language: String) -> CVDocument {
        CVDocument(language: language, person: Person(name: "Marta Bellini", professionalTitle: "Food safety specialist", email: "marta.bellini@example.org",
                                                      phone: "+39 333 000 0000", location: "Bologna", website: "https://marta.example.org"),
                   sections: [.summary("Eight years of quality work in food production, from the line to the audit."), experience, education,
                              .skills([SkillItem(name: "Root cause analysis", rating: 5), SkillItem(name: "Audits"), SkillItem(name: "HACCP", rating: 4)]),
                              .languages([LanguageItem(language: "Italiano", level: .native), LanguageItem(language: "English", level: .c1)]),
                              .certifications([CertificationItem(name: "Lead auditor", issuer: "Example Institute", year: 2020, url: "https://cert.example.org/1")]),
                              .profiles([ProfileLink(platform: "Web", url: "https://marta.example.org/cv")]), .interests(["Hiking", "Chess"])])
    }

    private static let experience = Section.experience([
        ExperienceItem(role: "Head of quality", company: "Forno Aurora", location: "Bologna",
                       period: DocumentPeriod(start: DocumentDate(year: 2021, month: 4), end: .present), description: "Ran the audits of two plants."),
        ExperienceItem(role: "Quality engineer", company: "Pasta Dorata", location: "Modena",
                       period: DocumentPeriod(start: DocumentDate(year: 2017, month: 9), end: .date(DocumentDate(year: 2021, month: 3))), description: "Cut rejects by a third."),
        ExperienceItem(role: "Line technician", company: "Latteria Verde", period: DocumentPeriod(start: DocumentDate(year: 2014), end: .date(DocumentDate(year: 2017)))),
    ])

    private static let education = Section.education([
        EducationItem(degree: "Food technology", school: "University of Example", period: DocumentPeriod(start: DocumentDate(year: 2011), end: .date(DocumentDate(year: 2014)))),
        EducationItem(degree: "Chemistry diploma", school: "Istituto Esempio", period: DocumentPeriod(start: DocumentDate(year: 2006), end: .date(DocumentDate(year: 2011)))),
    ])
}
