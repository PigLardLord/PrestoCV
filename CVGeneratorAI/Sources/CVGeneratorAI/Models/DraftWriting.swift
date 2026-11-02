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
        /// Whether the description says the job is over: its text then speaks of it in the past. The summary request also reads a
        /// job as over by the end year its own request read (#354, round 10).
        public var hasEnded: Bool
        /// The clauses of the description that belong to the job, which its own request reads (ADR 0031, "A request per section").
        public let clauses: [String]
        /// Whether a clause of the job names some work, not only where the person worked: its request then asks first for what
        /// the person said (#354, round 11).
        public var clausesNameWork = true
        /// The words of the job's clauses that the check drops in a written duty: the job's request avoids them.
        public var avoid: [String] = []
        /// The duties the person said for the job, as the check reads them: its request writes them first.
        public var said = 0
        /// The duties typical of its title the job's request writes after the person's (`adding(said:)`): under the owner's
        /// decision O1 each job gets 3 to 4 duties, the person's first (ADR 0031). A job with no title and no duty the person
        /// said gets the duties typical of the headline title, and no title.
        public var adding = Self.leastDuties

        /// The duties each job gets at least, and from how many of the person's own it gets no typical one (O1).
        public static var leastDuties: Int { DraftDepth.isRich ? 5 : 3 }
        public static var mostDuties: Int { DraftDepth.isRich ? 6 : 4 }

        /// The typical duties a job of `said` stated duties needs: enough to reach `leastDuties`, at least one, and none from
        /// `mostDuties` on. Asked for a range, the request padded a job with the same duty said again (#354, round 10).
        public static func adding(said: Int) -> Int {
            said >= mostDuties ? 0 : max(leastDuties - said, 1)
        }

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

/// What one sentence of the summary is about (#354, round 13, O1): the current job's title and the field, the topics of its kept
/// duties, its kept tools, its title with two qualities, an ended job's first kept duty, or the person's studies and languages (probe
/// round 21). Asked for the whole summary from every job, the request ran short; asked of one slot, a sentence has one thing to say.
public struct SummaryTopic: Equatable, Sendable {
    /// The job's title, or the headline title for a job with none; nil when the CV has neither.
    public let title: String?
    /// The field the person works in, for the sentence on the role; nil for the other slots.
    public let field: String?
    /// The topics of the kept duties the sentence speaks of ("the junior technicians"); empty for the role and the qualities.
    public let work: [String]
    /// The qualities the sentence says the person works with; empty but for the qualities slot.
    public let qualities: [String]
    /// The kept tools the sentence says the person works with; empty but for the tools slot (#354, probe round 3).
    public let tools: [String]
    /// The person's studies, each its degree and school as the facts hold them; empty but for the studies slot of a rich draft
    /// (`DraftDepth`; #354, probe round 21).
    public let studies: [String]
    /// The names of the languages the person speaks, as the facts hold them, with no level; empty but for that slot.
    public let languages: [String]
    /// Whether the job is over: the sentence then speaks of it in the past.
    public let hasEnded: Bool

    public init(
        title: String?, field: String? = nil, work: [String] = [], qualities: [String] = [], tools: [String] = [],
        studies: [String] = [], languages: [String] = [], hasEnded: Bool
    ) {
        self.title = title
        self.field = field
        self.work = work
        self.qualities = qualities
        self.tools = tools
        self.studies = studies
        self.languages = languages
        self.hasEnded = hasEnded
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
