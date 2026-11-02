import Foundation

/// The draft written around the facts a section at a time (ADR 0031, "A request per section"). Code gives each job the clauses of
/// the description that belong to it; then a request per job writes its years and duties, a request the tools of each job and one
/// the soft skills, and a last request the summary from the jobs and skills kept. Each answer is checked by the rules of the final
/// check inside its step, and a step whose check finds too little gets one repair request that reads what it rejected and why.
///
/// The first request that fails or runs out of time leaves its part unwritten and the writing goes on; a second stops the writing:
/// the draft keeps the facts and what the earlier requests wrote, and the log says at which steps. Cancellation passes through. One
/// instance writes one draft.
@MainActor
final class SectionDraft {
    /// The jobs a draft writes duties for, in its order: a longer career gets no request for its oldest jobs.
    static let writtenJobs = 10
    /// The most technologies and soft skills a draft keeps: more of a rich draft (`DraftDepth`; probe round 13), as
    /// `InferredSkills.caps` keeps.
    nonisolated static var technologies: Int { DraftDepth.isRich ? 12 : 8 }
    nonisolated static var softSkills: Int { DraftDepth.isRich ? 6 : 5 }
    /// The most sentences a summary keeps, as its check keeps them (`CVDataSanitizer.summaryMost`; probe round 15).
    nonisolated static var summarySentences: Int { CVDataSanitizer.summaryMost }
    /// The most requests the summary makes, a sentence or its repair each (#354, round 13): more of a rich draft, whose summary
    /// asks a slot more and has more to repair, and asks for a fifth sentence (probe round 15).
    nonisolated static var summaryRequests: Int { DraftDepth.isRich ? 10 : 4 }
    /// A summary of this many sentences and characters asks no more (#354, round 13): a rich one asks on to 450 characters (probe
    /// round 15), as a CV typical of the trade under O1 has; it stopped at 300, with the work of the ended jobs unsaid.
    nonisolated static var summaryEnough: (sentences: Int, characters: Int) { DraftDepth.isRich ? (4, 450) : (2, 120) }
    /// Why a sentence that says an earlier sentence of the summary again goes, which its repair reads (#354, round 17).
    static let repeatsReason = "say something the summary does not say yet"

    private let service: any CVGenerationService
    private let sanitizer: CVDataSanitizer
    private let log: DraftLog
    private let limit: Duration
    private let description: String

    /// What the requests wrote so far, as their checks kept it: what the draft keeps when the writing stops.
    private var duties: [String?] = []
    private var years: [Int: RoleWriting] = [:]
    private var technologies: [String] = []
    private var softSkills: [String] = []
    private var summary: String?

    /// The requests that failed or ran out of time: the first leaves its part unwritten, the second stops the writing (ADR 0031).
    private var failures = 0

    /// A second request failed or ran out of time, and the log says so: the writing stops there.
    private struct Stopped: Error {}

    /// - Parameters:
    ///   - limit: How long each request may take.
    ///   - description: The person's description, which the checks read; no request reads it.
    init(service: any CVGenerationService, sanitizer: CVDataSanitizer, log: DraftLog, limit: Duration, description: String) {
        self.service = service
        self.sanitizer = sanitizer
        self.log = log
        self.limit = limit
        self.description = description
    }

    /// What the requests write around `facts`, the grounded `generated` draft of the extraction, and that draft with each employer
    /// as the description writes it with the noun of its kind, the place after it, the years each job's request read and the skills
    /// as the person wrote them: the final check reads both.
    /// Nil when there is nothing to write around (no title, job or degree, or no language of the six) or when no job can be given
    /// its clauses.
    func write(
        around facts: CVData, generated: CVData, language: Vocabulary.Language?
    ) async throws -> (writing: DraftWriting, draft: CVData)? {
        guard DraftBrief(facts, language: language) != nil else { return nil }
        // The employers as the description writes them with the noun of their kind, so that their clauses give their years.
        let generated = generated.with(experience: generated.experience.map { employed($0, language: language) })
        let context: CVDataSanitizer.DraftContext
        do {
            context = try sanitizer.draftContext(of: generated, against: description)
        } catch {
            log.unwritten(at: .attribution, by: error)
            return nil
        }
        let located = generated.with(experience: generated.experience.map(located))
        guard var brief = DraftBrief(facts, language: language, contexts: context.jobs.map { clauses(of: $0, in: generated) }) else {
            return nil
        }
        brief.own = context.own
        brief.names = generated.experience.map(\.company) + generated.education.compactMap(\.institution)
            + [generated.personalInfo.name].compactMap { $0 }
        let names = CVDataSanitizer.ownNames(of: generated)
        for number in brief.roles.indices {
            brief.roles[number].clausesNameWork = brief.roles[number].clauses.contains { CVDataSanitizer.namesWork($0, names: names) }
        }
        for number in brief.roles.indices where context.jobs.indices.contains(number) {
            let check = try? sanitizer.dutyCheck(of: located, job: context.jobs[number].job, duties: nil, against: description)
            brief.roles[number].avoid = check?.avoid ?? []
            if let check {
                brief.roles[number].said = check.pinned.count
                // The duties the person said, by clause: two sentences of two duties each are four (#354, round 15).
                let clauses = check.pinned.reduce(0) { $0 + DutyClauses.count(in: $1, language: language) }
                brief.roles[number].adding = DraftBrief.Role.adding(said: max(clauses, check.pinned.count))
            }
        }
        duties = Array(repeating: nil, count: brief.roles.count)

        do {
            try await writeJobs(of: brief, context: context, in: located)
            try await writeSkills(of: brief, around: dated(located, context: context))
            try await writeSummary(of: brief, field: context.field, around: dated(located, context: context))
            // A summary too short to read as one gets the titles the person held, latest first by the dates of the draft, written by
            // the code (ADR 0031).
            let held = facts.with(experience: dated(located, context: context).experience)
            if let floor = try? sanitizer.summaryFloor(
                of: held, summary: summary, most: Self.summarySentences, qualities: softSkills, against: description
            ) {
                summary = floor
            }
        } catch is Stopped {
            // The log said where; the draft keeps what the earlier requests wrote.
        }
        let writing = DraftWriting(summary: summary, roleDescriptions: duties, technologies: technologies, softSkills: softSkills)
        log.written(writing)
        return (writing, dated(located, context: context))
    }

