import Foundation
import CVDocumentModel

/// Renders the sections of a document in the structure of the markup contract. The titles, the word for an open
/// period and the level names come from the document's language.
struct SectionHTML {
    let headings: Headings

    /// nil for a section with nothing to print: it has no heading either.
    func render(_ section: Section) -> HTML? {
        switch section {
        case .summary(let text): titled("summary", headings.summary, HTML.optionalParagraph(class: "cv-summary", text: text))
        case .experience(let items): titled("experience", headings.experience, items.map(experience))
        case .education(let items): titled("education", headings.education, items.map(education))
        case .skills(let items): titled("skills", headings.skills, inline(items.map(skill)))
        case .languages(let items): titled("languages", headings.languages, items.map(language))
        case .certifications(let items): titled("certifications", headings.certifications, items.map(certification))
        case .profiles(let items): titled("profiles", headings.profiles, inline(items.compactMap(profile)))
        case .interests(let items): titled("interests", headings.interests, inline(items.map(interest)))
        }
    }

    private func titled(_ kind: String, _ title: String, _ items: [HTML]) -> HTML? {
        guard !items.isEmpty else { return nil }
        return .element(.section, attributes: [(.class, "cv-section"), (.dataSection, kind)],
                        children: [.element(.h2, class: "cv-section-title", text: title)] + items)
    }

    /// Inline entries (skills, profiles, interests) are separated by one space.
    private func inline(_ items: [HTML]) -> [HTML] {
        items.enumerated().flatMap { $0.offset == 0 ? [$0.element] : [.separator, $0.element] }
    }

    // MARK: Entries

    private func experience(_ item: ExperienceItem) -> HTML {
        var details = HTML.optionalParagraph(class: "cv-entry-location", text: item.location)
        details += period(item.period)
        details += HTML.optionalParagraph(class: "cv-entry-description", text: item.description)
        return entry(title: item.role, subtitle: item.company, details: details)
    }

    private func education(_ item: EducationItem) -> HTML {
        let details = period(item.period) + HTML.optionalParagraph(class: "cv-entry-description", text: item.description)
        return entry(title: item.degree, subtitle: item.school, details: details)
    }

    private func certification(_ item: CertificationItem) -> HTML {
        var details: [HTML] = []
        if let year = item.year { details.append(.element(.p, class: "cv-entry-period", text: "\(year)")) }
        details += HTML.optionalParagraph(class: "cv-entry-description", text: item.description)
        details += HTML.optionalAnchor(class: "cv-entry-link", to: item.url)
        return entry(title: item.name, subtitle: item.issuer, details: details)
    }

    private func entry(title: String, subtitle: String, details: [HTML]) -> HTML {
        let heading: [HTML] = [.element(.h3, class: "cv-entry-title", text: title), .element(.p, class: "cv-entry-subtitle", text: subtitle)]
        return .element(.article, class: "cv-entry", children: heading + details)
    }

    // MARK: Inline entries

    private func skill(_ item: SkillItem) -> HTML {
        var attributes: [(Attr, String)] = [(.class, "cv-skill")]
        if let rating = item.rating { attributes.append((.dataRating, "\(rating)")) }
        return .element(.span, attributes: attributes, children: [.text(item.name)])
    }

    private func language(_ item: LanguageItem) -> HTML {
        let level = HTML.element(.span, class: "cv-language-level", text: headings.levelName(item.level))
        return .element(.p, class: "cv-language", children: [.text(item.language + " "), level])
    }

    private func profile(_ item: ProfileLink) -> HTML? {
        guard let link = WebLink(item.url) else { return nil }
        let children: [HTML] = [.element(.span, class: "cv-profile-platform", text: item.platform), .separator,
                                .element(.span, class: "cv-profile-url", text: link.url)]
        return .anchor(class: "cv-profile", to: link, children: children)
    }

    private func interest(_ name: String) -> HTML { .element(.span, class: "cv-interest", text: name) }

    // MARK: Periods

    private func period(_ period: DocumentPeriod?) -> [HTML] {
        guard let period else { return [] }
        return [.element(.p, class: "cv-entry-period", text: periodText(period))]
    }

    private func periodText(_ period: DocumentPeriod) -> String {
        switch period.end {
        case .present: "\(period.start.text) – \(headings.present)"
        case .date(let end): "\(period.start.text) – \(end.text)"
        case .unspecified: period.start.text          // ended, end not given: never shown as "present"
        }
    }
}

private extension DocumentDate {
    /// `03/2019`, or `2019` for a date with no month.
    var text: String {
        guard let month else { return "\(year)" }
        return (month < 10 ? "0\(month)" : "\(month)") + "/\(year)"
    }
}
