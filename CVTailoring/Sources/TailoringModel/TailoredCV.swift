/// One line of a tailored experience, and the statements of the source it comes from. A line that names none, or one of
/// another experience, can be built: that is a provenance failure the gate reports, so the model must represent it.
public struct TailoredLine: Hashable, Sendable {
    public let statement: Statement
    public let sources: [StatementRef]

    /// A line names at most `TailoringLimits.maxSourcesPerLine` sources, and its text is bounded (R8).
    public init(statement: Statement, sources: [StatementRef]) throws(TailoringModelError) {
        try Bounds.text(statement.text, .statement)
        try Bounds.count(sources.count, atMost: TailoringLimits.maxSourcesPerLine, .sources)
        self.statement = statement
        self.sources = sources
    }
}

/// An experience of a tailored CV, and the experience of the source it comes from.
public struct TailoredExperience: Hashable, Sendable {
    public let source: ExperienceRef
    public let role: String
    public let company: String
    public let location: String
    public let period: TailoringPeriod?
    public let lines: [TailoredLine]

    public init(source: ExperienceRef, role: String, company: String, location: String = "", period: TailoringPeriod? = nil,
                lines: [TailoredLine]) throws(TailoringModelError) {
        try Bounds.text(role, .role)
        try Bounds.text(company, .company)
        try Bounds.text(location, .location)
        try Bounds.count(lines.count, atMost: TailoringLimits.maxEntriesPerSection, .lines)
        self.source = source
        self.role = role
        self.company = company
        self.location = location
        self.period = period
        self.lines = lines
    }
}

/// The CV a tailoring produces: the shape of the source CV, with each experience's lines naming the source statements
/// they come from (ADR 0013).
///
/// It keeps its source, and every reference in it was made by that source or by a snapshot equal to it, and is in range
/// there. A reference made by another snapshot is refused, even when its position is in range of the source. So every
/// one resolves with `source.statement(_:)`.
///
/// It checks structure only: sizes, and that references are in range. That a line names a source, names one of its own
/// experience, or says only what the source says is for the provenance gate, so the model of a reply that fails those
/// checks must still be a value.
public struct TailoredCV: Hashable, Sendable {
    public let source: SourceCV
    public let language: TailoringLanguage
    public let personal: SourcePersonalDetails
    public let summary: String
    public let experiences: [TailoredExperience]
    public let education: [SourceEducation]
    public let skills: [SourceSkill]
    public let languages: [SourceLanguage]
    public let certifications: [SourceCertification]
    public let profiles: [SourceProfile]
    public let interests: [String]

    /// Refuses a reference that `source` did not make, or whose position it does not have, with `referenceOutOfRange`. Sections hold at most
    /// `TailoringLimits.maxEntriesPerSection` entries, and each text is bounded (R8).
    public init(source: SourceCV, language: TailoringLanguage, personal: SourcePersonalDetails, summary: String = "",
                experiences: [TailoredExperience] = [], education: [SourceEducation] = [], skills: [SourceSkill] = [],
                languages: [SourceLanguage] = [], certifications: [SourceCertification] = [], profiles: [SourceProfile] = [],
                interests: [String] = []) throws(TailoringModelError) {
        try Bounds.count(experiences.count, atMost: TailoringLimits.maxEntriesPerSection, .experiences)
        try Bounds.cvSections(summary: summary, education: education, skills: skills, languages: languages,
                              certifications: certifications, profiles: profiles, interests: interests)
        for experience in experiences {
            guard source.contains(experience.source) else { throw .referenceOutOfRange }
            for line in experience.lines where !line.sources.allSatisfy(source.contains) { throw .referenceOutOfRange }
        }
        self.source = source
        self.language = language
        self.personal = personal
        self.summary = summary
        self.experiences = experiences
        self.education = education
        self.skills = skills
        self.languages = languages
        self.certifications = certifications
        self.profiles = profiles
        self.interests = interests
    }
}