    // MARK: - Attribution

    /// The clauses a job's request reads: those of the description that belong to it, and the text the extraction gave the job
    /// when no clause holds it, which says what the person did there.
    private func clauses(of job: CVDataSanitizer.DraftContext.Job, in generated: CVData) -> [String] {
        let said = generated.experience.indices.contains(job.job) ? generated.experience[job.job].description?.presentValue : nil
        guard let said, !job.clauses.contains(where: { $0.localizedCaseInsensitiveContains(said) }) else { return job.clauses }
        return job.clauses + [said]
    }

    /// `job` with its employer as the description writes it with the noun of its kind (`CVDataSanitizer.employer`).
    private func employed(_ job: Experience, language: Vocabulary.Language?) -> Experience {
        let company = CVDataSanitizer.employer(job.company, in: description, language: language)
        guard company != job.company else { return job }
        return Experience(
            title: job.title, company: company, location: job.location, startDate: job.startDate, endDate: job.endDate,
            current: job.current, description: job.description, achievements: job.achievements
        )
    }

    /// `job` with the place the description names right after its employer, when the extraction left its location empty or wrote
    /// the employer there.
    private func located(_ job: Experience) -> Experience {
        let empty = job.location.presentValue == nil || job.location.map { job.company.localizedCaseInsensitiveContains($0) } == true
        guard empty, let place = CVDataSanitizer.place(after: job.company, in: description) else { return job }
        return Experience(
            title: job.title, company: job.company, location: place, startDate: job.startDate, endDate: job.endDate,
            current: job.current, description: job.description, achievements: job.achievements
        )
    }

    /// `located` with the years each job's request read filling the dates the extraction left empty, and each technology as the
    /// person wrote it, without the verb it was said with, and none that is a clause (`statedSkill`): the rules check them as any
    /// date and skill.
    private func dated(_ located: CVData, context: CVDataSanitizer.DraftContext) -> CVData {
        var experience = located.experience
        for (number, role) in years where context.jobs.indices.contains(number) && experience.indices.contains(context.jobs[number].job) {
            let index = context.jobs[number].job
            let job = experience[index]
            experience[index] = Experience(
                title: job.title, company: job.company, location: job.location,
                startDate: job.startDate.presentValue ?? role.startDate?.presentValue,
                endDate: job.current ? job.endDate : job.endDate.presentValue ?? role.endDate?.presentValue,
                current: job.current, description: job.description, achievements: job.achievements
            )
        }
        let skills = located.skills.compactMap { skill in
            skill.kind == .technology
                ? sanitizer.statedSkill(skill.name, against: description).map { Skill(name: $0, level: skill.level, kind: skill.kind) }
                : skill
        }
        return located.with(experience: experience).with(skills: skills)
    }

    // MARK: - Jobs

    /// A request per job, in order, for the typical duties it needs (`DraftBrief.Role.adding`), its duties checked; a job whose
    /// stated and kept duties are fewer than three gets one repair that asks for exactly those missing, and what still fails goes
    /// (O1, ADR 0031). A job that needs no typical duty gets no request when the extraction read its years. A job keeps only its
    /// written duties, no more than it needs: the person's own come back in the final check.
    private func writeJobs(of brief: DraftBrief, context: CVDataSanitizer.DraftContext, in located: CVData) async throws {
        for number in brief.roles.indices.prefix(Self.writtenJobs) {
            // A job that needs no typical duty and whose years the extraction read gets no request: its own duties come back in
            // the final check (#354, round 10).
            let adding = brief.roles[number].adding
            guard adding > 0 || !Self.hasItsYears(number, context: context, in: located) else { continue }
            let failed = failures
            let role = try await request(.jobs) { try await self.service.writeJob(number: number, of: brief) }
            if let role { years[number] = role }
            // A job whose request failed gets no repair: a second failure would stop the writing before the skills and the summary.
            guard failures == failed, context.jobs.indices.contains(number) else { continue }
            let job = context.jobs[number].job
            guard let first = try? sanitizer.dutyCheck(
                of: located, job: job, duties: role?.duties.map(Self.mended), against: description
            ) else { continue }
            // No more typical duties than the job needs: an echo of the person's own duty goes in the check, and does not count.
            var kept = Array(first.kept.prefix(adding))
            if first.pinned.count + kept.count < DraftBrief.Role.leastDuties {
                let rejected = first.rejected.map(Self.quoted)
                let repaired = try await request(.jobs) { [kept] in
                    try await self.service.repairJob(number: number, of: brief, kept: first.pinned + kept, rejected: rejected)
                }
                if let repaired, let second = try? sanitizer.dutyCheck(
                    of: located, job: job, duties: Self.mended(repaired.joined(separator: " ")), keeping: kept, against: description
                ) {
                    kept += second.kept.prefix(adding - kept.count)
                }
            }
            duties[number] = kept.joined(separator: " ").presentValue
        }
    }

