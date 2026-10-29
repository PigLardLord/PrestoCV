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
    var moreSkillsResult: DraftWriting?
    var summaryResult: String?
    var summaryRepairResult: String?
    /// The errors the first calls of a request throw, in order, by the request's name in `sectionCalls`.
    var sectionFailures: [String: [any Error]] = [:]
    /// How long a request takes before it answers, by its name in `sectionCalls`; it stops early when its task is cancelled.
    var sectionDelays: [String: Duration] = [:]
    /// Told the name of each section request as it starts.
    var onSection: (@MainActor (String) -> Void)?

    /// The section requests in the order they were made: "job 0", "repairJob 0", "tools", "softSkills", "moreSkills", "summary",
    /// "repairSummary".
    private(set) var sectionCalls: [String] = []
    /// The brief each section request read, one for one with `sectionCalls`.
    private(set) var sectionBriefs: [DraftBrief] = []
    /// The jobs of each tools request, by their numbers.
    private(set) var toolsRequests: [[Int]] = []
    private(set) var toolsCounts: [ClosedRange<Int>] = []
    private(set) var jobRepairs: [(number: Int, kept: [String], rejected: [String])] = []
    private(set) var moreSkillsRequests: [(tools: Int, qualities: Int, listedTools: [String], listedQualities: [String], rejected: [String])] = []
    private(set) var summaryRequests: [(tools: [String], qualities: [String])] = []
    private(set) var summaryRepairs: [(kept: [String], rejected: [String], problems: [String])] = []

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

    func writeMoreSkills(
        for brief: DraftBrief, tools: Int, qualities: Int, listedTools: [String], listedQualities: [String], rejected: [String]
    ) async throws -> DraftWriting? {
        moreSkillsRequests.append((tools, qualities, listedTools, listedQualities, rejected))
        try await section("moreSkills", brief)
        return moreSkillsResult
    }

    func writeSummary(for brief: DraftBrief, tools: [String], qualities: [String]) async throws -> String? {
        summaryRequests.append((tools, qualities))
        try await section("summary", brief)
        return summaryResult
    }

    func repairSummary(
        for brief: DraftBrief, tools: [String], qualities: [String], kept: [String], rejected: [String], problems: [String]
    ) async throws -> String? {
        summaryRepairs.append((kept, rejected, problems))
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
