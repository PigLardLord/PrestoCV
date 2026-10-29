#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// The requests of a draft written a section at a time (ADR 0031, "A request per section"). Each request is a fresh session with its
/// own token cap and greedy decoding; a streamed answer cut by its cap keeps its whole parts, and the part the cut fell in goes.
extension FoundationModelsService {
    // MARK: The token caps

    /// A job's years and 1 to 4 duties.
    nonisolated static let jobTokens = 220
    /// A job's repair: up to 3 duties.
    nonisolated static let jobRepairTokens = 180
    /// 3 to 5 qualities.
    nonisolated static let softSkillsTokens = 100
    /// One sentence of the summary, or its repair: a sentence, not a paragraph (#354, round 13).
    nonisolated static let summarySentenceTokens = 90

    /// The cap of a request for at most `most` tools of one title: 80 for 3.
    nonisolated static func toolsTokens(most: Int) -> Int { 80 + 20 * max(most - 3, 0) }

    /// The cap of a request for `count` more skills.
    nonisolated static func moreSkillsTokens(count: Int) -> Int { 40 + 12 * count }

    // MARK: The jobs

    public func writeJob(number: Int, of brief: DraftBrief) async throws -> RoleWriting? {
        guard brief.roles.indices.contains(number) else { return nil }
        let role = brief.roles[number]
        let schema = try Self.jobSchema(duties: Self.jobDuties(said: role.said, adding: role.adding))
        guard let last = try await streamed(SectionPrompts.job(number: number, of: brief), schema: schema, tokens: Self.jobTokens) else {
            return nil
        }
        let content = last.answer.content
        let duties = Self.whole(try? content.value([String].self, forProperty: "duties"), isComplete: last.isComplete)
        let year = { (name: String) in (try? content.value(String.self, forProperty: name))?.presentValue }
        return RoleWriting(
            startDate: year("startYear"), endDate: year("endYear"),
            duties: duties.map(Self.sentence).joined(separator: " ").presentValue
        )
    }

    /// The duties a job's request writes: the person's own, then the typical ones it needs, 1 to 4 (#354, round 10).
    nonisolated static func jobDuties(said: Int, adding: Int) -> Int { min(4, max(1, said + adding)) }

    /// A job's years and exactly `duties` duties. A range let the model pad: asked for 2 to 4, it wrote 4 for a job that needed one
    /// more, and the extra ones said a duty again with other words (#354, round 10).
    nonisolated static func jobSchema(duties: Int) throws -> GenerationSchema {
        let year = { (name: String, about: String) in
            DynamicGenerationSchema.Property(name: name, description: about, schema: DynamicGenerationSchema(type: String.self), isOptional: true)
        }
        let root = DynamicGenerationSchema(name: "Job", properties: [
            year("startYear", "The year the person started this job, as they wrote it; null if they did not say it"),
            year("endYear", "The year the person left this job, as they wrote it; null if they did not say it or still work there"),
            DynamicGenerationSchema.Property(
                name: "duties",
                description: "\(duties) duties of the job, one short whole sentence each",
                schema: DynamicGenerationSchema(
                    arrayOf: DynamicGenerationSchema(type: String.self), minimumElements: duties, maximumElements: duties
                )
            ),
        ])
        return try GenerationSchema(root: root, dependencies: [])
    }

    public func repairJob(number: Int, of brief: DraftBrief, kept: [String], rejected: [String]) async throws -> [String]? {
        let prompt = SectionPrompts.jobRepair(number: number, of: brief, kept: kept, rejected: rejected)
        guard let last = try await streamed(prompt, JobRepairAnswer.self, tokens: Self.jobRepairTokens) else { return nil }
        return Self.whole(last.answer.content.duties, isComplete: last.isComplete).map(Self.sentence)
    }

    // MARK: The skills

    public func writeTools(for brief: DraftBrief, roles: [Int], count: ClosedRange<Int>) async throws -> [String]? {
        guard !roles.isEmpty, roles.allSatisfy(brief.roles.indices.contains) else { return nil }
        let prompt = SectionPrompts.tools(for: brief, roles: roles, count: count)
        let schema = try Self.toolsSchema(count: count)
        let answer = try await respond(prompt, schema: schema, tokens: Self.toolsTokens(most: count.upperBound))
        return Self.clean(try? answer.value([String].self, forProperty: "tools"))
    }

