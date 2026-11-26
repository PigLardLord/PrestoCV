import CVDocumentModel
import CVDesignCatalog
import CVRendering

/// #467: CVs whose section after the profile falls at every height of a page's foot as the profile grows, one profile
/// line per paragraph. The names and contacts are made up.
public enum PageBreakDocument {
    /// Enough profile lengths that the section after the profile starts at every height of a page's foot.
    public static let summaryLines = 4...39

    /// A4 with room for every document: the longest takes five pages in the macOS fonts, one more than `PageSetup.a4`
    /// keeps, and a page the renderer drops would read as lost text.
    public static let page = PageSetup(widthPoints: PageSetup.a4.widthPoints, heightPoints: PageSetup.a4.heightPoints, maxPages: 8)

    /// What follows the profile.
    public enum Body: String, Sendable, CaseIterable {
        /// One role of eight one-line duties.
        case shortRole
        /// The most skills a section holds, 200, with names long enough that the section is longer than a page.
        case manySkills
        /// A first role of one-line duties, then a short role at another firm. The duties grow with the profile, from 20 to
        /// 55, so the first role grows from shorter than a page to longer than one.
        case longFirstRole
    }

    /// An imported design that sets the most the markup contract lets a section title set below its last line: the
    /// bottom padding and the bottom margin at `MarkupContract.titleBottomSpacing`, and a bottom border at
    /// `MarkupContract.borderWidth`, in em or, on a small title, in pt.
    public enum LimitDesign: String, Sendable, CaseIterable {
        case em, pt

        public var css: String {
            let spacing = MarkupContract.titleBottomSpacing, border = MarkupContract.borderWidth
            return switch self {
            case .em: ".cv-section-title{padding-bottom:\(spacing.em)em;margin-bottom:\(spacing.em)em;"
                + "border-bottom:\(border.em)em solid var(--color-primary)}"
            case .pt: ".cv-section-title{font-size:7pt;padding-bottom:\(spacing.pt)pt;margin-bottom:\(spacing.pt)pt;"
                + "border-bottom:\(border.pt)pt solid var(--color-primary)}"
            }
        }
    }

    public static func document(summaryLines: Int, body: Body) -> CVDocument {
        let profile = Section.summary((1...summaryLines).map { "Line \($0) of a profile that fills the page." }.joined(separator: "\n"))
        return CVDocument(language: "en", person: Person(name: "Alex Example", professionalTitle: "Software developer",
                                                         email: "alex@example.org", phone: "+49 30 0000000", location: "Berlin"),
                          sections: [profile] + sections(body, summaryLines: summaryLines))
    }

    /// The lines of the sections' starts that must never end a page: the titles, and the head of the first role.
    public static func startLines(_ headings: Headings) -> [String] {
        [headings.summary, headings.experience, headings.skills, "Senior developer", "Example GmbH", "Berlin",
         "01/2020 – \(headings.present)"]
    }

    private static func sections(_ body: Body, summaryLines: Int) -> [Section] {
        switch body {
        case .shortRole:
            [.experience([firstRole(duties: 8)])]
        case .manySkills:
            [.skills((1...200).map { SkillItem(name: "Skill \(number($0)) with a long name") })]
        case .longFirstRole:
            [.experience([firstRole(duties: summaryLines + 16),
                          role("Developer", at: "Sample AG", in: "Hamburg", from: DocumentDate(year: 2015, month: 3), duties: 3)])]
        }
    }

    /// The first role, whose head is in `startLines`.
    private static func firstRole(duties: Int) -> ExperienceItem {
        role("Senior developer", at: "Example GmbH", in: "Berlin", from: DocumentDate(year: 2020, month: 1), duties: duties)
    }

    private static func role(_ name: String, at company: String, in place: String, from start: DocumentDate, duties: Int) -> ExperienceItem {
        ExperienceItem(role: name, company: company, location: place, period: DocumentPeriod(start: start, end: .present),
                       description: (1...duties).map { "Duty \(number($0)) of the \(name.lowercased()), one line long." }
                           .joined(separator: "\n"))
    }

    /// Three digits, so no item's text is part of another's.
    private static func number(_ n: Int) -> String { n < 10 ? "00\(n)" : n < 100 ? "0\(n)" : "\(n)" }
}
