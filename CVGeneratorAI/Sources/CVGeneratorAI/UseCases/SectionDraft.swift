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
        for number in brief.roles.indices where context.jobs.indices.contains(number) {
            let check = try? sanitizer.dutyCheck(of: located, job: context.jobs[number].job, duties: nil, against: description)
            brief.roles[number].avoid = check?.avoid ?? []
            brief.roles[number].described = check?.saysEnough ?? false
        }
        duties = Array(repeating: nil, count: brief.roles.count)

        do {
            try await writeJobs(of: brief, context: context, in: located)
            try await writeSkills(of: brief, around: dated(located, context: context))
            try await writeSummary(of: brief, field: context.field, around: dated(located, context: context))
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

    /// A request per job, in order, its duties checked; a job whose check keeps fewer than two duties or under 40 characters gets
    /// one repair, and what still fails goes. A job whose stated duties run to 40 characters keeps no typical duty and gets no
    /// repair (ADR 0031, D6). A job keeps only its written duties: the person's own come back in the final check.
    private func writeJobs(of brief: DraftBrief, context: CVDataSanitizer.DraftContext, in located: CVData) async throws {
        for number in brief.roles.indices.prefix(Self.writtenJobs) {
            let role = try await request(.jobs) { try await self.service.writeJob(number: number, of: brief) }
            if let role { years[number] = role }
            guard context.jobs.indices.contains(number) else { continue }
            let job = context.jobs[number].job
            guard let first = try? sanitizer.dutyCheck(of: located, job: job, duties: role?.duties, against: description) else { continue }
            var kept = first.kept
            let described = CVDataSanitizer.DutyVerdicts.describedLength
            if !first.saysEnough, first.length < described || first.pinned.count + first.kept.count < 2 {
                let rejected = first.rejected.map(Self.quoted)
                let repaired = try await request(.jobs) {
                    try await self.service.repairJob(number: number, of: brief, kept: first.pinned + first.kept, rejected: rejected)
                }
                if let repaired, let second = try? sanitizer.dutyCheck(
                    of: located, job: job, duties: repaired.joined(separator: " "), keeping: first.kept, against: description
                ) {
                    kept += second.kept
                }
            }
            duties[number] = kept.joined(separator: " ").presentValue
        }
    }

    // MARK: - Skills

    /// The tools of each job and the soft skills, cleaned by code, then one request for those missing when the final check would
    /// keep fewer than 4 technologies or 3 soft skills (3 and 2 for a single short job).
    private func writeSkills(of brief: DraftBrief, around dated: CVData) async throws {
        let tools = try await request(.skills) { try await self.service.writeTools(for: brief) }
        let qualities = try await request(.skills) { try await self.service.writeSoftSkills(for: brief) }
        var skills = sanitizer.skillCheck(technologies: (tools ?? []).flatMap { $0 }, softSkills: qualities ?? [], against: description)
        keep(skills)
        let kept = try kept(around: dated).skills
        let sparse = brief.roles.count <= 1 && brief.roles.flatMap(\.clauses).joined().count < 80
        let missingTools = max((sparse ? 3 : 4) - kept.count { $0.kind == .technology }, 0)
        let missingQualities = max((sparse ? 2 : 3) - kept.count { $0.kind == .softSkill }, 0)
        guard missingTools > 0 || missingQualities > 0 else { return }
        let names = kept.map(\.name)
        let more = try await request(.skills) {
            try await self.service.writeMoreSkills(for: brief, tools: missingTools, qualities: missingQualities, excluding: names)
        }
        guard let more else { return }
        skills = sanitizer.skillCheck(
            technologies: skills.technologies + more.technologies, softSkills: skills.softSkills + more.softSkills, against: description
        )
        keep(skills)
    }

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

    /// The summary, last, from the jobs and the skills the final check keeps. A summary that keeps a sentence but names no title,
    /// or is too short, gets an opening code writes from the facts; one that drops a sentence or misses something else gets one
    /// repair, kept when it misses no more than the first.
    private func writeSummary(of brief: DraftBrief, field: String?, around dated: CVData) async throws {
        let kept = try kept(around: dated)
        let keptDuties = kept.experience.map(\.description)
        let keptSkills = kept.skills.map(\.name)
        let work = keptDuties.compactMap { $0 } + technologies
        let written = try await request(.summary) {
            try await self.service.writeSummary(for: brief, duties: keptDuties, skills: keptSkills)
        }
        guard let first = try? sanitizer.summaryCheck(
            of: dated, summary: written, field: field, work: work, duties: keptDuties.compactMap { $0 }, against: description
        ) else {
            return
        }
        summary = first.text
        let opening = first.kept.isEmpty ? nil : first.opening
        if let opening { summary = Self.joining(opening, first.kept) }
        let problems = first.problems.filter { $0 != first.openingProblem }
        guard !first.rejected.isEmpty || !problems.isEmpty else { return }
        let keptSentences = (opening.map { [$0] } ?? []) + first.kept
        let rejected = first.rejected.map(Self.quoted)
        let repaired = try await request(.summary) {
            try await self.service.repairSummary(
                for: brief, duties: keptDuties, skills: keptSkills, kept: keptSentences, rejected: rejected, problems: problems
            )
        }
        let cut = repaired.map { SentenceSplitter.sentences(in: $0).prefix(Self.summarySentences).joined(separator: " ") }
        guard let second = try? sanitizer.summaryCheck(
            of: dated, summary: cut, field: field, work: work, duties: keptDuties.compactMap { $0 }, against: description
        ), second.text != nil, second.problems.count <= first.problems.count || first.text == nil else { return }
        summary = second.opening.map { Self.joining($0, second.kept) } ?? second.text
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
