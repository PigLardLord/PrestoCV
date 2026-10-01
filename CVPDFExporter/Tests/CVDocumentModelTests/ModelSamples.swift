import CVDocumentModel

/// Values of the model for the schema tests. The enumerations hold one value of every case of `Section`, `PeriodEnd` and
/// `LanguageItem.Level`, written by a `next` function whose switch has no default: a case added to the model does not
/// compile until it has a sample here, so the schema tests cannot silently leave it out.
enum ModelSamples {
    static let ends: [PeriodEnd] = chain(from: .present, next: next(after:))
    static let levels: [LanguageItem.Level] = chain(from: .a1, next: next(after:))
    static let sections: [Section] = chain(from: .summary("Writes programs."), next: next(after:))

    /// Every kind of section, every period end and every level, with every optional field present.
    static let populated = CVDocument(
        language: "en-GB",
        person: Person(name: "Ada Lovelace", professionalTitle: "Analyst", email: "ada@example.com", phone: "+44 20 7946 0000",
                       location: "London", website: "https://ada.example"),
        sections: sections)

    /// Required fields only.
    static let minimal: CVDocument = {
        var sections: [Section] = []
        sections.append(.summary(""))
        sections.append(.experience([ExperienceItem(role: "Analyst", company: "Engine Co")]))
        sections.append(.education([EducationItem(degree: "Mathematics", school: "Home")]))
        sections.append(.skills([SkillItem(name: "Notes")]))
        sections.append(.languages([LanguageItem(language: "English", level: .native)]))
        sections.append(.certifications([CertificationItem(name: "Diploma", issuer: "Society")]))
        sections.append(.profiles([ProfileLink(platform: "Web", url: "https://ada.example")]))
        sections.append(.interests([]))
        return CVDocument(language: "en", person: Person(name: "A"), sections: sections)
    }()

    static let withoutSections = CVDocument(language: "en", person: Person(name: "Ada"), sections: [])

    /// The smallest and the largest values the validator accepts for ratings, years and months.
    static let limits: CVDocument = {
        var sections: [Section] = []
        sections.append(.skills([SkillItem(name: "Least", rating: 1), SkillItem(name: "Most", rating: 5)]))
        sections.append(.certifications([CertificationItem(name: "First", issuer: "A", year: 1900), CertificationItem(name: "Last", issuer: "B", year: 2200)]))
        let first = DocumentPeriod(start: DocumentDate(year: 1900, month: 1), end: .date(DocumentDate(year: 1900, month: 1)))
        let last = DocumentPeriod(start: DocumentDate(year: 2200, month: 12), end: .date(DocumentDate(year: 2200, month: 12)))
        sections.append(.education([EducationItem(degree: "First", school: "A", period: first), EducationItem(degree: "Last", school: "B", period: last)]))
        return CVDocument(language: "en", person: Person(name: "A"), sections: sections)
    }()

    // MARK: Walking the cases of an enumeration

    private static func chain<T>(from first: T, next: (T) -> T?) -> [T] {
        var all = [first]
        while let following = next(all[all.count - 1]) { all.append(following) }
        return all
    }

    private static func next(after end: PeriodEnd) -> PeriodEnd? {
        switch end {
        case .present: .unspecified
        case .unspecified: .date(DocumentDate(year: 2020, month: 6))
        case .date: nil
        }
    }

    private static func next(after level: LanguageItem.Level) -> LanguageItem.Level? {
        switch level {
        case .a1: .a2
        case .a2: .b1
        case .b1: .b2
        case .b2: .c1
        case .c1: .c2
        case .c2: .native
        case .native: nil
        }
    }

    private static func next(after section: Section) -> Section? {
        switch section {
        case .summary: .experience(ends.map { experience(ending: $0) })
        case .experience: .education([education])
        case .education: .skills([SkillItem(name: "Swift", rating: 4)])
        case .skills: .languages(levels.map { LanguageItem(language: "Language \($0.rawValue)", level: $0) })
        case .languages: .certifications([CertificationItem(name: "Diploma", issuer: "Society", year: 2021, url: "https://society.example", description: "Awarded")])
        case .certifications: .profiles([ProfileLink(platform: "Web", url: "https://ada.example")])
        case .profiles: .interests(["Chess", "Poetry"])
        case .interests: nil
        }
    }

    private static func experience(ending end: PeriodEnd) -> ExperienceItem {
        ExperienceItem(role: "Analyst", company: "Engine Co", location: "London",
                       period: DocumentPeriod(start: DocumentDate(year: 2018, month: 4), end: end), description: "Wrote the first program.")
    }

    private static let education = EducationItem(
        degree: "Mathematics", school: "Home", period: DocumentPeriod(start: DocumentDate(year: 2010, month: 9), end: .date(DocumentDate(year: 2014, month: 6))),
        description: "Tutored by De Morgan.")
}
