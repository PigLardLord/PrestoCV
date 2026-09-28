import PrestoCVDomain
import CVDocumentModel
import CVDrafting

/// CV → CVDocument. Exhaustive and deterministic (ADR 0007): no UUID(), no Date(), no `default:`,
/// no display strings (dates stay typed; the renderer formats them in the document language, R13).
public struct CVToDocumentMapper: Sendable {
    public init() {}
    public func map(_ cv: CV, language: String) -> CVDocument {
        var sections: [Section] = []
        if !cv.experiences.isEmpty {
            sections.append(.experience(cv.experiences.map { e in
                ExperienceItem(role: e.role, company: e.company, period: e.period.map(period), description: e.description.isEmpty ? nil : e.description)
            }))
        }
        if !cv.skills.isEmpty { sections.append(.skills(cv.skills.map { SkillItem(name: $0.name, rating: $0.level?.value) })) }
        return CVDocument(language: language, person: Person(name: cv.fullName, professionalTitle: nil, email: cv.email?.value), sections: sections)
    }

    private func period(_ p: Period) -> DocumentPeriod {
        let start = DocumentDate(year: p.start.year, month: p.start.month)
        switch p.end {
        case .current: return DocumentPeriod(start: start, end: .present)
        case .date(let d): return DocumentPeriod(start: start, end: .date(DocumentDate(year: d.year, month: d.month)))
        case .unknown: return DocumentPeriod(start: start, end: .unspecified)
        }
    }
}

/// What the draft said that the CV cannot hold; shown during review, never dropped silently.
public enum DraftGap: Sendable, Equatable { case period(role: String, PeriodError), invalidEmail(String) }

/// CVDraft → CV, through the domain's single period rule (R6).
public struct DraftToCVMapper: Sendable {
    public init() {}
    public func map(_ draft: CVDraft, id: CVID) -> (cv: CV, gaps: [DraftGap]) {
        var gaps: [DraftGap] = []
        var email: EmailAddress?
        if let raw = draft.email { email = EmailAddress(raw); if email == nil { gaps.append(.invalidEmail(raw)) } }
        var cv = CV(id: id, fullName: draft.fullName ?? "", email: email)
        for job in draft.jobs.reversed() {
            var period: Period?
            do throws(PeriodError) {
                period = try Period.make(start: job.startYear.map { ($0, nil) }, end: job.endYear.map { ($0, nil) }, current: job.isCurrent)
            } catch { gaps.append(.period(role: job.role, error)) }
            cv.addExperience(Experience(role: job.role, company: job.company, period: period))
        }
        for s in draft.skills { cv.addSkill(Skill(name: s.name, level: s.proficiency.flatMap { SkillLevel(level($0)) })) }
        return (cv, gaps)
    }
    private func level(_ p: CVDraft.Proficiency) -> Int {
        switch p { case .beginner: 2; case .intermediate: 3; case .advanced: 4; case .expert: 5 }
    }
}
