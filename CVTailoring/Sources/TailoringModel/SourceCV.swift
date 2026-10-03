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
    /// A hash of the content, computed once. The references this snapshot makes carry it, so that another snapshot
    /// refuses them, and an equal one, with the same content and so the same fingerprint, accepts them. The hasher is
    /// seeded per process, so a fingerprint is neither stable across processes nor predictable: references are never
    /// serialised.
    let fingerprint: Int

    /// Each section holds at most `TailoringLimits.maxEntriesPerSection` entries, and each text is bounded (R8).
    public init(language: TailoringLanguage, personal: SourcePersonalDetails, summary: String = "",
                experiences: [SourceExperience] = [], education: [SourceEducation] = [], skills: [SourceSkill] = [],
                languages: [SourceLanguage] = [], certifications: [SourceCertification] = [], profiles: [SourceProfile] = [],
                interests: [String] = []) throws(TailoringModelError) {
        try Bounds.count(experiences.count, atMost: TailoringLimits.maxEntriesPerSection, .experiences)
        try Bounds.cvSections(summary: summary, education: education, skills: skills, languages: languages,
                              certifications: certifications, profiles: profiles, interests: interests)
        var hasher = Hasher()
        hasher.combine(language)
        hasher.combine(personal)
        hasher.combine(summary)
        hasher.combine(experiences)
        hasher.combine(education)
        hasher.combine(skills)
        hasher.combine(languages)
        hasher.combine(certifications)
        hasher.combine(profiles)
        hasher.combine(interests)
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
        self.fingerprint = hasher.finalize()
    }

    // MARK: References

    /// A reference to the experience at `index`, counted from 0. It carries this snapshot.
    public func experienceRef(at index: Int) throws(TailoringModelError) -> ExperienceRef {
        guard experiences.indices.contains(index) else { throw .referenceOutOfRange }
        return ExperienceRef(index: index, snapshot: fingerprint)
    }

    /// A reference to a line of an experience, both counted from 0. It carries this snapshot.
    public func statementRef(experience: Int, line: Int) throws(TailoringModelError) -> StatementRef {
        let ref = try experienceRef(at: experience)
        guard experiences[ref.index].statements.indices.contains(line) else { throw .referenceOutOfRange }
        return StatementRef(experience: ref, line: line)
    }

    /// The experience a reference names. A reference made by another snapshot is `referenceOutOfRange`, even when its
    /// position is in range here, and so is one whose position this snapshot does not have; never a trap (R9). A
    /// reference made by an equal snapshot resolves. The references of a `TailoredCV` always resolve against its own
    /// `source`.
    public func experience(_ ref: ExperienceRef) throws(TailoringModelError) -> SourceExperience {
        guard contains(ref) else { throw .referenceOutOfRange }
        return experiences[ref.index]
    }

    /// The statement a reference names, with the same guarantee as `experience(_:)`.
    public func statement(_ ref: StatementRef) throws(TailoringModelError) -> Statement {
        guard contains(ref) else { throw .referenceOutOfRange }
        return experiences[ref.experience.index].statements[ref.line]
    }

    /// Whether this snapshot, or one equal to it, made the reference, and its position exists here.
    func contains(_ ref: ExperienceRef) -> Bool {
        ref.snapshot == fingerprint && experiences.indices.contains(ref.index)
    }

    func contains(_ ref: StatementRef) -> Bool {
        contains(ref.experience) && experiences[ref.experience.index].statements.indices.contains(ref.line)
    }
}
