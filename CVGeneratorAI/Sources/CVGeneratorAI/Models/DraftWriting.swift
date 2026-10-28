import Foundation

/// What the second pass of a draft writes from (ADR 0031): the facts that the rules kept from the first pass, and nothing of the
/// description. It holds the titles, the studies and the skills the person named, and no employer, school, place or person, so the
/// text written from it has no name to copy.
public struct DraftBrief: Equatable, Sendable {
    /// A job of the draft, as the second pass sees it.
    public struct Role: Equatable, Sendable {
        /// The job title the rules kept; empty for a job kept by its employer alone, which the second pass does not describe.
        public let title: String
        /// Whether the description says the job is over: its text then speaks of it in the past.
        public let hasEnded: Bool

        public init(title: String, hasEnded: Bool) {
            self.title = title
            self.hasEnded = hasEnded
        }
    }

    /// The English name of the language of the description ("Italian"), which the written text uses.
    public let language: String
    /// The person's headline title, when the rules kept one.
    public let headline: String?
    /// The jobs of the draft, in its order: `DraftWriting.roleDescriptions` answers them one for one.
    public let roles: [Role]
    /// The degrees the rules kept.
    public let studies: [String]
    /// The skills the person named, which the second pass does not repeat.
    public let namedSkills: [String]

    public init(language: String, headline: String?, roles: [Role], studies: [String], namedSkills: [String]) {
        self.language = language
        self.headline = headline
        self.roles = roles
        self.studies = studies
        self.namedSkills = namedSkills
    }

    /// The brief of the grounded first pass `facts`, or nil when there is nothing to write around: no headline title, no job title
    /// and no degree (a draft of no role gets no summary and no skills of the model's own), or a description of no known language.
    init?(_ facts: CVData, language: Vocabulary.Language?) {
        guard let language, let name = CVPrompt.languageName(forCode: language.rawValue) else { return nil }
        let roles = facts.experience.map { Role(title: $0.title, hasEnded: !$0.current && $0.endDate.presentValue != nil) }
        let studies = facts.education.compactMap { $0.degree.presentValue }
        let headline = facts.personalInfo.title.presentValue
        guard headline != nil || roles.contains(where: { $0.title.presentValue != nil }) || !studies.isEmpty else { return nil }
        self.init(language: name, headline: headline, roles: roles, studies: studies, namedSkills: facts.skills.map(\.name))
    }
}

/// What the second pass of a draft writes around the facts (ADR 0031). None of it is a fact: the rules keep only the sentences and
/// the skills that state no fact of their own (`WrittenText`, `InferredSkills`).
public struct DraftWriting: Codable, Equatable, Sendable {
    /// Two to four sentences on the person's profession and strengths.
    public let summary: String?
    /// The duties typical of each role of the brief, one for one with `DraftBrief.roles`; nil for a role it does not describe.
    public let roleDescriptions: [String?]
    /// The tools, methods and knowledge of the trade that fit the roles.
    public let technologies: [String]
    /// The ways of working with people and tasks that fit the roles.
    public let softSkills: [String]

    public init(summary: String?, roleDescriptions: [String?], technologies: [String], softSkills: [String]) {
        self.summary = summary
        self.roleDescriptions = roleDescriptions
        self.technologies = technologies
        self.softSkills = softSkills
    }
}
