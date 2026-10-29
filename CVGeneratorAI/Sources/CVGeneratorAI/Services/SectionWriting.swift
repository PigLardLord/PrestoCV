#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// The requests of a draft written a section at a time (ADR 0031, "A request per section"). Each request is a fresh session with its
/// own token cap and greedy decoding; a streamed answer cut by its cap keeps its whole parts, and the part the cut fell in goes.
extension FoundationModelsService {
    // MARK: The token caps

    /// A job's years and 2 to 4 duties.
    nonisolated static let jobTokens = 220
    /// A job's repair: up to 3 duties.
    nonisolated static let jobRepairTokens = 180
    /// 3 to 5 qualities.
    nonisolated static let softSkillsTokens = 100
    /// A summary of 2 to 4 sentences.
    nonisolated static let summaryTokens = 220
    /// The summary's repair: four sentences of a summary, not a page.
    nonisolated static let summaryRepairTokens = 140
    /// The longest summary a repair keeps, in sentences: a repair that runs on is cut, not thrown away.
    nonisolated static let summaryRepairSentences = 4

    /// The tools' cap grows with the jobs: an entry of 2 or 3 tools for each.
    nonisolated static func toolsTokens(jobs: Int) -> Int { 60 + 40 * jobs }

    /// The cap of a request for `count` more skills.
    nonisolated static func moreSkillsTokens(count: Int) -> Int { 40 + 12 * count }

    // MARK: The jobs

    public func writeJob(number: Int, of brief: DraftBrief) async throws -> RoleWriting? {
        guard let last = try await streamed(SectionPrompts.job(number: number, of: brief), JobAnswer.self, tokens: Self.jobTokens) else {
            return nil
        }
        let content = last.answer.content
        let duties = Self.whole(content.duties, isComplete: last.isComplete)
        return RoleWriting(
            startDate: content.startYear?.presentValue, endDate: content.endYear?.presentValue,
            duties: duties.map(Self.sentence).joined(separator: " ").presentValue
        )
    }

    public func repairJob(number: Int, of brief: DraftBrief, kept: [String], rejected: [String]) async throws -> [String]? {
        let prompt = SectionPrompts.jobRepair(number: number, of: brief, kept: kept, rejected: rejected)
        guard let last = try await streamed(prompt, JobRepairAnswer.self, tokens: Self.jobRepairTokens) else { return nil }
        return Self.whole(last.answer.content.duties, isComplete: last.isComplete).map(Self.sentence)
    }

    // MARK: The skills

    public func writeTools(for brief: DraftBrief) async throws -> [[String]]? {
        let count = brief.roles.count
        guard count > 0 else { return nil }
        let answer = try await respond(
            SectionPrompts.tools(for: brief), schema: try Self.toolsSchema(count: count), tokens: Self.toolsTokens(jobs: count)
        )
        guard let jobs = try? answer.value([GeneratedContent].self, forProperty: "jobs") else { return nil }
        return jobs.map { Self.clean(try? $0.value([String].self, forProperty: "tools")) }
    }

    /// One entry of up to 3 tools for each of `count` jobs, in order, none for a job when none fits; the entry's type is a
    /// dependency the array refers to.
    nonisolated static func toolsSchema(count: Int) throws -> GenerationSchema {
        let job = DynamicGenerationSchema(name: "JobTools", properties: [
            DynamicGenerationSchema.Property(
                name: "job", description: "The job's title", schema: DynamicGenerationSchema(type: String.self)
            ),
            DynamicGenerationSchema.Property(
                name: "tools",
                description: "Up to 3 pieces of equipment, machines or software of the job, first those its lines name; none when none fits",
                schema: DynamicGenerationSchema(arrayOf: DynamicGenerationSchema(type: String.self), minimumElements: 0, maximumElements: 3)
            ),
        ])
        let root = DynamicGenerationSchema(name: "Tools", properties: [
            DynamicGenerationSchema.Property(
                name: "jobs", description: "One entry for each job, in order",
                schema: DynamicGenerationSchema(
                    arrayOf: DynamicGenerationSchema(referenceTo: "JobTools"), minimumElements: count, maximumElements: count
                )
            ),
        ])
        return try GenerationSchema(root: root, dependencies: [job])
    }

    public func writeSoftSkills(for brief: DraftBrief) async throws -> [String]? {
        let prompt = SectionPrompts.softSkills(for: brief)
        guard let last = try await streamed(prompt, QualitiesAnswer.self, tokens: Self.softSkillsTokens) else { return nil }
        return Self.whole(last.answer.content.qualities, isComplete: last.isComplete)
    }