    /// Whether the extraction read the years of the job at `number`: its start, and its end unless it is current.
    private static func hasItsYears(_ number: Int, context: CVDataSanitizer.DraftContext, in located: CVData) -> Bool {
        guard context.jobs.indices.contains(number), located.experience.indices.contains(context.jobs[number].job) else { return false }
        let job = located.experience[context.jobs[number].job]
        return job.startDate.presentValue != nil && (job.current || job.endDate.presentValue != nil)
    }

    // MARK: - Skills

    /// The tools of each job title, a request each, the headline title first and a past title's only while the CV is short of
    /// tools (`mergedTools`), and the soft skills, cleaned by code against the tools the person names, then
    /// a request for the tools missing and one for the qualities missing, each asking one more, when the final check would keep
    /// fewer than `fewestTools` technologies or `fewestQualities` soft skills; each reads the skills the checks dropped, with the
    /// reason.
    private func writeSkills(of brief: DraftBrief, around dated: CVData) async throws {
        let sparse = brief.roles.count <= 1 && brief.roles.flatMap(\.clauses).joined().count < 80
        let fewestTools = Self.fewestTools(sparse: sparse)
        let order = dated.experience.count == brief.roles.count ? Self.latestFirst(dated.experience) : Array(brief.roles.indices)
        let headline = Self.headlineRole(of: brief, order: order)
        let groups = Self.headlineFirst(Self.toolGroups(of: brief), headline: headline)
        var answers: [[String]] = []
        for (group, roles) in groups.enumerated() {
            let count = Self.toolCount(group: group, groups: groups.count, sparse: sparse)
            answers.append(try await request(.skills) { try await self.service.writeTools(for: brief, roles: roles, count: count) } ?? [])
        }
        let stated = dated.skills.filter { $0.kind != .softSkill }.map(\.name)
        let language = sanitizer.language(of: description)
        let isKind = { (tool: String) in CVDataSanitizer.endsInAKindOfTool(tool, language: language) }
        let tools = try Self.mergedTools(answers, fewest: fewestTools, isKind: isKind) { tools in
            let checked = sanitizer.skillCheck(technologies: tools, softSkills: [], stated: stated, names: brief.names, against: description)
            let writing = DraftWriting(
                summary: nil, roleDescriptions: duties, technologies: Array(checked.technologies.prefix(Self.technologies)), softSkills: []
            )
            return try sanitizer.sanitize(dated, writing: writing, against: description).skills.count { $0.kind == .technology }
        }
        let qualities = try await request(.skills) { try await self.service.writeSoftSkills(for: brief) }
        // ADR 0031, D8: the work the person says they like doing is a soft skill in their own words, before those written.
        let liked = CVDataSanitizer.workLikings(in: description)
        var skills = sanitizer.skillCheck(
            technologies: tools, softSkills: liked + (qualities ?? []), stated: stated,
            names: brief.names, against: description
        )
        keep(skills)
        let kept = try kept(around: dated).skills
        let missingTools = max(fewestTools - kept.count { $0.kind == .technology }, 0)
        let missingQualities = max(Self.fewestQualities(sparse: sparse) - kept.count { $0.kind == .softSkill }, 0)
        guard missingTools > 0 || missingQualities > 0 else { return }
        let listedTools = kept.filter { $0.kind != .softSkill }.map(\.name)
        let listedQualities = kept.filter { $0.kind == .softSkill }.map(\.name)
        // One more of each kind short, as the checks may drop one, and two more tools of a rich draft, whose answer repeated the
        // tools listed (probe round 4); the answer is cut to the most of each kind. Asked 8 or more, the request ran out of the
        // trade's tools and wrote those of another (probe round 9): 6 at most.
        let toolsAsked = missingTools > 0 ? min(missingTools + (DraftDepth.isRich ? 2 : 1), 6) : 0
        let qualitiesAsked = missingQualities > 0 ? missingQualities + 1 : 0
        let rejected = Self.rejectedSkills(skills.dropped)
        // The tools are asked apart from the qualities: asked together, the tools came back as an activity and a bare record,
        // asked alone as a system of the trade (#354, round 8).
        // The tools asked are those of the headline title: asked those of the jobs, the request wrote a past trade's (#354, round 15).
        let title = headline.flatMap { brief.roles[$0].title.presentValue } ?? brief.headline
        var moreTools: [String] = []
        var moreQualities: [String] = []
        for (tools, qualities) in [(toolsAsked, 0), (0, qualitiesAsked)] where tools + qualities > 0 {
            let more = try await request(.skills) {
                try await self.service.writeMoreSkills(
                    for: brief, title: title, tools: tools, qualities: qualities, listedTools: listedTools,
                    listedQualities: listedQualities, rejected: rejected
                )
            }
            if tools > 0 { moreTools += more?.technologies ?? [] }
            if qualities > 0 { moreQualities += more?.softSkills ?? [] }
        }
        moreTools = sanitizer.repairedTools(moreTools, against: description)
        guard !moreTools.isEmpty || !moreQualities.isEmpty else { return }
        skills = sanitizer.skillCheck(
            technologies: skills.technologies + moreTools, softSkills: skills.softSkills + moreQualities, stated: stated,
            names: brief.names, against: description
        )
        keep(skills)
    }

