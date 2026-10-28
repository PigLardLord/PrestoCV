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
    var writeResult: Result<DraftWriting?, Error> = .success(nil)
    /// The errors the first calls of the second pass throw, in order, before `writeResult` answers.
    var writeFailures: [any Error] = []
    /// How long the second pass takes before it answers; it stops early when its task is cancelled.
    var writeDelay: Duration?

    private(set) var generateRequests: [CVGenerationRequest] = []
    private(set) var writeBriefs: [DraftBrief] = []

    func availability() -> AIAvailability {
        availabilityResult
    }

    func generateCV(from request: CVGenerationRequest) async throws -> CVData {
        generateRequests.append(request)
        if let generateDelay { try await Task.sleep(for: generateDelay) }
        if !generateFailures.isEmpty { throw generateFailures.removeFirst() }
        return try generateResult.get()
    }

    func writeDraft(for brief: DraftBrief) async throws -> DraftWriting? {
        writeBriefs.append(brief)
        if let writeDelay { try await Task.sleep(for: writeDelay) }
        if !writeFailures.isEmpty { throw writeFailures.removeFirst() }
        return try writeResult.get()
    }

    static let sample = CVData(
        personalInfo: PersonalInfo(name: "John Doe"),
        experience: [Experience(title: "Engineer", company: "Tech Corp", startDate: "2020")]
    )
}
