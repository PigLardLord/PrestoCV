import Foundation
import PrestoCVDomain
import CVDocumentModel

/// CV → CVDocument (ADR 0007): exhaustive and deterministic. It creates no identifier and reads no clock, and it writes
/// no display string: dates stay typed, and the renderer formats them in the document language (R13).
///
/// - The document is in the language it is asked for, not the CV's: the export workflow decides which language a
///   document is printed in.
/// - Sections come in a fixed order, each only when it has content: summary, experience, education, skills, languages,
///   certifications, profiles, interests.
/// - An optional text of the document is nil when the CV's text is only white space. Any other text is passed as it is.
/// - Identity, revision, dates of storage, title and design are not printed and are never mapped.
/// - `CVDocument` version 1 holds only the year of a certification, so the month it was issued is not carried.
public struct CVToDocumentMapper: Sendable {
    public init() {}

    public func map(_ cv: CV, language: DocumentLanguage) -> CVDocument {
        CVDocument(language: language.tag, person: person(cv.personal), sections: sections(of: cv))
    }

    // MARK: Person

    private func person(_ details: PersonalDetails) -> Person {
        Person(name: details.fullName, professionalTitle: nilIfBlank(details.professionalTitle), email: details.email?.value,
               phone: details.phone?.value, location: nilIfBlank(details.location), website: details.website?.value)
    }

    // MARK: Sections

    private func sections(of cv: CV) -> [Section] {
        let entries = cv.sections
        var result: [Section] = []
        if let summary = nilIfBlank(cv.personal.summary) { result.append(.summary(summary)) }
        if !entries.experiences.isEmpty { result.append(.experience(entries.experiences.map(experience))) }
        if !entries.education.isEmpty { result.append(.education(entries.education.map(education))) }
        if !entries.skills.isEmpty { result.append(.skills(entries.skills.map(skill))) }
        if !entries.languages.isEmpty { result.append(.languages(entries.languages.map(languageItem))) }
        if !entries.certifications.isEmpty { result.append(.certifications(entries.certifications.map(certification))) }
        if !entries.profiles.isEmpty { result.append(.profiles(entries.profiles.map(profile))) }
        if !entries.interests.isEmpty { result.append(.interests(entries.interests)) }
        return result
    }

    private func experience(_ entry: Experience) -> ExperienceItem {
        ExperienceItem(role: entry.role, company: entry.company, location: nilIfBlank(entry.location),
                       period: entry.period.map(period), description: nilIfBlank(entry.description))
    }

    private func education(_ entry: Education) -> EducationItem {
        EducationItem(degree: entry.degree, school: entry.school, period: entry.period.map(period),
                      description: nilIfBlank(entry.description))
    }

    private func skill(_ entry: Skill) -> SkillItem {
        SkillItem(name: entry.name, rating: entry.level?.value)
    }

    private func languageItem(_ entry: LanguageSkill) -> LanguageItem {
        LanguageItem(language: entry.language, level: level(entry.proficiency))
    }

    private func certification(_ entry: Certification) -> CertificationItem {
        CertificationItem(name: entry.name, issuer: entry.issuer, year: entry.issued?.year, url: entry.link?.value,
                          description: nilIfBlank(entry.description))
    }

    private func profile(_ entry: PrestoCVDomain.ProfileLink) -> CVDocumentModel.ProfileLink {
        CVDocumentModel.ProfileLink(platform: entry.platform, url: entry.link.value)
    }

    // MARK: Periods and levels

    private func period(_ value: Period) -> DocumentPeriod {
        DocumentPeriod(start: date(value.start), end: end(value.end))
    }

    private func date(_ value: PartialDate) -> DocumentDate {
        DocumentDate(year: value.year, month: value.month)
    }

    private func end(_ value: PrestoCVDomain.PeriodEnd) -> CVDocumentModel.PeriodEnd {
        switch value {
        case .current: .present
        case .date(let day): .date(date(day))
        case .unknown: .unspecified
        }
    }

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

    // MARK: Text

    private func nilIfBlank(_ text: String) -> String? {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }
}
