import Foundation
import PrestoCVDomain

extension CVFileV1 {
    /// The CV this file stores, or the first reason it is not valid.
    func toDomain() throws(Invalid) -> CV {
        try checkEnvelope()
        try checkSizes()
        return try CV(id: CVID(id), revision: revision, createdAt: createdAt, updatedAt: updatedAt, title: title,
                      personal: personal.toDomain(), sections: sectionsToDomain(), design: design?.toDomain(),
                      language: DocumentLanguage.canonical(ifPresent: language, field: "language"))
    }

    private func checkEnvelope() throws(Invalid) {
        guard schemaVersion == Self.version else { throw Invalid(reason: "version") }
        guard (1...Int(Int32.max)).contains(revision) else { throw Invalid(reason: "revision") }   // no overflow on +1
    }

    private func sectionsToDomain() throws(Invalid) -> CVSections {
        let sections = try CVSections(experiences: experiences.toDomain(), education: education.toDomain(), skills: skills.toDomain(),
                                      languages: languages.toDomain(), certifications: certifications.toDomain(),
                                      profiles: profiles.toDomain(), interests: interests)
        guard sections.interests == interests else { throw Invalid(reason: "interests") }   // trimmed, non-empty, unique
        return sections
    }
}

/// A value object that is parsed from a text and gives the same text back: the form a stored value must already be in.
protocol CanonicalText {
    init?(_ raw: String)
    var canonicalText: String { get }
}

extension EmailAddress: CanonicalText { var canonicalText: String { value } }
extension PhoneNumber: CanonicalText { var canonicalText: String { value } }
extension WebLink: CanonicalText { var canonicalText: String { value } }
extension DocumentLanguage: CanonicalText { var canonicalText: String { tag } }

extension CanonicalText {
    /// A stored value is exactly what its value object produces from it.
    static func canonical(_ raw: String, field: String) throws(CVFileV1.Invalid) -> Self {
        guard let parsed = Self(raw), parsed.canonicalText == raw else { throw CVFileV1.Invalid(reason: field) }
        return parsed
    }

    static func canonical(ifPresent raw: String?, field: String) throws(CVFileV1.Invalid) -> Self? {
        guard let raw else { return nil }
        return try canonical(raw, field: field)
    }
}

/// A stored entry that maps to a domain entry.
protocol StoredEntry {
    associatedtype Entry
    func toDomain() throws(CVFileV1.Invalid) -> Entry
}

extension Array where Element: StoredEntry {
    func toDomain() throws(CVFileV1.Invalid) -> [Element.Entry] {
        var entries: [Element.Entry] = []
        for stored in self { entries.append(try stored.toDomain()) }
        return entries
    }
}

extension CVFileV1.PersonalV1 {
    func toDomain() throws(CVFileV1.Invalid) -> PersonalDetails {
        try PersonalDetails(fullName: fullName, professionalTitle: professionalTitle,
                            email: EmailAddress.canonical(ifPresent: email, field: "email"),
                            phone: PhoneNumber.canonical(ifPresent: phone, field: "phone"), location: location,
                            website: WebLink.canonical(ifPresent: website, field: "website"), summary: summary)
    }
}

extension CVFileV1.PeriodFieldsV1 {
    /// `Period.make` is the one period rule; every stored combination is a period, no period, or corrupt.
    func toDomain(of entry: String) throws(CVFileV1.Invalid) -> Period? {
        do throws(PeriodError) {
            return try Period.make(start: start.map { ($0.year, $0.month) }, end: end.map { ($0.year, $0.month) }, current: current)
        } catch {
            throw CVFileV1.Invalid(reason: "\(entry) period: \(error)")
        }
    }
}

extension CVFileV1.ExperienceV1: StoredEntry {
    func toDomain() throws(CVFileV1.Invalid) -> Experience {
        let period = try CVFileV1.PeriodFieldsV1(start: start, end: end, current: current).toDomain(of: "experience")
        return Experience(role: role, company: company, location: location, period: period, description: description)
    }
}

extension CVFileV1.EducationV1: StoredEntry {
    func toDomain() throws(CVFileV1.Invalid) -> Education {
        let period = try CVFileV1.PeriodFieldsV1(start: start, end: end, current: current).toDomain(of: "education")
        return Education(degree: degree, school: school, period: period, description: description)
    }
}

extension CVFileV1.SkillV1: StoredEntry {
    func toDomain() throws(CVFileV1.Invalid) -> Skill {
        guard let level else { return Skill(name: name) }
        guard let valid = SkillLevel(level) else { throw CVFileV1.Invalid(reason: "skill level \(level)") }
        return Skill(name: name, level: valid)
    }
}

extension CVFileV1.LanguageV1: StoredEntry {
    func toDomain() throws(CVFileV1.Invalid) -> LanguageSkill {
        guard let proficiency = LanguageProficiency(rawValue: proficiency) else { throw CVFileV1.Invalid(reason: "proficiency") }
        return LanguageSkill(language: language, proficiency: proficiency)
    }
}

extension CVFileV1.CertificationV1: StoredEntry {
    func toDomain() throws(CVFileV1.Invalid) -> Certification {
        try Certification(name: name, issuer: issuer, issued: issuedDate(), link: WebLink.canonical(ifPresent: link, field: "certification link"),
                          description: description)
    }

    private func issuedDate() throws(CVFileV1.Invalid) -> PartialDate? {
        guard let issued else { return nil }
        guard let date = PartialDate(year: issued.year, month: issued.month) else { throw CVFileV1.Invalid(reason: "certification date") }
        return date
    }
}

extension CVFileV1.ProfileV1: StoredEntry {
    func toDomain() throws(CVFileV1.Invalid) -> ProfileLink {
        ProfileLink(platform: platform, link: try WebLink.canonical(link, field: "profile link"))
    }
}

extension CVFileV1.DesignV1 {
    func toDomain() throws(CVFileV1.Invalid) -> DesignChoice {
        guard let choice = DesignChoice(design: design, palette: palette, fonts: fonts) else { throw CVFileV1.Invalid(reason: "design") }
        return choice
    }
}
