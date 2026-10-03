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
    public func experienceRef(at index: Int) throws(TailoringModelError) -> ExperienceRef {
        guard experiences.indices.contains(index) else { throw .referenceOutOfRange }
        return ExperienceRef(index: index)
    }

    /// A reference to a line of an experience, both counted from 0.
    public func statementRef(experience: Int, line: Int) throws(TailoringModelError) -> StatementRef {
        let ref = try experienceRef(at: experience)
        guard experiences[ref.index].statements.indices.contains(line) else { throw .referenceOutOfRange }
        return StatementRef(experience: ref, line: line)
    }

    /// The experience a reference names. A reference is meaningful only for the snapshot that made it, so one that does
    /// not fit this snapshot is `referenceOutOfRange`, never a trap (R9). The references of a `TailoredCV` always
    /// resolve against its own `source`.
    public func experience(_ ref: ExperienceRef) throws(TailoringModelError) -> SourceExperience {
        guard contains(ref) else { throw .referenceOutOfRange }
        return experiences[ref.index]
    }

    /// The statement a reference names, with the same guarantee as `experience(_:)`: a reference whose experience or
    /// whose line this snapshot does not have is `referenceOutOfRange`.
    public func statement(_ ref: StatementRef) throws(TailoringModelError) -> Statement {
        guard contains(ref) else { throw .referenceOutOfRange }
        return experiences[ref.experience.index].statements[ref.line]
    }

    func contains(_ ref: ExperienceRef) -> Bool {
        experiences.indices.contains(ref.index)
    }

    func contains(_ ref: StatementRef) -> Bool {
        contains(ref.experience) && experiences[ref.experience.index].statements.indices.contains(ref.line)
    }
}
