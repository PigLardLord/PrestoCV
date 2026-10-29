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

    private let service: any CVGenerationService
    private let sanitizer: CVDataSanitizer
    private let log: DraftLog
    private let limit: Duration
    private let description: String

    /// What the requests wrote so far, as their checks kept it: what the draft keeps when a later request fails.
    private var duties: [String?] = []
    /// The duties the person said for each job, as the check pins them: the summary reads them alone of an ended job.
    private var stated: [[String]] = []
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
        stated = Array(repeating: [], count: brief.roles.count)
        for number in brief.roles.indices where context.jobs.indices.contains(number) {
            let check = try? sanitizer.dutyCheck(of: located, job: context.jobs[number].job, duties: nil, against: description)
            brief.roles[number].avoid = check?.avoid ?? []
            stated[number] = check?.pinned ?? []
            if let check {
                brief.roles[number].said = check.pinned.count
                brief.roles[number].adding = check.saysEnough ? 0 : max(1, 2 - check.pinned.count)
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
            if let floor = try? sanitizer.summaryFloor(of: held, summary: summary, most: Self.summarySentences, against: description) {
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
    /// check keeps fewer than two duties or under 40 characters gets one repair, and what still fails goes. A job whose stated
    /// duties run to 40 characters keeps no typical duty and gets no repair (ADR 0031, D6), and no request when the extraction read
    /// its years. A job keeps only its written duties, no more than it needs: the person's own come back in the final check.
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
            let length = (first.pinned + kept).joined(separator: " ").count
            if !first.saysEnough, length < CVDataSanitizer.DutyVerdicts.describedLength || first.pinned.count + kept.count < 2 {
                let rejected = first.rejected.map(Self.quoted)
                let repaired = try await request(.jobs) { [kept] in
                    try await self.service.repairJob(number: number, of: brief, kept: first.pinned + kept, rejected: rejected)
                }
                if let repaired, let second = try? sanitizer.dutyCheck(
                    of: located, job: job, duties: Self.mended(repaired.joined(separator: " ")), keeping: kept, against: description
                ) {
                    kept += second.kept.prefix(max(adding - kept.count, 1))
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

    /// The tools of each job title, a request each, and the soft skills, cleaned by code against the tools the person names, then
    /// a request for the tools missing and one for the qualities missing, each asking one more, when the final check would keep
    /// fewer than 4 technologies or 3 soft skills (3 and 2 for a single short job); each reads the skills the checks dropped, with
    /// the reason.
    private func writeSkills(of brief: DraftBrief, around dated: CVData) async throws {
        let sparse = brief.roles.count <= 1 && brief.roles.flatMap(\.clauses).joined().count < 80
        let fewestTools = sparse ? 3 : 4
        let groups = Self.toolGroups(of: brief)
        let count = Self.toolCount(groups: groups.count, sparse: sparse)
        var tools: [String] = []
        for roles in groups {
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
        let kept = try kept(around: dated).skills
        let missingTools = max(fewestTools - kept.count { $0.kind == .technology }, 0)
        let missingQualities = max((sparse ? 2 : 3) - kept.count { $0.kind == .softSkill }, 0)
        guard missingTools > 0 || missingQualities > 0 else { return }
        let listedTools = kept.filter { $0.kind != .softSkill }.map(\.name)
        let listedQualities = kept.filter { $0.kind == .softSkill }.map(\.name)
        // One more of each kind short, as the checks may drop one; the answer is cut to the most of each kind.
        let toolsAsked = missingTools > 0 ? missingTools + 1 : 0
        let qualitiesAsked = missingQualities > 0 ? missingQualities + 1 : 0
        let rejected = Self.rejectedSkills(skills.dropped)
        // The tools are asked apart from the qualities: asked together, the tools came back as an activity and a bare record,
        // asked alone as a system of the trade (#354, round 8).
        var moreTools: [String] = []
        var moreQualities: [String] = []
        for (tools, qualities) in [(toolsAsked, 0), (0, qualitiesAsked)] where tools + qualities > 0 {
            let more = try await request(.skills) {
                try await self.service.writeMoreSkills(
                    for: brief, tools: tools, qualities: qualities, listedTools: listedTools, listedQualities: listedQualities,
                    rejected: rejected
                )
            }
            if tools > 0 { moreTools += more?.technologies ?? [] }
            if qualities > 0 { moreQualities += more?.softSkills ?? [] }
        }
        guard !moreTools.isEmpty || !moreQualities.isEmpty else { return }
        skills = sanitizer.skillCheck(
            technologies: skills.technologies + moreTools, softSkills: skills.softSkills + moreQualities, stated: stated,
            names: brief.names, against: description
        )
        keep(skills)
    }

    /// How many tools each title's request asks: a single title asks the fewest the CV needs (4, or 3 for a sparse description)
    /// and one more, as a check may drop one; a title among others asks 2 or 3. One title asked 2 or 3 left the CV short every
    /// time, and the request for those missing named activities and bare kinds (#354, round 6).
    static func toolCount(groups: Int, sparse: Bool) -> ClosedRange<Int> {
        guard groups == 1 else { return 2...3 }
        let fewest = sparse ? 3 : 4
        return fewest...(fewest + 1)
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

    /// The summary, last, from the jobs and the skills the final check keeps. Code writes its opening from the facts and the request
    /// what follows it, from the topics of each job's kept duties (#354, round 3). A summary that keeps a sentence but names no
    /// title, or is too short, gets the opening again; one that drops a sentence or misses something else gets one repair, kept when
    /// it misses no more than the first.
    private func writeSummary(of brief: DraftBrief, field: String?, around dated: CVData) async throws {
        let kept = try kept(around: dated)
        let keptDuties = kept.experience.compactMap(\.description)
        let keptTools = kept.skills.filter { $0.kind != .softSkill }.map(\.name)
        let keptQualities = kept.skills.filter { $0.kind == .softSkill }.map(\.name)
        let endedDuties = kept.experience.filter { !$0.current && $0.endDate.presentValue != nil }.compactMap(\.description)
        // The summary reads only the tools the description states: one the draft wrote came back as the summary's own claim
        // (#354, round 11). The check still reads all the kept ones, for a sentence that lists them.
        let summaryTools = (try? sanitizer.statedTools(keptTools, against: description)) ?? []
        let work = keptDuties + summaryTools
        var brief = brief
        let jobDuties = kept.experience.count == brief.roles.count ? kept.experience.map(\.description) : duties
        // The work of the current jobs, the person's own duties first: an ended job's duties came back in the present as the
        // person's work now (#354, round 10). With no current job, an ended one gives what the person said of it.
        // A job ends by the years its own request read, which the extraction may have left out.
        if kept.experience.count == brief.roles.count {
            for (number, job) in kept.experience.enumerated() where !job.current && job.endDate.presentValue != nil {
                brief.roles[number].hasEnded = true
            }
        }
        let isCurrent = brief.roles.contains { !$0.hasEnded }
        for number in brief.roles.indices where jobDuties.indices.contains(number) {
            let role = brief.roles[number]
            // A current job's work is the topics of the duties the person said, those of its written ones only when the person
            // said none: a written duty came back in the summary as the person's own claim (#354, round 11).
            if !role.hasEnded {
                brief.roles[number].work = CVDataSanitizer.workTopics(stated: stated[number], duties: jobDuties[number])
            } else {
                brief.roles[number].work = isCurrent ? [] : CVDataSanitizer.workTopics(of: stated[number].joined(separator: " "))
            }
        }
        brief.opening = try? sanitizer.summaryOpening(of: dated, against: description)
        let written = try await request(.summary) { [brief] in
            try await self.service.writeSummary(for: brief, tools: summaryTools, qualities: keptQualities)
        }
        // The text mended (`mended`), then the summary cut to its most sentences (#354, round 4).
        let opened = Self.opened(written.map(Self.mended), by: brief.opening)
            .map { SentenceSplitter.sentences(in: $0).prefix(Self.summarySentences).joined(separator: " ") }
        guard let first = try? sanitizer.summaryCheck(
            of: dated, summary: opened, field: field, work: work, duties: keptDuties, qualities: keptQualities,
            tools: keptTools, endedDuties: endedDuties, against: description
        ) else {
            return
        }
        summary = first.text
        let opening = first.kept.isEmpty ? nil : first.opening
        if let opening { summary = Self.joining(opening, first.kept) }
        let problems = first.problems.filter { $0 != first.openingProblem }
        guard !first.rejected.isEmpty || !problems.isEmpty else { return }
        let keptSentences = ((opening.map { [$0] } ?? []) + first.kept).filter { $0 != brief.opening }
        let rejected = first.rejected.map(Self.quoted)
        let repaired = try await request(.summary) { [brief] in
            try await self.service.repairSummary(
                for: brief, tools: summaryTools, qualities: keptQualities, kept: keptSentences, rejected: rejected, problems: problems
            )
        }
        let cut = Self.opened(repaired.map(Self.mended), by: brief.opening)
            .map { SentenceSplitter.sentences(in: $0).prefix(Self.summarySentences).joined(separator: " ") }
        guard let second = try? sanitizer.summaryCheck(
            of: dated, summary: cut, field: field, work: work, duties: keptDuties, qualities: keptQualities,
            tools: keptTools, endedDuties: endedDuties, against: description
        ), second.text != nil, second.problems.count <= first.problems.count || first.text == nil else { return }
        summary = second.opening.map { Self.joining($0, second.kept) } ?? second.text
    }

    /// `text` as a request wrote it, with each semicolon the person's own clause follows as a full stop and each German separable
    /// verb written apart at the end of a subordinate clause joined (#354, round 4), each sentence without the relative word it opens
    /// with and each verb without the noun of its own action (#354, round 12): the checks then read the sentences the draft keeps.
    static func mended(_ text: String) -> String {
        OwnActionNoun.dropped(in: SeparableVerbs.joined(in: CVDataSanitizer.withoutRelativeOpenings(SentenceSplitter.unchained(text))))
    }

    /// The sentences a summary request wrote after `opening`, which code wrote: nil when it wrote none. The check drops a sentence
    /// that says the opening again.
    private static func opened(_ written: String?, by opening: String?) -> String? {
        guard let written = written?.presentValue else { return nil }
        return opening.map { $0 + " " + written } ?? written
    }

    /// The opening, then the kept sentences that are not it, at most four.
    private static func joining(_ opening: String, _ kept: [String]) -> String? {
        ([opening] + kept.filter { $0 != opening }).prefix(summarySentences).joined(separator: " ").presentValue
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
