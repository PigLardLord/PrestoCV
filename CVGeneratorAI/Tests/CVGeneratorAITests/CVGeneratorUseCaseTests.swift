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

    @Test("generateCV lists the job that goes on now first, then the newest")
    func currentJobFirst() async throws {
        let service = FakeCVGenerationService()
        service.generateResult = .success(CVData(experience: [
            Experience(title: "assistant", company: "nursery", startDate: "2012", endDate: "2016"),
            Experience(title: "", company: "Don Milani school", startDate: "2016", current: true),
        ]))
        let useCase = CVGeneratorUseCase(service: service)
        let request = CVGenerationRequest(
            userPrompt: "Since 2016 I have taught at the Don Milani school. Before that, from 2012 to 2016, I worked as an assistant in a nursery."
        )

        let cvData = try await useCase.generateCV(from: request)

        #expect(cvData.experience.map(\.company) == ["Don Milani school", "nursery"])
        #expect(cvData.experience.map(\.startDate) == ["2016", "2012"])
    }

    @Test("generateCV orders the jobs only by the years the description backs")
    func inventedYearsOrderNothing() async throws {
        let service = FakeCVGenerationService()
        service.generateResult = .success(CVData(experience: [
            Experience(title: "", company: "Alpha", startDate: "2010", endDate: "2012"),
            Experience(title: "", company: "Beta", startDate: "2018", endDate: "2020"),
        ]))
        let useCase = CVGeneratorUseCase(service: service)

        let cvData = try await useCase.generateCV(from: CVGenerationRequest(userPrompt: "I worked at Alpha. I worked at Beta."))

        #expect(cvData.experience.map(\.company) == ["Alpha", "Beta"])
        #expect(cvData.experience.allSatisfy { $0.startDate == nil && $0.endDate == nil })
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

    @Test("generateCV asks for the language data of an English or German description before the model, and says when it is missing",
          arguments: [("I am John Doe, an engineer at Tech Corp since 2020", "en"), ("Ich bin Ingenieurin bei Tech Corp seit 2020.", "de")])
    func missingLanguageDataStopsBeforeTheModel(description: String, language: String) async {
        let service = FakeCVGenerationService()
        let withoutData = ForcedLexicalTagger([.english: .noAssets, .german: .noAssets])
        let useCase = CVGeneratorUseCase(service: service, sanitizer: CVDataSanitizer(lexicalClasses: withoutData))

        await #expect(throws: CVGenerationError.languageDataUnavailable(languageCode: language)) {
            try await useCase.generateCV(from: CVGenerationRequest(userPrompt: description))
        }
        #expect(service.generateRequests.isEmpty)
    }

    @Test("An Italian description needs no language data of the device")
    func italianNeedsNoLanguageData() async throws {
        let service = FakeCVGenerationService()
        service.generateResult = .success(CVData(experience: [Experience(title: "", company: "Tech Corp")]))
        let withoutData = ForcedLexicalTagger(Dictionary(uniqueKeysWithValues: Vocabulary.Language.allCases.map { ($0, .noAssets) }))
        let useCase = CVGeneratorUseCase(service: service, sanitizer: CVDataSanitizer(lexicalClasses: withoutData))

        let cvData = try await useCase.generateCV(from: CVGenerationRequest(userPrompt: "Dal 2020 lavoro presso Tech Corp."))

        #expect(cvData.experience.map(\.company) == ["Tech Corp"])
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