    /// How many tools the request of the title `group` of `groups` asks, in the order asked (`headlineFirst`): a single title asks
    /// the fewest the CV needs (`fewestTools`) and one more, as a check may drop one; a title among others asks 2 or 3. One title
    /// asked 2 or 3 left the CV short every time, and the request for those missing named activities and bare kinds (#354, round 6).
    /// Of a rich draft (`DraftDepth`) the headline title asks as a single title does: a past title adds only its first kept tool
    /// (`mergedTools`), and a CV of several jobs stayed short of tools (probe round 4).
    static func toolCount(group: Int, groups: Int, sparse: Bool) -> ClosedRange<Int> {
        guard groups == 1 || (DraftDepth.isRich && group == 0) else { return 2...3 }
        let fewest = fewestTools(sparse: sparse)
        return fewest...(fewest + 1)
    }

    /// The fewest tools a draft keeps, of a `sparse` description or of the others: more of a rich draft (`DraftDepth`), a CV
    /// typical of the trade under O1 (probe rounds 4 and 13).
    static func fewestTools(sparse: Bool) -> Int {
        DraftDepth.isRich ? (sparse ? 6 : 10) : (sparse ? 3 : 4)
    }

    /// The fewest soft skills a draft keeps, of a `sparse` description or of the others: more of a rich draft (`DraftDepth`;
    /// probe round 13).
    static func fewestQualities(sparse: Bool) -> Int {
        DraftDepth.isRich ? (sparse ? 3 : 4) : (sparse ? 2 : 3)
    }

    /// The tools of the title groups' answers, the headline title's first (`headlineFirst`): its answer whole, then of each past
    /// title's answer the first item the check keeps, and only while the CV has fewer than `fewest` tools of the trade, as
    /// `tradeTools` counts them. A past title's request padded the CV with the tools of a trade the person left ("trailer",
    /// "truck loading equipment"; #354, round 15). A past title's first kept tool that is no kind of tool (`isKind`) comes before
    /// those that are: the first kept, "Montagesystem", left out the "Werkzeugkasten" of the trade. A single title's answer is the
    /// tools as they were.
    static func mergedTools(
        _ answers: [[String]], fewest: Int, isKind: (String) -> Bool, tradeTools: ([String]) throws -> Int
    ) rethrows -> [String] {
        guard var tools = answers.first else { return [] }
        for past in answers.dropFirst() {
            let have = try tradeTools(tools)
            guard have < fewest else { break }
            let raising = try past.filter { try tradeTools(tools + [$0]) > have }
            if let item = raising.first(where: { !isKind($0) }) ?? raising.first { tools.append(item) }
        }
        return tools
    }

