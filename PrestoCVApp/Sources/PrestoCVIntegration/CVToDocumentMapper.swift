import Foundation
import PrestoCVDomain
import CVDocumentModel

/// Maps a CV to the document the exporter renders (ADR 0007). Exhaustive and deterministic: no clock, no identifiers,
/// no `default:` over a domain enum, so a new case or a new CV field cannot be left out without the build or the
/// mirror-completeness test failing. Text is trimmed and a blank value is not printed. An item with nothing to print
/// is not printed either: a skill, language or certification with a blank name, an experience or education entry whose
/// fields are all blank. An entry with some value prints what it has. The order of the entries is the order the person chose. Two things are deliberately not printed: the title of the CV (a private list name) and the
/// design choice (the export workflow resolves it).
public struct CVToDocumentMapper: Sendable {
    public init() {}

    public func map(_ cv: CV, language: DocumentLanguage) -> CVDocument {
        CVDocument(language: language.tag, person: person(cv.personal), sections: sections(cv))
    }

    // MARK: Header

    private func person(_ details: PersonalDetails) -> Person {
        Person(name: line(details.fullName), professionalTitle: text(details.professionalTitle),
               email: details.email?.value, phone: details.phone?.value, location: text(details.location),
               website: details.website?.value)
    }

    // MARK: Sections, in print order

    private func sections(_ cv: CV) -> [CVDocumentModel.Section] {
        let content = cv.sections
        var result: [CVDocumentModel.Section] = []
        if let summary = block(cv.personal.summary) { result.append(.summary(summary)) }
        let experiences = content.experiences.compactMap(experience)
        if !experiences.isEmpty { result.append(.experience(experiences)) }
        let education = content.education.compactMap(education)
        if !education.isEmpty { result.append(.education(education)) }
        let skills = content.skills.compactMap { item in
            text(item.name).map { SkillItem(name: $0, rating: item.level?.value) }
        }
        if !skills.isEmpty { result.append(.skills(skills)) }
        let languages = content.languages.compactMap { item in
            text(item.language).map { LanguageItem(language: $0, level: level(item.proficiency)) }
        }
        if !languages.isEmpty { result.append(.languages(languages)) }
        let certifications = content.certifications.compactMap(certification)
        if !certifications.isEmpty { result.append(.certifications(certifications)) }
        let profiles = content.profiles.map { CVDocumentModel.ProfileLink(platform: line($0.platform), url: $0.link.value) }
        if !profiles.isEmpty { result.append(.profiles(profiles)) }
        let interests = content.interests.map(line).filter { !$0.isEmpty }
        if !interests.isEmpty { result.append(.interests(interests)) }
        return result
    }

    /// Nil when no field has a value; otherwise what the entry has.
    private func experience(_ item: Experience) -> ExperienceItem? {
        let result = ExperienceItem(role: line(item.role), company: line(item.company), location: text(item.location),
                                    period: item.period.map(period), description: block(item.description))
        let hasValue = !result.role.isEmpty || !result.company.isEmpty || result.location != nil || result.period != nil
            || result.description != nil
        return hasValue ? result : nil
    }

    /// Nil when no field has a value; otherwise what the entry has.
    private func education(_ item: Education) -> EducationItem? {
        let result = EducationItem(degree: line(item.degree), school: line(item.school), period: item.period.map(period),
                                   description: block(item.description))
        let hasValue = !result.degree.isEmpty || !result.school.isEmpty || result.period != nil || result.description != nil
        return hasValue ? result : nil
    }

    /// The document carries the year only: a certification date is printed as a year. Nil when the name is blank.
    private func certification(_ item: Certification) -> CertificationItem? {
        guard let name = text(item.name) else { return nil }
        return CertificationItem(name: name, issuer: line(item.issuer), year: item.issued?.year, url: item.link?.value,
                                 description: block(item.description))
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

    /// A single-line value, or nil when nothing is left to print.
    private func text(_ value: String) -> String? {
        let result = line(value)
        return result.isEmpty ? nil : result
    }

    /// A multi-line value (summary, descriptions), or nil when nothing is left to print.
    private func block(_ value: String) -> String? {
        let result = Self.clean(value, lineBreak: "\n").trimmed
        return result.isEmpty ? nil : result
    }

    private func line(_ value: String) -> String { Self.clean(value, lineBreak: " ").trimmed }

    /// Only what the exporter's validator accepts (`CVDocumentValidator`): the domain holds any text, and a pasted CV
    /// carries CRLF, tabs and stray controls. CRLF, CR, VT, FF and NEL are line breaks (one `lineBreak` each), a tab is a
    /// space, any other control character and the explicit bidirectional embeddings, overrides and isolates (which
    /// reorder what is printed) are dropped. The rule of the domain itself is issue #102.
    private static func clean(_ value: String, lineBreak: Unicode.Scalar) -> String {
        var result = String.UnicodeScalarView()
        var afterCarriageReturn = false
        for scalar in value.unicodeScalars {
            defer { afterCarriageReturn = scalar == "\r" }
            switch scalar {
            case "\n" where afterCarriageReturn: continue
            case "\n", "\r", "\u{0B}", "\u{0C}", "\u{85}": result.append(lineBreak)
            case "\t": result.append(" ")
            default:
                let reorders = (0x202A...0x202E).contains(scalar.value) || (0x2066...0x2069).contains(scalar.value)
                if scalar.properties.generalCategory != .control, !reorders { result.append(scalar) }
            }
        }
        return String(result)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
