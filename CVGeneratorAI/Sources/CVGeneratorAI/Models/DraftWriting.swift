import Foundation

/// What the second pass of a draft writes from (ADR 0031): the facts that the rules kept from the first pass, and nothing of the
/// description. It holds the titles, the employers, the studies and the skills the person named, and no place or date; the names
/// of schools and people it holds (`names`) only for the tools request to mask them. The employer tells the trade of a role ("a
/// nursery" is no school, #354), and the rules drop a written sentence that names it.
public struct DraftBrief: Equatable, Sendable {
    /// A job of the draft, as the second pass sees it.
    public struct Role: Equatable, Sendable {
        /// The job title the rules kept; empty for a job kept by its employer alone, which the second pass describes from the
        /// headline title when there is one, with no title of its own (#354).
        public let title: String
        /// The employer the rules kept, if any.
        public let employer: String?
        /// Whether the description says the job is over: its text then speaks of it in the past.
        public let hasEnded: Bool
        /// The clauses of the description that belong to the job, which its own request reads (ADR 0031, "A request per section").
        public let clauses: [String]
        /// The words of the job's clauses that the check drops in a written duty: the job's request avoids them.
        public var avoid: [String] = []
        /// Whether the duties the person said for the job run to 40 characters: its request then asks for no typical duty (ADR 0031,
        /// D6).
        public var described = false
        /// The topics of the duties the checks kept for the job, which the summary request reads in place of the duties, which it
        /// would copy (#354, round 3).
        public var work: [String] = []

        public init(title: String, employer: String? = nil, hasEnded: Bool, clauses: [String] = []) {
            self.title = title
            self.employer = employer
            self.hasEnded = hasEnded
            self.clauses = clauses
        }
    }

    /// The English name of the language of the description ("Italian"), which the written text uses.
    public let language: String
    /// The person's headline title, when the rules kept one.
    public let headline: String?
    /// The jobs of the draft, in its order: `DraftWriting.roleDescriptions` answers them one for one.
    public var roles: [Role]
    /// The degrees the rules kept.
    public let studies: [String]
    /// The skills the person named, which the second pass does not repeat.
    public let namedSkills: [String]
    /// The sentences in which the person says what they do and what they are like at work, with no job (#354, round 1): the
    /// skills requests read them.
    public var own: [String] = []
    /// The summary's first sentence, which code writes from the facts; the summary request writes what follows it (#354, round 3).
    public var opening: String?
    /// The names of the draft (its employers, schools and person), which the tools request reads as "the company": it wrote a
    /// tool named after the employer (#354, round 7). The checks drop a tool that holds a word of one.
    public var names: [String] = []

    public init(language: String, headline: String?, roles: [Role], studies: [String], namedSkills: [String]) {
        self.language = language
        self.headline = headline
        self.roles = roles
        self.studies = studies
        self.namedSkills = namedSkills
    }

    /// The brief of the grounded first pass `facts`, or nil when there is nothing to write around: no headline title, no job title
    /// and no degree (a draft of no role gets no summary and no skills of the model's own), or a description of no known language.
    /// - Parameter contexts: The clauses of each job of `facts`, one for one with its `experience`.
    init?(_ facts: CVData, language: Vocabulary.Language?, contexts: [[String]] = []) {
        guard let language, let name = CVPrompt.languageName(forCode: language.rawValue) else { return nil }
        let roles = facts.experience.enumerated().map { index, job in
            Role(
                title: job.title, employer: job.company.presentValue, hasEnded: !job.current && job.endDate.presentValue != nil,
                clauses: contexts.indices.contains(index) ? contexts[index] : []
            )
        }
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

/// What the request of one job writes (ADR 0031, "A request per section"): the years it read in the job's own clauses, and its
/// duties as sentences. None of it is a fact until the rules check it.
public struct RoleWriting: Equatable, Sendable {
    /// The year the job started, as the person wrote it; nil when they did not say it.
    public let startDate: String?
    /// The year the job ended, as the person wrote it; nil when they did not say it or still work there.
    public let endDate: String?
    /// The duties, as whole sentences.
    public let duties: String?

    public init(startDate: String?, endDate: String?, duties: String?) {
        self.startDate = startDate
        self.endDate = endDate
        self.duties = duties
    }
}
