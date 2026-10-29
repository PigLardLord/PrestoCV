import Foundation

/// The draft written around the facts a section at a time (ADR 0031, "A request per section"). Code gives each job the clauses of
/// the description that belong to it; then a request per job writes its years and duties, a request the tools of each job and one
/// the soft skills, and a last request the summary from the jobs and skills kept. Each answer is checked by the rules of the final
/// check inside its step, and a step whose check finds too little gets one repair request that reads what it rejected and why.
///
/// A request that fails or runs out of time stops the writing: the draft keeps the facts and what the earlier requests wrote, and the
/// log says at which step. Cancellation passes through. One instance writes one draft.
@MainActor
final class SectionDraft {
    /// The jobs a draft writes duties for, in its order: a longer career gets no request for its oldest jobs.
    static let writtenJobs = 10
    /// The most technologies and soft skills a draft keeps.
    static let technologies = 8
    static let softSkills = 5
    /// The most sentences a summary keeps.
    static let summarySentences = 4
    /// The most requests the summary makes, a sentence or its repair each (#354, round 13).
    static let summaryRequests = 4
    /// A summary of this many sentences and characters asks no more (#354, round 13).
    static let summaryEnough = (sentences: 2, characters: 120)

    private let service: any CVGenerationService
    private let sanitizer: CVDataSanitizer
    private let log: DraftLog
    private let limit: Duration
    private let description: String

    /// What the requests wrote so far, as their checks kept it: what the draft keeps when a later request fails.
    private var duties: [String?] = []
    private var years: [Int: RoleWriting] = [:]
    private var technologies: [String] = []
    private var softSkills: [String] = []
    private var summary: String?

    /// A request failed or ran out of time, and the log says so: the writing stops there.
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
                brief.roles[number].adding = DraftBrief.Role.adding(said: check.pinned.count)
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
            let role = try await request(.jobs) { try await self.service.writeJob(number: number, of: brief) }
            if let role { years[number] = role }
            guard context.jobs.indices.contains(number) else { continue }
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

    /// The tools of each job title, a request each, the headline's first, and the soft skills, cleaned by code against the tools
    /// the person names (#354, round 13, O1). The headline's title asks 6 to 8 tools and each other title 1: each title
    /// asked 2 or 3, and the past titles of another trade filled the CV with tools of no trade of the person's. When the final
    /// check would keep fewer than 4 technologies (3 for a single short job), the headline's title is asked for up to 2 tools of
    /// one kind at a time, software, then devices, then instruments, until the CV has enough; and with fewer than 3 soft skills
    /// (2), one request asks the qualities missing and one more, reading the qualities kept and those the checks dropped, with the
    /// reason. A tools request reads no tool kept: shown them, it named them again.
    private func writeSkills(of brief: DraftBrief, around dated: CVData) async throws {
        let sparse = brief.roles.count <= 1 && brief.roles.flatMap(\.clauses).joined().count < 80
        let fewestTools = sparse ? 3 : 4
        let groups = Self.toolGroups(of: brief)
        let latest = dated.experience.count == brief.roles.count ? Self.latestFirst(dated.experience).first : nil
        let headline = Self.headlineGroup(of: groups, brief: brief, latest: latest)
        let headlineRoles = groups.indices.contains(headline) ? groups[headline] : []
        let others = groups.enumerated().filter { $0.offset != headline }.map(\.element)
        var tools: [String] = []
        for (index, roles) in ((headlineRoles.isEmpty ? [] : [headlineRoles]) + others).enumerated() {
            let count = Self.toolCount(isHeadline: index == 0)
            tools += try await request(.skills) { try await self.service.writeTools(for: brief, roles: roles, count: count) } ?? []
        }
        let qualities = try await request(.skills) { try await self.service.writeSoftSkills(for: brief) }
        let stated = dated.skills.filter { $0.kind != .softSkill }.map(\.name)
        // ADR 0031, D8: the work the person says they like doing is a soft skill in their own words, before those written.
        let liked = CVDataSanitizer.workLikings(in: description)
        var skills = sanitizer.skillCheck(
            technologies: tools, softSkills: liked + (qualities ?? []), stated: stated,
            names: brief.names, against: description
        )
        keep(skills)
        for kind in ToolKind.allCases {
            let kept = try kept(around: dated).skills
            guard kept.count(where: { $0.kind == .technology }) < fewestTools else { break }
            let more = try await request(.skills) {
                try await self.service.writeToolsOfAKind(for: brief, roles: headlineRoles, kind: kind)
            } ?? []
            guard !more.isEmpty else { continue }
            skills = sanitizer.skillCheck(
                technologies: skills.technologies + more, softSkills: skills.softSkills, stated: stated, names: brief.names,
                against: description
            )
            keep(skills)
        }
        let kept = try kept(around: dated).skills
        let missingQualities = max((sparse ? 2 : 3) - kept.count { $0.kind == .softSkill }, 0)
        guard missingQualities > 0 else { return }
        // One more than missing, as the checks may drop one; the answer is cut to the most.
        let listed = kept.filter { $0.kind == .softSkill }.map(\.name)
        let rejected = Self.rejectedSkills(skills.dropped)
        let more = try await request(.skills) {
            try await self.service.writeMoreQualities(for: brief, count: missingQualities + 1, listed: listed, rejected: rejected)
        } ?? []
        guard !more.isEmpty else { return }
        skills = sanitizer.skillCheck(
            technologies: skills.technologies, softSkills: skills.softSkills + more, stated: stated, names: brief.names,
            against: description
        )
        keep(skills)
    }

