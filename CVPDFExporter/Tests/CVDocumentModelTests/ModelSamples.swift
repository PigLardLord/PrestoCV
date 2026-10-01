import CVDocumentModel

/// The cases of `Section`, named. `init(of:)` switches over `Section` without a default, so a case added to the model does
/// not compile until it is named here; `allCases` then makes `ModelSamples` write a sample for it.
enum SectionKind: CaseIterable {
    case summary, experience, education, skills, languages, certifications, profiles, interests

    init(of section: Section) {
        switch section {
        case .summary: self = .summary
        case .experience: self = .experience
        case .education: self = .education
        case .skills: self = .skills
        case .languages: self = .languages
        case .certifications: self = .certifications
        case .profiles: self = .profiles
        case .interests: self = .interests
        }
    }
}

/// The cases of `PeriodEnd`, named, on the same terms as `SectionKind`.
enum PeriodEndKind: CaseIterable {
    case present, unspecified, date

    init(of end: PeriodEnd) {
        switch end {
        case .present: self = .present
        case .unspecified: self = .unspecified
        case .date: self = .date
        }
    }
}

/// Values of the model for the schema tests.
///
/// There is one sample for every case of `Section` and of `PeriodEnd`: the kinds list the cases and the `sample` functions
/// switch over them without a default, so a case added to the model has to be named and then given a sample before the
/// tests compile. `LanguageItem.Level` is `CaseIterable` itself. That each sample is of the case it is named after is
/// checked by a test.
enum ModelSamples {
    static let ends: [PeriodEnd] = PeriodEndKind.allCases.map { sample(of: $0) }
    static let sections: [Section] = SectionKind.allCases.map { sample(of: $0) }

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

    // MARK: One sample for every case

    private static func sample(of kind: PeriodEndKind) -> PeriodEnd {
        switch kind {
        case .present: .present
        case .unspecified: .unspecified
        case .date: .date(DocumentDate(year: 2020, month: 6))
        }
    }

    private static func sample(of kind: SectionKind) -> Section {
        switch kind {
        case .summary: .summary("Writes programs.")
        case .experience: .experience(ends.map { experience(ending: $0) })
        case .education: .education([education])
        case .skills: .skills([SkillItem(name: "Swift", rating: 4)])
        case .languages: .languages(LanguageItem.Level.allCases.map { LanguageItem(language: "Language \($0.rawValue)", level: $0) })
        case .certifications: .certifications([CertificationItem(name: "Diploma", issuer: "Society", year: 2021, url: "https://society.example", description: "Awarded")])
        case .profiles: .profiles([ProfileLink(platform: "Web", url: "https://ada.example")])
        case .interests: .interests(["Chess", "Poetry"])
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