    /// The headline role of `brief`: the first job of the headline title, else the latest by `order` (`latestFirst`).
    static func headlineRole(of brief: DraftBrief, order: [Int]) -> Int? {
        let title = { (text: String?) in text?.presentValue?.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
        if let headline = title(brief.headline), let number = brief.roles.indices.first(where: { title(brief.roles[$0].title) == headline }) {
            return number
        }
        return order.first(where: brief.roles.indices.contains)
    }

    /// `groups` with the group of the job at `headline` first, the others in their order.
    static func headlineFirst(_ groups: [[Int]], headline: Int?) -> [[Int]] {
        guard let headline, let first = groups.firstIndex(where: { $0.contains(headline) }) else { return groups }
        return [groups[first]] + groups.enumerated().filter { $0.offset != first }.map(\.element)
    }

    /// The jobs of `brief` by their title, in the order of the first of each, a job with no title by the headline: each title asks
    /// for its tools once (#354, round 6).
    static func toolGroups(of brief: DraftBrief) -> [[Int]] {
        var groups: [[Int]] = []
        var titles: [String: Int] = [:]
        for (index, role) in brief.roles.enumerated() {
            let title = (role.title.presentValue ?? brief.headline ?? "").lowercased()
            if let group = titles[title] {
                groups[group].append(index)
            } else {
                titles[title] = groups.count
                groups.append([index])
            }
        }
        return groups
    }

    /// The skills the checks dropped as the request for more skills reads them: the skill in quotes, then why it went, in words the
    /// model reads; a verb cut to its object kept the object, and is none.
    static func rejectedSkills(_ dropped: [CVDataSanitizer.Rejection]) -> [String] {
        dropped.filter { $0.reason != "verb cut" }.map {
            quoted(CVDataSanitizer.Rejection(sentence: $0.sentence, reason: skillReasons[$0.reason] ?? $0.reason))
        }
    }

    private static let skillReasons = [
        "activity": "an activity, not a tool", "a word for a skill": "names no skill", "verb": "a verb, not a noun",
        "fragment": "not a whole name", "another language": "in another language", "a tool": "a tool, not a quality",
        "a name": "a name, not a quality", "same kind as an earlier tool": "a tool of a kind already listed",
        "a kind of tool, not its name": "a general kind, not a named tool",
        "the same quality as an earlier one": "the same quality as one listed",
        "a part or a material, not a tool": "a part or a material the work is done on, not a tool",
        "a word of a name": "named after a company, a school or a person",
        "a record or a document, not a tool": "a record, a document or its scan, not a tool",
        "what the work is done on": "what the work is done on, not a tool",
    ]

    private func keep(_ skills: CVDataSanitizer.SkillVerdict) {
        technologies = Array(skills.technologies.prefix(Self.technologies))
        softSkills = Array(skills.softSkills.prefix(Self.softSkills))
    }

    /// `dated` with what the requests wrote so far, as the final check keeps it, without a summary.
    private func kept(around dated: CVData) throws -> CVData {
        let writing = DraftWriting(summary: nil, roleDescriptions: duties, technologies: technologies, softSkills: softSkills)
        return try sanitizer.sanitize(dated, writing: writing, against: description)
    }

    // MARK: - Summary

    /// The summary, last, a sentence at a time after the opening code writes from the facts (#354, round 13, O1): each request asks
    /// for one sentence on one slot (`summaryTopics`), the check reads it after the sentences kept, and a rejected sentence gets one
    /// repair with its reason. The requests stop once the summary has 2 sentences and 120 characters (4 and 450 in a rich draft, which
    /// keeps up to 5; probe round 15, and asks its studies slot still: `nextTopic`), after 4 requests (10 in a rich draft), or when no
    /// slot is left; the floor then writes what is still missing (`summaryFloor`). Asked for the whole summary at once, the request
    /// ran short.
    private func writeSummary(of brief: DraftBrief, field: String?, around dated: CVData) async throws {
        let kept = try kept(around: dated)
        let keptDuties = kept.experience.compactMap(\.description)
        let keptTools = kept.skills.filter { $0.kind != .softSkill }.map(\.name)
        let keptQualities = kept.skills.filter { $0.kind == .softSkill }.map(\.name)
        let endedDuties = kept.experience.filter { !$0.current && $0.endDate.presentValue != nil }.compactMap(\.description)
        // A sentence names the work by a title, the field, a kept duty or a kept tool (#354, round 13, O1).
        let work = keptDuties + keptTools + [field].compactMap { $0?.presentValue }
        var brief = brief
        // A job ends by the years its own request read, which the extraction may have left out (#354, round 10).
        let isDated = kept.experience.count == brief.roles.count
        if isDated {
            for (number, job) in kept.experience.enumerated() where !job.current && job.endDate.presentValue != nil {
                brief.roles[number].hasEnded = true
            }
        }
        brief.opening = try? sanitizer.summaryOpening(of: dated, against: description)
        let order = isDated ? Self.latestFirst(kept.experience) : Array(brief.roles.indices)
        let jobDuties = (isDated ? kept.experience.map(\.description) : duties).map { SentenceSplitter.sentences(in: $0 ?? "") }
        // The typical duties each job keeps: the sentences its own request wrote, not the person's (#354, round 15).
        let typical = jobDuties.indices.map { number -> [String] in
            let written = DescriptionText.normalized(duties.indices.contains(number) ? duties[number] ?? "" : "")
            return written.isEmpty ? [] : jobDuties[number].filter { written.contains(DescriptionText.normalized($0)) }
        }
        let rankedTools = Self.specificFirst(keptTools, language: sanitizer.language(of: description))
        var topics = Self.summaryTopics(
            of: brief, duties: jobDuties, typical: typical, qualities: keptQualities, field: field, order: order,
            tools: rankedTools, studies: Self.studies(of: kept), languages: kept.languages.map(\.name), hasOpening: brief.opening != nil
        )[...]
        var lead = brief.opening
        var accepted: [String] = []
        var asked = 0

        // The sentences the check keeps after the opening, of the summary so far and `answer`; nil when it keeps nothing new to read.
        func checked(_ answer: String?) -> CVDataSanitizer.SummaryVerdict? {
            guard let answer = answer?.presentValue else { return nil }
            let text = ((lead.map { [$0] } ?? []) + accepted + SentenceSplitter.sentences(in: Self.mended(answer)))
                .prefix(Self.summarySentences).joined(separator: " ")
            return try? sanitizer.summaryCheck(
                of: dated, summary: text, field: field, work: work, duties: keptDuties, qualities: keptQualities,
                tools: keptTools, endedDuties: endedDuties, against: description
            )
        }
        func following(_ verdict: CVDataSanitizer.SummaryVerdict) -> [String] {
            let opening = lead ?? verdict.opening
            return Array(verdict.kept.filter { $0 != opening && $0 != verdict.opening }.prefix(Self.summarySentences - 1))
        }
        // `verdict`, of a rich draft (`DraftDepth`), without a new sentence that says an earlier one of the summary again
        // (`CVDataSanitizer.repeats`), which then leads its rejections (#354, round 17): a third sentence wrote the second again
        // with "avec bienveillance" added.
        func withoutRepeats(_ verdict: CVDataSanitizer.SummaryVerdict?) -> CVDataSanitizer.SummaryVerdict? {
            guard var verdict, DraftDepth.isRich else { return verdict }
            var earlier = [lead ?? verdict.opening].compactMap { $0 } + accepted
            var repeats: [String] = []
            for sentence in following(verdict) where !accepted.contains(sentence) {
                if CVDataSanitizer.repeats(sentence, earlier: earlier, besides: keptQualities) {
                    repeats.append(sentence)
                } else {
                    earlier.append(sentence)
                }
            }
            verdict.kept.removeAll(where: repeats.contains)
            verdict.rejected.insert(contentsOf: repeats.map { .init(sentence: $0, reason: Self.repeatsReason) }, at: 0)
            return verdict
        }

        while asked < Self.summaryRequests, accepted.count < Self.summarySentences - 1,
              var topic = Self.nextTopic(of: &topics, isEnough: Self.isEnough(lead, accepted)) {
            let written = (lead.map { [$0] } ?? []) + accepted
            // A tools slot of a rich draft asks the tools the summary does not name yet, and none when it names them all.
            if DraftDepth.isRich {
                guard let unsaid = Self.unsaid(topic, tools: rankedTools, written: written) else { continue }
                topic = unsaid
            }
            asked += 1
            let answer = try await request(.summary) { [brief] in
                try await self.service.writeSummarySentence(for: brief, topic: topic, written: written)
            }
            var verdict = withoutRepeats(checked(answer))
            // The studies slot, which a summary long enough still asks, gets its repair too (probe round 23).
            if let first = verdict, let rejection = first.rejected.first, asked < Self.summaryRequests,
               topic.isOfStudies || !Self.isEnough(lead ?? first.opening, following(first)) {
                asked += 1
                let repaired = try await request(.summary) { [brief] in
                    try await self.service.repairSummarySentence(
                        for: brief, topic: topic, written: written, rejected: Self.quoted(rejection)
                    )
                }
                if let second = withoutRepeats(checked(repaired)), following(second).count >= following(first).count {
                    verdict = second
                }
            }
            // A request that wrote nothing the check reads leaves the summary as it was.
            guard let verdict else { continue }
            if lead == nil { lead = verdict.opening }
            accepted = following(verdict)
            summary = ((lead.map { [$0] } ?? []) + accepted).joined(separator: " ").presentValue
        }
    }

    /// The slots of the summary's sentences, in the order they are asked (#354, round 13, O1): the current job's title with the
    /// field; the topics of its work (`workTopics`); its title with the first two `qualities`; then the first kept duty of each
    /// ended job, latest first by `order`. With no current job, the latest one stands for it. A job with no title reads the
    /// headline title. A rich draft (`DraftDepth`; probe rounds 3 and 4) also asks of the first three kept `tools`, after the
    /// first work slot, with the second pair of work in the first qualities slot (else a topic of the job's work no slot asks;
    /// probe round 15), then of the latest ended job, with the first topic of its work no earlier slot asks (probe round 14), then
    /// of the person's `studies` and `languages` (probe round 21), then of the current job's next work, of two topics of its work
    /// no slot asks, of its next tools and qualities, and of the other ended jobs; its title is said by the opening when there is
    /// one, so its slot then comes last and only with a field, and the field is asked only of a job with no title, as a few words of
    /// a trade (`cleanField`).
    static func summaryTopics(
        of brief: DraftBrief, duties: [[String]], typical: [[String]], qualities: [String], field: String?, order: [Int],
        tools: [String] = [], studies: [SummaryStudy] = [], languages: [String] = [], hasOpening: Bool = false
    ) -> [SummaryTopic] {
        let roles = order.filter(brief.roles.indices.contains)
        guard let current = currentJob(of: brief, order: order) else {
            return qualities.isEmpty ? [] : [SummaryTopic(title: brief.headline, qualities: Array(qualities.prefix(2)), hasEnded: false)]
        }
        let title = { (number: Int) in brief.roles[number].title.presentValue ?? brief.headline }
        let kept = { (number: Int) in duties.indices.contains(number) ? duties[number] : [] }
        let hasEnded = brief.roles[current].hasEnded
        let work = workTopics(of: brief, current: current, duties: duties, typical: typical)
        let qualitiesSlot = { (qualities: ArraySlice<String>) in
            SummaryTopic(title: title(current), qualities: Array(qualities), hasEnded: hasEnded)
        }
        let ended = roles.filter { $0 != current }.compactMap { number -> SummaryTopic? in
            let work = CVDataSanitizer.workTopics(of: kept(number).first ?? "", limit: 1)
            return work.isEmpty ? nil : SummaryTopic(title: title(number), work: work, hasEnded: brief.roles[number].hasEnded)
        }
        guard DraftDepth.isRich else {
            let role = SummaryTopic(title: title(current), field: field?.presentValue, hasEnded: hasEnded)
            return [role] + work.prefix(1) + (qualities.isEmpty ? [] : [qualitiesSlot(qualities.prefix(2))]) + ended
        }
        // The field only for a job with no title, and only as a few words of a trade: a clause of the description fed as the
        // field ("Ich kenne mich mit KNX aus") came back as a sentence on it (#354, probe round 3).
        let field = brief.roles[current].title.presentValue == nil ? cleanField(field) : nil
        let role = SummaryTopic(title: title(current), field: field, hasEnded: hasEnded)
        let toolsSlot = { (tools: ArraySlice<String>) in SummaryTopic(title: title(current), tools: Array(tools), hasEnded: hasEnded) }
        var topics = hasOpening ? [] : [role]
        topics += work.prefix(1)
        if !tools.isEmpty { topics.append(toolsSlot(tools.prefix(3))) }
        var asked = work.flatMap(\.work)
        let own = ((typical.indices.contains(current) ? typical[current] : []) + kept(current)).flatMap { CVDataSanitizer.workTopics(of: $0) }
        // The first qualities slot with the second pair of work (probe rounds 10 and 15): with no work of its own, its sentence said
        // again a duty an earlier sentence had said, and the check rejected it as a repeat; after the third pair, it came once the
        // summary had enough. With no second pair, it takes the first topic of the job's work that no slot asks (probe round 14):
        // with four typical duties, its sentence said the first pair again.
        if !qualities.isEmpty {
            let paired = work.dropFirst().first?.work ?? Array(unused(own, besides: asked).prefix(1))
            asked += paired
            topics.append(SummaryTopic(title: title(current), work: paired, qualities: Array(qualities.prefix(2)), hasEnded: hasEnded))
        } else {
            topics += work.dropFirst().prefix(1)
        }
        // Each ended job with the first topic of its work that no earlier slot asks, else its first (probe round 14): the first
        // duty of an ended job said the work of the current one, and its sentence was rejected as a repeat. The latest comes
        // next (probe round 15): after all the current job's work, it came once the summary had enough, and the career went unsaid.
        var endedSlots: [SummaryTopic] = []
        for number in roles where number != current {
            let ownEnded = kept(number).flatMap { CVDataSanitizer.workTopics(of: $0) }
            guard let topic = unused(ownEnded, besides: asked).first ?? ownEnded.first else { continue }
            asked.append(topic)
            endedSlots.append(SummaryTopic(title: title(number), work: [topic], hasEnded: brief.roles[number].hasEnded))
        }
        topics += endedSlots.prefix(1)
        // The person's studies and languages after the career (probe round 21, O1): told never to name a school, a study or a
        // language, the summary left out what the person wrote of them.
        if DraftDepth.isRich, !studies.isEmpty || !languages.isEmpty {
            topics.append(SummaryTopic(title: title(current), studies: studies, languages: languages, hasEnded: hasEnded))
        }
        // The slots for a summary still short (probe round 4): with a slot rejected, the summary of a short description stopped at
        // 2 sentences. Two topics of the job's work that no slot asks have one of their own (probe round 15): the typical duties
        // held work no sentence said.
        topics += work.dropFirst(2)
        let spare = unused(own, besides: asked).prefix(2)
        if !spare.isEmpty { topics.append(SummaryTopic(title: title(current), work: Array(spare), hasEnded: hasEnded)) }
        if tools.count > 3 { topics.append(toolsSlot(tools.dropFirst(3).prefix(3))) }
        if qualities.count > 2 { topics.append(qualitiesSlot(qualities.dropFirst(2).prefix(2))) }
        topics += endedSlots.dropFirst()
        // The role last, with the opening too (probe round 17): a summary still short then has one more slot, of the title alone
        // when it has no field.
        if hasOpening { topics.append(role) }
        return topics
    }

    /// Each study of `facts` as its degree and school, for the summary's studies slot (#354, probe round 21); a study with neither
    /// is left out.
    static func studies(of facts: CVData) -> [SummaryStudy] {
        facts.education.compactMap { entry in
            let study = SummaryStudy(course: entry.degree.presentValue, school: entry.institution.presentValue)
            return study.course == nil && study.school == nil ? nil : study
        }
    }

    /// The `topics` that say something `asked` does not, each once (#354, probe round 14): a topic all of whose content words, as
    /// `CVDataSanitizer.repeats` compares them, an earlier one has is asked already ("delle comunicazioni ufficiali" after "le
    /// comunicazioni ufficiali").
    static func unused(_ topics: [String], besides asked: [String]) -> [String] {
        var said = Set(asked.flatMap { CVDataSanitizer.contentStems(of: $0) })
        return topics.filter { topic in
            let stems = CVDataSanitizer.contentStems(of: topic)
            guard !stems.isEmpty, !stems.isSubset(of: said) else { return false }
            said.formUnion(stems)
            return true
        }
    }

    /// `field` when it reads as a few words of a trade: at most four words of letters, spaces and hyphens, as the summary check
    /// reads it.
    static func cleanField(_ field: String?) -> String? {
        guard let field = field?.presentValue else { return nil }
        return field.split(separator: " ").count <= 4 && field.allSatisfy { $0.isLetter || $0 == " " || $0 == "-" } ? field : nil
    }

    /// `tools` with those that name a product, a standard or a system first (probe round 4): a word with a digit or two capitals
    /// ("HACCP", "KNX-Systeme", "Excel 365"), then a capitalized one but in German, whose nouns all are, then the others, and last
    /// a field of the work, whose last word ends as an abstract noun does (`fieldEndings`: "Facturación", "manutenzione"), each
    /// group in its order. The tools slot asked of "il frigorifero" and "il forno" wrote a sentence any job could hold; asked of
    /// "Facturación", it said a duty again and was rejected as a repeat (probe round 13).
    static func specificFirst(_ tools: [String], language: String?) -> [String] {
        func rank(_ tool: String) -> Int {
            let letters = Array(tool)
            let isNamed = tool.contains(where: \.isNumber)
                || zip(letters, letters.dropFirst()).contains { $0.isUppercase && $1.isUppercase }
            if isNamed { return 0 }
            if let last = Word.words(in: tool).last?.accented, fieldEndings.contains(where: last.hasSuffix) { return 3 }
            return language != "de" && tool.first?.isUppercase == true ? 1 : 2
        }
        return tools.enumerated().sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }.map(\.element)
    }