    /// How many tools a title's request asks: 6 to 8 for the headline's, 1 for another, often of another trade, which the checks
    /// may drop (#354, round 13, O1, T1). Not "0 to 1": the model fails an array of 0 to 1 before a word (ModelManagerError 1032),
    /// and every draft with a second title lost its writing.
    nonisolated static func toolCount(isHeadline: Bool) -> ClosedRange<Int> {
        isHeadline ? 6...8 : 1...1
    }

    /// The group of `groups` of the headline's title: the one whose job holds the headline, or has no title and so reads it; else
    /// the one of the `latest` job; else the first (#354, round 13, O1).
    static func headlineGroup(of groups: [[Int]], brief: DraftBrief, latest: Int?) -> Int {
        let titles = brief.roles.map { $0.title.presentValue?.lowercased() }
        if let headline = brief.headline?.presentValue?.lowercased(), let group = groups.firstIndex(where: { roles in
            roles.contains { brief.roles.indices.contains($0) && (titles[$0] == nil || titles[$0] == headline) }
        }) {
            return group
        }
        if let latest, let group = groups.firstIndex(where: { $0.contains(latest) }) { return group }
        return 0
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
        "a kind of tool, not its name": "a kind of tool, not the name of one",
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
    /// repair with its reason. The requests stop once the summary has 2 sentences and 120 characters, after 4 requests, or when no
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
        var topics = Self.summaryTopics(of: brief, duties: jobDuties, qualities: keptQualities, field: field, order: order)[...]
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

        while asked < Self.summaryRequests, !Self.isEnough(lead, accepted), accepted.count < Self.summarySentences - 1,
              let topic = topics.popFirst() {
            let written = (lead.map { [$0] } ?? []) + accepted
            asked += 1
            let answer = try await request(.summary) { [brief] in
                try await self.service.writeSummarySentence(for: brief, topic: topic, written: written)
            }
            var verdict = checked(answer)
            if let first = verdict, let rejection = first.rejected.first, asked < Self.summaryRequests,
               !Self.isEnough(lead ?? first.opening, following(first)) {
                asked += 1
                let repaired = try await request(.summary) { [brief] in
                    try await self.service.repairSummarySentence(
                        for: brief, topic: topic, written: written, rejected: Self.quoted(rejection)
                    )
                }
                if let second = checked(repaired), following(second).count >= following(first).count { verdict = second }
            }
            // A request that wrote nothing the check reads leaves the summary as it was.
            guard let verdict else { continue }
            if lead == nil { lead = verdict.opening }
            accepted = following(verdict)
            summary = ((lead.map { [$0] } ?? []) + accepted).joined(separator: " ").presentValue
        }
    }

    /// The slots of the summary's sentences, in the order they are asked (#354, round 13, O1): the current job's title and the
    /// `field`; the topics of the first two kept `duties` of the current job; its title with the first two `qualities`; then the
    /// first kept duty of each ended job, latest first by `order`. With no current job, the latest one stands for it. A job with no
    /// title reads the headline title.
    static func summaryTopics(
        of brief: DraftBrief, duties: [[String]], qualities: [String], field: String?, order: [Int]
    ) -> [SummaryTopic] {
        let roles = order.filter(brief.roles.indices.contains)
        guard let current = roles.first(where: { !brief.roles[$0].hasEnded }) ?? roles.first else {
            return qualities.isEmpty ? [] : [SummaryTopic(title: brief.headline, qualities: Array(qualities.prefix(2)), hasEnded: false)]
        }
        let title = { (number: Int) in brief.roles[number].title.presentValue ?? brief.headline }
        let kept = { (number: Int) in duties.indices.contains(number) ? duties[number] : [] }
        let hasEnded = brief.roles[current].hasEnded
        var topics = [SummaryTopic(title: title(current), field: field?.presentValue, hasEnded: hasEnded)]
        let work = CVDataSanitizer.workTopics(of: kept(current).prefix(2).joined(separator: " "), limit: 2)
        if !work.isEmpty { topics.append(SummaryTopic(title: title(current), work: work, hasEnded: hasEnded)) }
        if !qualities.isEmpty {
            topics.append(SummaryTopic(title: title(current), qualities: Array(qualities.prefix(2)), hasEnded: hasEnded))
        }
        for number in roles where number != current {
            let work = CVDataSanitizer.workTopics(of: kept(number).first ?? "", limit: 1)
            if !work.isEmpty { topics.append(SummaryTopic(title: title(number), work: work, hasEnded: brief.roles[number].hasEnded)) }
        }
        return topics
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

    /// One request of `step`, within its time and tried once more when it fails below the model.
    /// - Throws: `Stopped` when it fails or runs out of time, once the log says so; CancellationError when the task was cancelled.
    private func request<Value: Sendable>(
        _ step: DraftStep, _ work: @escaping @Sendable @MainActor () async throws -> Value
    ) async throws -> Value {
        do {
            return try await DraftAttempt.run(within: limit, retried: { self.log.retried(at: .writing, by: $0) }, work)
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            // A request stopped by a cancellation may report it with an error of its own.
            try Task.checkCancellation()
            log.unwritten(at: step, by: error)
            throw Stopped()
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