    /// `count` tools of one title. A job may not go without tools: allowed none, the model answered none for a job with no lines of
    /// its own, and the next request filled the gap with activities and roles (#354, round 5).
    nonisolated static func toolsSchema(count: ClosedRange<Int>) throws -> GenerationSchema {
        let root = DynamicGenerationSchema(name: "Tools", properties: [
            DynamicGenerationSchema.Property(
                name: "tools",
                description: "\(count.lowerBound) or \(count.upperBound) software, equipment, machines or instruments of the job's trade, "
                    + "first those its lines name",
                schema: DynamicGenerationSchema(
                    arrayOf: DynamicGenerationSchema(type: String.self), minimumElements: count.lowerBound, maximumElements: count.upperBound
                )
            ),
        ])
        return try GenerationSchema(root: root, dependencies: [])
    }

    public func writeSoftSkills(for brief: DraftBrief) async throws -> [String]? {
        let prompt = SectionPrompts.softSkills(for: brief)
        guard let last = try await streamed(prompt, QualitiesAnswer.self, tokens: Self.softSkillsTokens) else { return nil }
        return Self.whole(last.answer.content.qualities, isComplete: last.isComplete)
    }

    public func writeMoreSkills(
        for brief: DraftBrief, tools: Int, qualities: Int, listedTools: [String], listedQualities: [String], rejected: [String]
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
            let about = "\(tools) more software, systems, machines or instruments of the trade, each of another kind; no activity, no material or part"
            properties.append(list("tools", about, tools))
        }
        if qualities > 0 { properties.append(list("qualities", "\(qualities) more personal qualities at work, in the language of the CV", qualities)) }
        guard !properties.isEmpty else { return nil }
        let schema = try GenerationSchema(root: DynamicGenerationSchema(name: "MoreSkills", properties: properties), dependencies: [])
        let prompt = SectionPrompts.moreSkills(
            for: brief, tools: tools, qualities: qualities, listedTools: listedTools, listedQualities: listedQualities, rejected: rejected
        )
        let answer = try await respond(prompt, schema: schema, tokens: Self.moreSkillsTokens(count: tools + qualities))
        return DraftWriting(
            summary: nil, roleDescriptions: [],
            technologies: tools > 0 ? Self.clean(try? answer.value([String].self, forProperty: "tools")) : [],
            softSkills: qualities > 0 ? Self.clean(try? answer.value([String].self, forProperty: "qualities")) : []
        )
    }

    // MARK: The summary

    public func writeSummarySentence(for brief: DraftBrief, topic: SummaryTopic, written: [String]) async throws -> String? {
        try await summarySentence(SectionPrompts.summarySentence(for: brief, topic: topic, written: written))
    }

    public func repairSummarySentence(
        for brief: DraftBrief, topic: SummaryTopic, written: [String], rejected: String
    ) async throws -> String? {
        try await summarySentence(SectionPrompts.summarySentenceRepair(for: brief, topic: topic, written: written, rejected: rejected))
    }

    /// The first whole sentence `prompt` answers: one cut at its cap keeps its whole sentences, and a second sentence goes.
    private func summarySentence(_ prompt: SectionPrompts.Prompt) async throws -> String? {
        guard let last = try await streamed(prompt, SummarySentenceAnswer.self, tokens: Self.summarySentenceTokens),
              let sentence = last.answer.content.sentence,
              let whole = last.isComplete ? sentence.presentValue : Self.wholeSentences(of: sentence) else { return nil }
        return SentenceSplitter.sentences(in: whole).first?.presentValue
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

    private func streamed(
        _ prompt: SectionPrompts.Prompt, schema: GenerationSchema, tokens: Int
    ) async throws -> StreamedAnswer.Last<LanguageModelSession.ResponseStream<GeneratedContent>.Snapshot>? {
        let session = LanguageModelSession(instructions: prompt.instructions)
        do {
            let stream = session.streamResponse(
                to: prompt.text, schema: schema, includeSchemaInPrompt: true,
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
struct JobRepairAnswer {
    @Guide(description: "The rejected sentences written again and the duties asked for, one short whole sentence each", .count(1...3))
    let duties: [String]
}

@Generable
struct QualitiesAnswer {
    @Guide(description: "Personal qualities at work, as nouns", .count(3...5))
    let qualities: [String]
}

@Generable
struct SummarySentenceAnswer {
    @Guide(description: "One sentence of the summary, as the person")
    let sentence: String
}
#endif
