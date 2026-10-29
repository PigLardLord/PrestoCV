import Foundation

/// Protocol for CV generation services
/// Implementations can use different AI backends (FoundationModels, remote APIs, etc.)
/// @MainActor isolation ensures all operations stay within the same actor context, avoiding concurrency issues
@MainActor
public protocol CVGenerationService {
    /// Whether the service can generate now on this device, and the reason when it cannot
    func availability() -> AIAvailability

    /// Generate a CV from user input
    /// - Parameter request: The generation request containing the person's description
    /// - Returns: The CV data the model produced, not yet checked against the description
    /// - Throws: CVGenerationError if generation fails, or CancellationError if the task was cancelled
    func generateCV(from request: CVGenerationRequest) async throws -> CVData

    /// Write the summary, the duties of each role and the role's skills around the facts of a draft: the second pass (ADR 0031)
    /// - Parameter brief: The facts the rules kept from the first pass, without the description
    /// - Returns: What the model wrote, not yet checked; nil when the service writes nothing around the facts
    /// - Throws: CVGenerationError if generation fails, or CancellationError if the task was cancelled
    func writeDraft(for brief: DraftBrief) async throws -> DraftWriting?

    // MARK: A request per section (ADR 0031)
    //
    // Each request answers one section of the draft from the brief, never from the description; nil when the service writes
    // nothing for it. Each throws CVGenerationError if generation fails, or CancellationError if the task was cancelled.

    /// The years and the duties of the job at `number` of `brief`, from its own clauses.
    func writeJob(number: Int, of brief: DraftBrief) async throws -> RoleWriting?

    /// The duties of the job at `number` of `brief` written again: each sentence of `rejected` ("sentence": reason) fixed or left
    /// out, and one more duty, none of `kept`.
    func repairJob(number: Int, of brief: DraftBrief, kept: [String], rejected: [String]) async throws -> [String]?

    /// `count` tools of the trade of the jobs of `brief` at `roles`, which share a title: 6 to 8 of the headline's, at most 1 of another.
    func writeTools(for brief: DraftBrief, roles: [Int], count: ClosedRange<Int>) async throws -> [String]?

    /// 3 to 5 personal qualities at work that fit the jobs of `brief`.
    func writeSoftSkills(for brief: DraftBrief) async throws -> [String]?

    /// Up to 2 tools of `kind` of the title of the jobs of `brief` at `roles`, the headline's: none when the trade works with none
    /// of that kind; none of the tools kept (`listed`) and none of `rejected` ("tool": reason), those the check dropped.
    func writeToolsOfAKind(for brief: DraftBrief, roles: [Int], kind: ToolKind, listed: [String], rejected: [String]) async throws -> [String]?

    /// `count` more soft skills for the jobs of `brief`, none of those kept (`listed`) and none of `rejected` ("quality": reason).
    func writeMoreQualities(for brief: DraftBrief, count: Int, listed: [String], rejected: [String]) async throws -> [String]?

    /// One sentence of the summary, on `topic` alone, after the sentences `written` so far: no duty, which it would copy (#354,
    /// round 13).
    func writeSummarySentence(for brief: DraftBrief, topic: SummaryTopic, written: [String]) async throws -> String?

    /// The sentence on `topic` written again, from the one the check rejected and why (`rejected`, "sentence": reason).
    func repairSummarySentence(for brief: DraftBrief, topic: SummaryTopic, written: [String], rejected: String) async throws -> String?
}

extension CVGenerationService {
    /// A service that only extracts writes nothing around the facts: the draft keeps them alone.
    public func writeDraft(for brief: DraftBrief) async throws -> DraftWriting? { nil }
    public func writeJob(number: Int, of brief: DraftBrief) async throws -> RoleWriting? { nil }
    public func repairJob(number: Int, of brief: DraftBrief, kept: [String], rejected: [String]) async throws -> [String]? { nil }
    public func writeTools(for brief: DraftBrief, roles: [Int], count: ClosedRange<Int>) async throws -> [String]? { nil }
    public func writeSoftSkills(for brief: DraftBrief) async throws -> [String]? { nil }
    public func writeToolsOfAKind(
        for brief: DraftBrief, roles: [Int], kind: ToolKind, listed: [String], rejected: [String]
    ) async throws -> [String]? { nil }
    public func writeMoreQualities(for brief: DraftBrief, count: Int, listed: [String], rejected: [String]) async throws -> [String]? { nil }
    public func writeSummarySentence(for brief: DraftBrief, topic: SummaryTopic, written: [String]) async throws -> String? { nil }
    public func repairSummarySentence(
        for brief: DraftBrief, topic: SummaryTopic, written: [String], rejected: String
    ) async throws -> String? { nil }
}