    /// The endings of the abstract nouns that name a field of the work rather than a tool, in the six languages, with their
    /// accents: "matita" does not end as "contabilità" does.
    static let fieldEndings = [
        "ción", "sión", "dad", "zione", "sione", "ità", "tion", "sion", "ity", "ité", "ção", "são", "dade", "ung", "keit", "heit",
    ]

    /// `topic` of a rich draft, a tools slot with the first of `tools` that the summary `written` does not name yet, as many as the
    /// slot holds, and nil when it names them all; another slot as it is (probe round 13). A work slot named the tools, and the
    /// tools slots after it said them again and were rejected as repeats, which shortened the summary.
    static func unsaid(_ topic: SummaryTopic, tools: [String], written: [String]) -> SummaryTopic? {
        guard !topic.tools.isEmpty, topic.work.isEmpty, topic.qualities.isEmpty else { return topic }
        let text = DescriptionText.normalized(written.joined(separator: " "))
        let unsaid = tools.filter { DescriptionText.spans(of: DescriptionText.normalized($0), in: text).isEmpty }
        guard !unsaid.isEmpty else { return nil }
        return SummaryTopic(
            title: topic.title, field: topic.field, tools: Array(unsaid.prefix(topic.tools.count)), hasEnded: topic.hasEnded
        )
    }

