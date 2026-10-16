import Foundation
@testable import CVGeneratorAI

/// A scripted `CVGenerationService` that records what it was asked.
@MainActor
final class FakeCVGenerationService: CVGenerationService {
    var availabilityResult: AIAvailability = .available
    var generateResult: Result<CVData, Error> = .success(FakeCVGenerationService.sample)

    private(set) var generateRequests: [CVGenerationRequest] = []

    func availability() -> AIAvailability {
        availabilityResult
    }

    func generateCV(from request: CVGenerationRequest) async throws -> CVData {
        generateRequests.append(request)
        return try generateResult.get()
    }

    static let sample = CVData(
        personalInfo: PersonalInfo(name: "John Doe"),
        experience: [Experience(title: "Engineer", company: "Tech Corp", startDate: "2020")]
    )
}
