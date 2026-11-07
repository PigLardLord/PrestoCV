import Foundation
import CVDocumentModel

/// Documents with every field filled, for the tests that hold the JSON Schema to the type. A new section case breaks
/// `Kind.of` and `section(_:)` at compile time, so the schema tests cannot go on without a sample of it.
enum SchemaSamples {
    enum Kind: CaseIterable { case summary, experience, education, skills, languages, certifications, profiles, interests }

    static func kind(of section: Section) -> Kind {
        switch section {
        case .summary: .summary
        case .experience: .experience
        case .education: .education
        case .skills: .skills
        case .languages: .languages
        case .certifications: .certifications
        case .profiles: .profiles
        case .interests: .interests
        }
    }

    static let person = Person(name: "Ada", professionalTitle: "Engineer", email: "ada@example.com", phone: "+39 06 1234567", location: "Roma", website: "https://ada.example")
    static let period = DocumentPeriod(start: DocumentDate(year: 2019, month: 3), end: .date(DocumentDate(year: 2021, month: 6)))
    static let experience = ExperienceItem(role: "Analyst", company: "Babbage", location: "London", period: period, description: "Line 1")
    static let education = EducationItem(degree: "Mathematics", school: "Home", period: period, description: "Tutored")
    static let skill = SkillItem(name: "Swift", rating: 5)
    static let language = LanguageItem(language: "English", level: .native)
    static let certification = CertificationItem(name: "Swift Certified", issuer: "Apple", year: 2021, url: "https://cert.example/1", description: "Concurrency")
    static let profile = ProfileLink(platform: "GitHub", url: "https://github.com/ada")

    /// A section of the kind with `count` entries; nil for the summary, which has none.
    static func section(_ kind: Kind, count: Int) -> Section? {
        switch kind {
        case .summary: nil
        case .experience: .experience(Array(repeating: experience, count: count))
        case .education: .education(Array(repeating: education, count: count))
        case .skills: .skills(Array(repeating: skill, count: count))
        case .languages: .languages(Array(repeating: language, count: count))
        case .certifications: .certifications(Array(repeating: certification, count: count))
        case .profiles: .profiles(Array(repeating: profile, count: count))
        case .interests: .interests(Array(repeating: "Poetry", count: count))
        }
    }

    static func section(_ kind: Kind) -> Section { section(kind, count: 1) ?? .summary("A summary") }

    static let minimal = CVDocument(language: "en", person: Person(name: "Ada"), sections: [])
    static let full = CVDocument(language: "en-GB", person: person, sections: Kind.allCases.map(section))
}