    public func writeMoreSkills(
        for brief: DraftBrief, tools: Int, qualities: Int, excluding kept: [String], rejected: [String]
    ) async throws -> DraftWriting? {
        let list = { (name: String, about: String, count: Int) in
            DynamicGenerationSchema.Property(
                name: name, description: about,
                schema: DynamicGenerationSchema(
                    arrayOf: DynamicGenerationSchema(type: String.self), minimumElements: count, maximumElements: count
                )
            )
        }
        var properties: [DynamicGenerationSchema.Property] = []
        if tools > 0 {
            let about = "\(tools) more pieces of equipment, machines or software of the trade, each of another kind; no activity, no material or part"
            properties.append(list("tools", about, tools))
        }
        if qualities > 0 { properties.append(list("qualities", "\(qualities) more personal qualities at work", qualities)) }
        guard !properties.isEmpty else { return nil }
        let schema = try GenerationSchema(root: DynamicGenerationSchema(name: "MoreSkills", properties: properties), dependencies: [])
        let prompt = SectionPrompts.moreSkills(for: brief, tools: tools, qualities: qualities, excluding: kept, rejected: rejected)
        let answer = try await respond(prompt, schema: schema, tokens: Self.moreSkillsTokens(count: tools + qualities))
        return DraftWriting(
            summary: nil, roleDescriptions: [],
            technologies: tools > 0 ? Self.clean(try? answer.value([String].self, forProperty: "tools")) : [],
            softSkills: qualities > 0 ? Self.clean(try? answer.value([String].self, forProperty: "qualities")) : []
        )
    }

    // MARK: The summary

    public func writeSummary(for brief: DraftBrief, duties: [String?], skills: [String]) async throws -> String? {
        let prompt = SectionPrompts.summary(for: brief, duties: duties, skills: skills)
        guard let last = try await streamed(prompt, SummaryAnswer.self, tokens: Self.summaryTokens),
              let summary = last.answer.content.summary else { return nil }
        return last.isComplete ? summary.presentValue : Self.wholeSentences(of: summary)
    }

    public func repairSummary(
        for brief: DraftBrief, duties: [String?], skills: [String], kept: [String], rejected: [String], problems: [String]
    ) async throws -> String? {
        let prompt = SectionPrompts.summaryRepair(
            for: brief, duties: duties, skills: skills, kept: kept, rejected: rejected, problems: problems
        )
        guard let last = try await streamed(prompt, SummaryAnswer.self, tokens: Self.summaryRepairTokens),
              let summary = last.answer.content.summary,
              let whole = last.isComplete ? summary.presentValue : Self.wholeSentences(of: summary) else { return nil }
        return SentenceSplitter.sentences(in: whole).prefix(Self.summaryRepairSentences).joined(separator: " ").presentValue
    }

    // MARK: A request

    private func respond(_ prompt: SectionPrompts.Prompt, schema: GenerationSchema, tokens: Int) async throws -> GeneratedContent {
        let session = LanguageModelSession(instructions: prompt.instructions)
        do {
            return try await session.respond(
                to: prompt.text, schema: schema, includeSchemaInPrompt: true,
                options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: tokens)
            ).content
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw Self.map(failure: error)
        }
    }

    private func streamed<Answer: Generable>(
        _ prompt: SectionPrompts.Prompt, _ type: Answer.Type, tokens: Int
    ) async throws -> StreamedAnswer.Last<LanguageModelSession.ResponseStream<Answer>.Snapshot>? {
        let session = LanguageModelSession(instructions: prompt.instructions)
        do {
            let stream = session.streamResponse(
                to: prompt.text, generating: type, includeSchemaInPrompt: true,
                options: GenerationOptions(samplingMode: .greedy, maximumResponseTokens: tokens)
            )
            return try await StreamedAnswer.last(of: stream, keepingPartialAfter: Self.leavesAnAnswer(failure:))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw Self.map(failure: error)
        }
    }

    // MARK: The parts of an answer

    /// The values written, trimmed, without the last one when the answer was cut while writing it.
    nonisolated private static func whole(_ values: [String]?, isComplete: Bool) -> [String] {
        let present = clean(values)
        return isComplete ? present : Array(present.dropLast())
    }

    nonisolated private static func clean(_ values: [String]?) -> [String] {
        (values ?? []).compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).presentValue }
    }

    nonisolated private static func sentence(_ text: String) -> String {
        guard let last = text.last, !".!?…".contains(last) else { return text }
        return text + "."
    }

    nonisolated private static func wholeSentences(of text: String) -> String? {
        guard let end = text.lastIndex(where: { ".!?…".contains($0) }) else { return nil }
        return String(text[...end]).trimmingCharacters(in: .whitespacesAndNewlines).presentValue
    }
}

@Generable
struct JobAnswer {
    @Guide(description: "The year the person started this job, as they wrote it; null if they did not say it")
    let startYear: String?

    @Guide(description: "The year the person left this job, as they wrote it; null if they did not say it or still work there")
    let endYear: String?

    @Guide(description: "The duties of the job, one short whole sentence each", .count(2...4))
    let duties: [String]
}

@Generable
struct JobRepairAnswer {
    @Guide(description: "The rejected sentences written again and the duty asked for, one short whole sentence each", .count(1...3))
    let duties: [String]
}

@Generable
struct QualitiesAnswer {
    @Guide(description: "Personal qualities at work, as nouns", .count(3...5))
    let qualities: [String]
}

@Generable
struct SummaryAnswer {
    @Guide(description: "2 to 4 sentences on the person's profession and strengths")
    let summary: String
}
#endif
