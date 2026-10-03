/// The CV as it stood when the tailoring started: a snapshot (ADR 0013). Nothing in it changes; a tailored CV is a
/// separate value that names what it keeps of this one.
public struct SourceCV: Hashable, Sendable {
    public let language: TailoringLanguage
    public let personal: SourcePersonalDetails
    public let summary: String
    public let experiences: [SourceExperience]
    public let education: [SourceEducation]
    public let skills: [SourceSkill]
    public let languages: [SourceLanguage]
    public let certifications: [SourceCertification]
    public let profiles: [SourceProfile]
    public let interests: [String]

    /// Each section holds at most `TailoringLimits.maxEntriesPerSection` entries, and each text is bounded (R8).
    public init(language: TailoringLanguage, personal: SourcePersonalDetails, summary: String = "",
                experiences: [SourceExperience] = [], education: [SourceEducation] = [], skills: [SourceSkill] = [],
                languages: [SourceLanguage] = [], certifications: [SourceCertification] = [], profiles: [SourceProfile] = [],
                interests: [String] = []) throws(TailoringModelError) {
        try Bounds.count(experiences.count, atMost: TailoringLimits.maxEntriesPerSection, .experiences)
        try Bounds.cvSections(summary: summary, education: education, skills: skills, languages: languages,
                              certifications: certifications, profiles: profiles, interests: interests)
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

    // MARK: References

    /// A reference to the experience at `index`, counted from 0.
    public func experience(_ index: Int) throws(TailoringModelError) -> ExperienceRef {
        guard experiences.indices.contains(index) else { throw .referenceOutOfRange }
        return ExperienceRef(index: index)
    }

    /// A reference to a line of an experience, both counted from 0.
    public func statement(experience: Int, line: Int) throws(TailoringModelError) -> StatementRef {
        let experienceRef = try self.experience(experience)
        guard experiences[experienceRef.index].statements.indices.contains(line) else { throw .referenceOutOfRange }
        return StatementRef(experience: experienceRef, line: line)
    }

    /// The statement a reference names. It is total for a reference this snapshot made, which is always in range. A
    /// reference is meaningful only for the snapshot that made it: `TailoredCV` checks every reference it is given
    /// against its own source, so one from another snapshot cannot join a tailored CV.
    public func statement(_ ref: StatementRef) -> Statement {
        experiences[ref.experience.index].statements[ref.line]
    }
}
