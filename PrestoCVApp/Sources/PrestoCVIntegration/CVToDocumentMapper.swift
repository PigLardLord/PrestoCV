import Foundation
import PrestoCVDomain
import CVDocumentModel

/// Maps a CV to the document the exporter renders (ADR 0007). Exhaustive and deterministic: no clock, no identifiers,
/// no `default:` over a domain enum, so a new case or a new CV field cannot be left out without the build or the
/// mirror-completeness test failing. Text is trimmed and blank values are not printed; the order of the entries is the
/// order the person chose. Two things are deliberately not printed: the title of the CV (a private list name) and the
/// design choice (the export workflow resolves it).
public struct CVToDocumentMapper: Sendable {
    public init() {}

    public func map(_ cv: CV, language: DocumentLanguage) -> CVDocument {
        CVDocument(language: language.tag, person: person(cv.personal), sections: sections(cv))
    }

    // MARK: Header

    private func person(_ details: PersonalDetails) -> Person {
        Person(name: details.fullName.trimmed, professionalTitle: text(details.professionalTitle),
               email: details.email?.value, phone: details.phone?.value, location: text(details.location),
               website: details.website?.value)
    }

    // MARK: Sections, in print order

    private func sections(_ cv: CV) -> [CVDocumentModel.Section] {
        let content = cv.sections
        var result: [CVDocumentModel.Section] = []
        if let summary = text(cv.personal.summary) { result.append(.summary(summary)) }
        let experiences = content.experiences.map(experience)
        if !experiences.isEmpty { result.append(.experience(experiences)) }
        let education = content.education.map(education)
        if !education.isEmpty { result.append(.education(education)) }
        let skills = content.skills.map { SkillItem(name: $0.name.trimmed, rating: $0.level?.value) }
        if !skills.isEmpty { result.append(.skills(skills)) }
        let languages = content.languages.map { LanguageItem(language: $0.language.trimmed, level: level($0.proficiency)) }
        if !languages.isEmpty { result.append(.languages(languages)) }
        let certifications = content.certifications.map(certification)
        if !certifications.isEmpty { result.append(.certifications(certifications)) }
        let profiles = content.profiles.map { CVDocumentModel.ProfileLink(platform: $0.platform.trimmed, url: $0.link.value) }
        if !profiles.isEmpty { result.append(.profiles(profiles)) }
        let interests = content.interests.map(\.trimmed).filter { !$0.isEmpty }
        if !interests.isEmpty { result.append(.interests(interests)) }
        return result
    }

    private func experience(_ item: Experience) -> ExperienceItem {
        ExperienceItem(role: item.role.trimmed, company: item.company.trimmed, location: text(item.location),
                       period: item.period.map(period), description: text(item.description))
    }

    private func education(_ item: Education) -> EducationItem {
        EducationItem(degree: item.degree.trimmed, school: item.school.trimmed, period: item.period.map(period),
                      description: text(item.description))
    }

    /// The document carries the year only: a certification date is printed as a year.
    private func certification(_ item: Certification) -> CertificationItem {
        CertificationItem(name: item.name.trimmed, issuer: item.issuer.trimmed, year: item.issued?.year,
                          url: item.link?.value, description: text(item.description))
    }

    // MARK: Values

    private func period(_ period: Period) -> DocumentPeriod {
        DocumentPeriod(start: date(period.start), end: end(period.end))
    }

    private func end(_ end: PrestoCVDomain.PeriodEnd) -> CVDocumentModel.PeriodEnd {
        switch end {
        case .current: .present
        case .date(let date): .date(self.date(date))
        case .unknown: .unspecified
        }
    }

    private func date(_ date: PartialDate) -> DocumentDate { DocumentDate(year: date.year, month: date.month) }

    private func level(_ proficiency: LanguageProficiency) -> LanguageItem.Level {
        switch proficiency {
        case .a1: .a1
        case .a2: .a2
        case .b1: .b1
        case .b2: .b2
        case .c1: .c1
        case .c2: .c2
        case .native: .native
        }
    }

    /// A trimmed value, or nil when nothing is left to print.
    private func text(_ value: String) -> String? {
        let trimmed = value.trimmed
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