    /// The job the summary speaks of first: the first one of `order` that goes on, else the latest.
    static func currentJob(of brief: DraftBrief, order: [Int]) -> Int? {
        let roles = order.filter(brief.roles.indices.contains)
        return roles.first(where: { !brief.roles[$0].hasEnded }) ?? roles.first
    }

    /// The slots of the `current` job's work: the topics of its first two `typical` duties, those its own request wrote (#354,
    /// round 15), and of a rich draft the next two pairs (`DraftDepth`; probe rounds 3 and 4). The duties the person said are already in the
    /// job, and a sentence on them said one again; they stand for the work only when the job has no typical duty. Empty when its
    /// kept `duties` have no topic.
    static func workTopics(of brief: DraftBrief, current: Int, duties: [[String]], typical: [[String]]) -> [SummaryTopic] {
        let own = typical.indices.contains(current) ? typical[current] : []
        let kept = own.isEmpty ? (duties.indices.contains(current) ? duties[current] : []) : own
        let title = brief.roles[current].title.presentValue ?? brief.headline
        let pairs = DraftDepth.isRich
            ? [kept.prefix(2), kept.dropFirst(2).prefix(2), kept.dropFirst(4).prefix(2)] : [kept.prefix(2)]
        return pairs.compactMap { pair in
            let work = CVDataSanitizer.workTopics(of: pair.joined(separator: " "), limit: 2)
            return work.isEmpty ? nil : SummaryTopic(title: title, work: work, hasEnded: brief.roles[current].hasEnded)
        }
    }

