import Foundation
@testable import CVGeneratorAI

/// A scripted `CVGenerationService` that records what it was asked.
@MainActor
final class FakeCVGenerationService: CVGenerationService {
    var availabilityResult: AIAvailability = .available
    var generateResult: Result<CVData, Error> = .success(FakeCVGenerationService.sample)

    /// The errors the first calls of the first pass throw, in order, before `generateResult` answers.
    var generateFailures: [any Error] = []
    /// How long the first pass takes before it answers; it stops early when its task is cancelled.
    var generateDelay: Duration?

    private(set) var generateRequests: [CVGenerationRequest] = []

    func availability() -> AIAvailability {
        availabilityResult
    }

    func generateCV(from request: CVGenerationRequest) async throws -> CVData {
        generateRequests.append(request)
        if let generateDelay { try await Task.sleep(for: generateDelay) }
        if !generateFailures.isEmpty { throw generateFailures.removeFirst() }
        return try generateResult.get()
    }

    // MARK: A request per section (ADR 0031)

    /// The years and duties each job's request answers, by the job's number in the brief; nil for a job not listed.
    var jobResults: [Int: RoleWriting] = [:]
    /// The duties each job's repair answers, by the job's number.
    var jobRepairResults: [Int: [String]] = [:]
    /// The tools of each job, by its number: a request for the jobs that share a title answers theirs, in order.
    var toolsResult: [[String]]?
    var softSkillsResult: [String]?
    /// The tools each request for tools of one kind answers, by the kind; none for a kind not listed.
    var toolsOfAKindResults: [ToolKind: [String]] = [:]
    var moreQualitiesResult: [String]?
    /// The sentences the summary requests answer, in order; once they run out, `summaryResult` answers each.
    var summaryResults: [String?] = []
    var summaryResult: String?
    var summaryRepairResult: String?
    /// The errors the first calls of a request throw, in order, by the request's name in `sectionCalls`.
    var sectionFailures: [String: [any Error]] = [:]
    /// How long a request takes before it answers, by its name in `sectionCalls`; it stops early when its task is cancelled.
    var sectionDelays: [String: Duration] = [:]
    /// Told the name of each section request as it starts.
    var onSection: (@MainActor (String) -> Void)?

    /// The section requests in the order they were made: "job 0", "repairJob 0", "tools", "toolsOfAKind", "softSkills", "moreQualities", "summary",
    /// "repairSummary".
    private(set) var sectionCalls: [String] = []
    /// The brief each section request read, one for one with `sectionCalls`.
    private(set) var sectionBriefs: [DraftBrief] = []
    /// The jobs of each tools request, by their numbers.
    private(set) var toolsRequests: [[Int]] = []
    private(set) var toolsCounts: [ClosedRange<Int>] = []
    private(set) var jobRepairs: [(number: Int, kept: [String], rejected: [String])] = []
    private(set) var toolsOfAKindRequests: [(roles: [Int], kind: ToolKind, listed: [String], rejected: [String])] = []
    private(set) var moreQualitiesRequests: [(count: Int, listed: [String], rejected: [String])] = []
    private(set) var summaryRequests: [(topic: SummaryTopic, written: [String])] = []
    private(set) var summaryRepairs: [(topic: SummaryTopic, written: [String], rejected: String)] = []

    func writeJob(number: Int, of brief: DraftBrief) async throws -> RoleWriting? {
        try await section("job \(number)", brief)
        return jobResults[number]
    }

    func repairJob(number: Int, of brief: DraftBrief, kept: [String], rejected: [String]) async throws -> [String]? {
        jobRepairs.append((number, kept, rejected))
        try await section("repairJob \(number)", brief)
        return jobRepairResults[number]
    }

    func writeTools(for brief: DraftBrief, roles: [Int], count: ClosedRange<Int>) async throws -> [String]? {
        toolsRequests.append(roles)
        toolsCounts.append(count)
        try await section("tools", brief)
        return toolsResult.map { tools in roles.filter(tools.indices.contains).flatMap { tools[$0] } }
    }

    func writeSoftSkills(for brief: DraftBrief) async throws -> [String]? {
        try await section("softSkills", brief)
        return softSkillsResult
    }

    func writeToolsOfAKind(
        for brief: DraftBrief, roles: [Int], kind: ToolKind, listed: [String], rejected: [String]
    ) async throws -> [String]? {
        toolsOfAKindRequests.append((roles, kind, listed, rejected))
        try await section("toolsOfAKind", brief)
        return toolsOfAKindResults[kind]
    }

    func writeMoreQualities(for brief: DraftBrief, count: Int, listed: [String], rejected: [String]) async throws -> [String]? {
        moreQualitiesRequests.append((count, listed, rejected))
        try await section("moreQualities", brief)
        return moreQualitiesResult
    }

    func writeSummarySentence(for brief: DraftBrief, topic: SummaryTopic, written: [String]) async throws -> String? {
        summaryRequests.append((topic, written))
        try await section("summary", brief)
        return summaryResults.isEmpty ? summaryResult : summaryResults.removeFirst()
    }

    func repairSummarySentence(for brief: DraftBrief, topic: SummaryTopic, written: [String], rejected: String) async throws -> String? {
        summaryRepairs.append((topic, written, rejected))
        try await section("repairSummary", brief)
        return summaryRepairResult
    }

    private func section(_ name: String, _ brief: DraftBrief) async throws {
        sectionCalls.append(name)
        sectionBriefs.append(brief)
        onSection?(name)
        if let delay = sectionDelays[name] { try await Task.sleep(for: delay) }
        if let error = sectionFailures[name]?.first {
            sectionFailures[name]?.removeFirst()
            throw error
        }
    }

    static let sample = CVData(
        personalInfo: PersonalInfo(name: "John Doe"),
        experience: [Experience(title: "Engineer", company: "Tech Corp", startDate: "2020")]
    )
}
