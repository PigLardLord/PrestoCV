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
}
