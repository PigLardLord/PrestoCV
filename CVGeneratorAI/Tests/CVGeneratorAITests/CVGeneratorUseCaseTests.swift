import Testing
import Foundation
@testable import CVGeneratorAI

@MainActor
@Suite("CVGeneratorUseCase Tests")
struct CVGeneratorUseCaseTests {
    private let validRequest = CVGenerationRequest(
        userPrompt: "I am John Doe, an engineer at Tech Corp since 2020"
    )

    @Test("availability reports what the service reports")
    func availabilityComesFromTheService() {
        let service = FakeCVGenerationService()
        let useCase = CVGeneratorUseCase(service: service)

        service.availabilityResult = .unavailable(.modelNotReady)
        #expect(useCase.availability() == .unavailable(.modelNotReady))

        service.availabilityResult = .available
        #expect(useCase.availability() == .available)
    }

    @Test("generateCV does not call the service while unavailable", arguments: [
        AIAvailability.Reason.deviceNotEligible,
        .appleIntelligenceNotEnabled,
        .modelNotReady,
        .unknown,
    ])
    func unavailableServiceIsNeverCalled(reason: AIAvailability.Reason) async {
        let service = FakeCVGenerationService()
        service.availabilityResult = .unavailable(reason)
        let useCase = CVGeneratorUseCase(service: service)

        await #expect(throws: CVGenerationError.unavailable(reason)) {
            try await useCase.generateCV(from: validRequest)
        }
        #expect(service.generateRequests.isEmpty)
    }

    @Test("generateCV returns the service's CV when available")
    func availableServiceResultIsReturned() async throws {
        let service = FakeCVGenerationService()
        let useCase = CVGeneratorUseCase(service: service)

        let cvData = try await useCase.generateCV(from: validRequest)

        #expect(cvData == FakeCVGenerationService.sample)
        #expect(service.generateRequests == [validRequest])
    }

    @Test("generateCV rejects an invalid request before calling the service")
    func invalidRequestIsNeverSent() async {
        let service = FakeCVGenerationService()
        let useCase = CVGeneratorUseCase(service: service)

        await #expect(throws: CVGenerationError.descriptionTooShort) {
            try await useCase.generateCV(from: CVGenerationRequest(userPrompt: "   "))
        }
        #expect(service.generateRequests.isEmpty)
    }

    @Test("generateCV removes what the description does not support")
    func unsupportedDetailsAreRemoved() async throws {
        let service = FakeCVGenerationService()
        service.generateResult = .success(CVData(
            personalInfo: PersonalInfo(name: "John Doe", email: "invented@example.com"),
            experience: [Experience(title: "Engineer", company: "Tech Corp", startDate: "2020", endDate: "2024")]
        ))
        let useCase = CVGeneratorUseCase(service: service)

        let cvData = try await useCase.generateCV(from: validRequest)

        #expect(cvData.personalInfo.name == "John Doe")
        #expect(cvData.personalInfo.email == nil)
        #expect(cvData.experience.first?.startDate == "2020")
        #expect(cvData.experience.first?.endDate == nil)
    }

    @Test("generateCV reports an answer that nothing supports as empty")
    func emptyAfterSanitizing() async {
        let service = FakeCVGenerationService()
        service.generateResult = .success(CVData(
            personalInfo: PersonalInfo(name: "Someone Else", email: "invented@example.com")
        ))
        let useCase = CVGeneratorUseCase(service: service)

        await #expect(throws: CVGenerationError.emptyResult) {
            try await useCase.generateCV(from: validRequest)
        }
    }

    @Test("generateCV lets a service failure through unchanged")
    func serviceFailureIsPropagated() async {
        let service = FakeCVGenerationService()
        service.generateResult = .failure(CVGenerationError.busy)
        let useCase = CVGeneratorUseCase(service: service)

        await #expect(throws: CVGenerationError.busy) {
            try await useCase.generateCV(from: validRequest)
        }
    }

    @Test("generateCV lets cancellation through as cancellation")
    func cancellationIsPropagated() async {
        let service = FakeCVGenerationService()
        service.generateResult = .failure(CancellationError())
        let useCase = CVGeneratorUseCase(service: service)

        await #expect(throws: CancellationError.self) {
            try await useCase.generateCV(from: validRequest)
        }
    }
}