    /// The numbers of `jobs`, the latest first: the current ones, then by end and start, the earlier in the draft first on a tie.
    static func latestFirst(_ jobs: [Experience]) -> [Int] {
        func key(_ job: Experience) -> (Int, String, String) {
            let isOver = !job.current && job.endDate.presentValue != nil
            return (isOver ? 0 : 1, job.endDate.presentValue ?? "", job.startDate.presentValue ?? "")
        }
        return jobs.indices.sorted { left, right in
            let (one, other) = (key(jobs[left]), key(jobs[right]))
            return one == other ? left < right : one > other
        }
    }

    /// The next slot of `topics` to ask: the first one until the summary `isEnough`; then, in a rich draft (`DraftDepth`), the
    /// studies slot if it is still to ask, and no slot after it (probe round 23). The slot came after a summary long enough in 4
    /// inputs of 9, which then never named the person's studies and languages.
    static func nextTopic(of topics: inout ArraySlice<SummaryTopic>, isEnough: Bool) -> SummaryTopic? {
        guard isEnough else { return topics.popFirst() }
        guard DraftDepth.isRich, let studies = topics.first(where: \.isOfStudies) else { return nil }
        topics.removeAll()
        return studies
    }

    /// Whether `opening` and the sentences `accepted` after it are a summary long enough to ask no more.
    private static func isEnough(_ opening: String?, _ accepted: [String]) -> Bool {
        let sentences = (opening.map { [$0] } ?? []) + accepted
        return sentences.count >= summaryEnough.sentences && sentences.joined(separator: " ").count >= summaryEnough.characters
    }

    /// `text` as a request wrote it, with each semicolon the person's own clause follows as a full stop and each German separable
    /// verb written apart at the end of a subordinate clause joined (#354, round 4), each sentence without the relative word it opens
    /// with and each verb without the noun of its own action (#354, round 12): the checks then read the sentences the draft keeps.
    static func mended(_ text: String) -> String {
        OwnActionNoun.dropped(in: SeparableVerbs.joined(in: CVDataSanitizer.withoutRelativeOpenings(SentenceSplitter.unchained(text))))
    }

    // MARK: - Requests

    /// A rejected sentence as a repair request reads it: the sentence in quotes, then why it went.
    private static func quoted(_ rejection: CVDataSanitizer.Rejection) -> String {
        "\"\(rejection.sentence)\": \(rejection.reason)"
    }

    /// One request of `step`, within its time and tried once more when it fails below the model: nil when it fails or runs out of
    /// time for the first time, once the log says so.
    /// - Throws: `Stopped` when it is the second to fail or run out of time, once the log says so; CancellationError when the task
    ///   was cancelled.
    private func request<Value: Sendable>(
        _ step: DraftStep, _ work: @escaping @Sendable @MainActor () async throws -> Value?
    ) async throws -> Value? {
        do {
            return try await DraftAttempt.run(within: limit, retried: { self.log.retried(at: .writing, by: $0) }, work)
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            // A request stopped by a cancellation may report it with an error of its own.
            try Task.checkCancellation()
            log.unwritten(at: step, by: error)
            guard failures == 0 else { throw Stopped() }
            failures += 1
            return nil
        }
    }
}

extension CVData {
    /// The same draft with `experience` as its jobs.
    func with(experience: [Experience]) -> CVData {
        CVData(
            personalInfo: personalInfo, summary: summary, experience: experience, education: education,
            skills: skills, languages: languages, certifications: certifications, interests: interests
        )
    }

    /// The same draft with `skills` as its skills.
    func with(skills: [Skill]) -> CVData {
        CVData(
            personalInfo: personalInfo, summary: summary, experience: experience, education: education,
            skills: skills, languages: languages, certifications: certifications, interests: interests
        )
    }
}
