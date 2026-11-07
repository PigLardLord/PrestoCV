import Foundation
import CVDocumentModel
import CVRendering

/// The text the markup contract prints for a document, which the naive reader looks for (#121).
enum AtsFixtureText {
    static func heading(of section: Section, _ h: Headings) -> String? {
        switch section {
        case .summary(let text): text.isEmpty ? nil : h.summary
        case .experience(let items): items.isEmpty ? nil : h.experience
        case .education(let items): items.isEmpty ? nil : h.education
        case .skills(let items): items.isEmpty ? nil : h.skills
        case .languages(let items): items.isEmpty ? nil : h.languages
        case .certifications(let items): items.isEmpty ? nil : h.certifications
        case .profiles(let items): items.isEmpty ? nil : h.profiles
        case .interests(let items): items.isEmpty ? nil : h.interests
        }
    }

    static func date(_ d: DocumentDate) -> String {
        guard let m = d.month else { return "\(d.year)" }
        return (m < 10 ? "0\(m)" : "\(m)") + "/\(d.year)"
    }

    static func period(_ p: DocumentPeriod, _ h: Headings) -> String {
        switch p.end {
        case .present: "\(date(p.start)) – \(h.present)"
        case .date(let end): "\(date(p.start)) – \(date(end))"
        case .unspecified: date(p.start)
        }
    }

    /// The fields whose recovery the score counts: the person, each entry's title, subtitle and period, skills, languages.
    static func fields(_ document: CVDocument) -> [String] {
        let p = document.person
        return [p.name] + [p.professionalTitle, p.email, p.phone, p.location].compactMap { $0 } + document.sections.flatMap(sectionFields)
    }

    private static func sectionFields(_ section: Section) -> [String] {
        switch section {
        case .summary: []
        case .experience(let items): items.flatMap { [$0.role, $0.company] }
        case .education(let items): items.flatMap { [$0.degree, $0.school] }
        case .skills(let items): items.map(\.name)
        case .languages(let items): items.map(\.language)
        case .certifications(let items): items.flatMap { [$0.name, $0.issuer] }
        case .profiles(let items): items.map(\.platform)
        case .interests(let items): items
        }
    }
}
