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
        let useCase = CVGeneratorUseCase(service: service, claimChecker: FakeClaimChecker())

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
        let useCase = CVGeneratorUseCase(service: service, claimChecker: FakeClaimChecker())

        await #expect(throws: CVGenerationError.unavailable(reason)) {
            try await useCase.generateCV(from: validRequest)
        }
        #expect(service.generateRequests.isEmpty)
    }

    @Test("generateCV returns the service's CV when available")
    func availableServiceResultIsReturned() async throws {
        let service = FakeCVGenerationService()
        let useCase = CVGeneratorUseCase(service: service, claimChecker: FakeClaimChecker())

        let draft = try await useCase.generateCV(from: validRequest)

        #expect(draft == GeneratedDraft(cvData: FakeCVGenerationService.sample, personalItemsUnchecked: false))
        #expect(service.generateRequests == [validRequest])
    }

    @Test("generateCV rejects an invalid request before calling the service")
    func invalidRequestIsNeverSent() async {
        let service = FakeCVGenerationService()
        let useCase = CVGeneratorUseCase(service: service, claimChecker: FakeClaimChecker())

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
        let useCase = CVGeneratorUseCase(service: service, claimChecker: FakeClaimChecker())

        let cvData = try await useCase.generateCV(from: validRequest).cvData

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
        let useCase = CVGeneratorUseCase(service: service, claimChecker: FakeClaimChecker())
        let request = CVGenerationRequest(
            userPrompt: "Since 2016 I have taught at the Don Milani school. Before that, from 2012 to 2016, I worked as an assistant in a nursery."
        )

        let cvData = try await useCase.generateCV(from: request).cvData

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
        let useCase = CVGeneratorUseCase(service: service, claimChecker: FakeClaimChecker())

        let cvData = try await useCase.generateCV(from: CVGenerationRequest(userPrompt: "I worked at Alpha. I worked at Beta.")).cvData

        #expect(cvData.experience.map(\.company) == ["Alpha", "Beta"])
        #expect(cvData.experience.allSatisfy { $0.startDate == nil && $0.endDate == nil })
    }

    @Test("generateCV reports an answer that nothing supports as empty")
    func emptyAfterSanitizing() async {
        let service = FakeCVGenerationService()
        service.generateResult = .success(CVData(
            personalInfo: PersonalInfo(name: "Someone Else", email: "invented@example.com")
        ))
        let useCase = CVGeneratorUseCase(service: service, claimChecker: FakeClaimChecker())

        await #expect(throws: CVGenerationError.emptyResult) {
            try await useCase.generateCV(from: validRequest)
        }
    }

    @Test("generateCV lets a service failure through unchanged")
    func serviceFailureIsPropagated() async {
        let service = FakeCVGenerationService()
        service.generateResult = .failure(CVGenerationError.busy)
        let useCase = CVGeneratorUseCase(service: service, claimChecker: FakeClaimChecker())

        await #expect(throws: CVGenerationError.busy) {
            try await useCase.generateCV(from: validRequest)
        }
    }

    @Test("generateCV asks for the language data of an English or German description before the model, and says when it is missing",
          arguments: [("I am John Doe, an engineer at Tech Corp since 2020", "en"), ("Ich bin Ingenieurin bei Tech Corp seit 2020.", "de")])
    func missingLanguageDataStopsBeforeTheModel(description: String, language: String) async {
        let service = FakeCVGenerationService()
        let withoutData = ForcedLexicalTagger([.english: .noAssets, .german: .noAssets])
        let useCase = CVGeneratorUseCase(service: service, claimChecker: FakeClaimChecker(), sanitizer: CVDataSanitizer(lexicalClasses: withoutData))

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
        let useCase = CVGeneratorUseCase(service: service, claimChecker: FakeClaimChecker(), sanitizer: CVDataSanitizer(lexicalClasses: withoutData))

        let cvData = try await useCase.generateCV(from: CVGenerationRequest(userPrompt: "Dal 2020 lavoro presso Tech Corp.")).cvData

        #expect(cvData.experience.map(\.company) == ["Tech Corp"])
    }

    @Test("generateCV lets cancellation through as cancellation")
    func cancellationIsPropagated() async {
        let service = FakeCVGenerationService()
        service.generateResult = .failure(CancellationError())
        let useCase = CVGeneratorUseCase(service: service, claimChecker: FakeClaimChecker())

        await #expect(throws: CancellationError.self) {
            try await useCase.generateCV(from: validRequest)
        }
    }

    // MARK: - The claim check (ADR 0028)

    private var example: FaithfulExample { faithfulExamples[0] }

    private func generator(drafting draft: CVData, checker: FakeClaimChecker) -> CVGeneratorUseCase {
        let service = FakeCVGenerationService()
        service.generateResult = .success(draft)
        return CVGeneratorUseCase(service: service, claimChecker: checker)
    }

    @Test("The check judges the personal items the rules kept, against the description, and nothing else")
    func checkSeesOnlyThePersonalItems() async throws {
        let checker = FakeClaimChecker()

        _ = try await generator(drafting: example.draft, checker: checker).generateCV(from: CVGenerationRequest(userPrompt: example.description))

        #expect(await checker.calls == [FakeClaimChecker.Call(
            candidates: [
                ClaimCandidate(kind: .title, value: "primary school teacher"), ClaimCandidate(kind: .place, value: "Bologna"),
                ClaimCandidate(kind: .language, value: "Italian"), ClaimCandidate(kind: .language, value: "English"),
                ClaimCandidate(kind: .interest, value: "chess"), ClaimCandidate(kind: .interest, value: "hiking"),
            ],
            description: example.description
        )])
    }

    @Test("An item the check reads as a wish, a denial or another person's is withdrawn, and a fact stays as the rules left it")
    func nonFactsAreWithdrawn() async throws {
        let checker = FakeClaimChecker(stances: ["Bologna": .otherPerson, "English": .wish, "chess": .denied])

        let draft = try await generator(drafting: example.draft, checker: checker)
            .generateCV(from: CVGenerationRequest(userPrompt: example.description))

        let survivors = example.survivors
        #expect(draft.personalItemsUnchecked == false)
        #expect(draft.cvData.personalInfo == PersonalInfo(name: "Maria Rossi", title: "primary school teacher"))
        #expect(draft.cvData.languages == [Language(name: "Italian", proficiency: .native)], "The level of English goes with it")
        #expect(draft.cvData.interests == ["hiking"])
        #expect(draft.cvData.experience == survivors.experience)
        #expect(draft.cvData.education == survivors.education)
    }

    @Test("The check never brings back an item the rules dropped")
    func checkAddsNothing() async throws {
        let description = "I know Swift and Python. In my free time I like chess and hiking."
        let checker = FakeClaimChecker()
        let generated = CVData(
            skills: [Skill(name: "Swift"), Skill(name: "Java"), Skill(name: "python")],
            interests: ["chess", "Hiking", "Painting"]
        )

        let draft = try await generator(drafting: generated, checker: checker).generateCV(from: CVGenerationRequest(userPrompt: description))

        #expect(await checker.calls.map(\.candidates) == [[
            ClaimCandidate(kind: .skill, value: "Swift"), ClaimCandidate(kind: .skill, value: "python"),
            ClaimCandidate(kind: .interest, value: "chess"), ClaimCandidate(kind: .interest, value: "Hiking"),
        ]])
        #expect(draft.cvData.skills.map(\.name) == ["Swift", "python"])
        #expect(draft.cvData.interests == ["chess", "Hiking"])
    }

    @Test("An item the answer leaves without a verdict is withdrawn")
    func missingVerdictWithdraws() async throws {
        let checker = FakeClaimChecker(verdictLimit: 2)

        let draft = try await generator(drafting: example.draft, checker: checker)
            .generateCV(from: CVGenerationRequest(userPrompt: example.description))

        #expect(draft.cvData.personalInfo.title == "primary school teacher")
        #expect(draft.cvData.personalInfo.location == "Bologna")
        #expect(draft.cvData.languages.isEmpty)
        #expect(draft.cvData.interests.isEmpty)
        #expect(draft.personalItemsUnchecked == false)
    }

    @Test("A check that fails withdraws all five kinds, keeps the jobs, the schools, their dates and the achievements, and says so",
          arguments: [CVGenerationError.generationFailed, .busy])
    func failedCheckWithdrawsEveryPersonalItem(failure: CVGenerationError) async throws {
        let checker = FakeClaimChecker(failure: failure)

        let draft = try await generator(drafting: example.draft, checker: checker)
            .generateCV(from: CVGenerationRequest(userPrompt: example.description))

        let survivors = example.survivors
        #expect(draft == GeneratedDraft(
            cvData: CVData(
                personalInfo: PersonalInfo(name: "Maria Rossi"),
                experience: survivors.experience,
                education: survivors.education
            ),
            personalItemsUnchecked: true
        ))
        #expect(await checker.calls.count == 1, "No retry")
    }

    @Test("The check is not asked when the rules left no personal item")
    func noCandidateNoCheck() async throws {
        let checker = FakeClaimChecker(failure: CVGenerationError.generationFailed)

        let draft = try await generator(drafting: FakeCVGenerationService.sample, checker: checker).generateCV(from: validRequest)

        #expect(await checker.calls.isEmpty)
        #expect(draft == GeneratedDraft(cvData: FakeCVGenerationService.sample, personalItemsUnchecked: false))
    }

    @Test("A draft the failed check leaves empty is reported as empty")
    func emptyAfterWithdrawal() async {
        let checker = FakeClaimChecker(failure: CVGenerationError.generationFailed)
        let generated = CVData(skills: [Skill(name: "Swift")], interests: ["chess"])

        await #expect(throws: CVGenerationError.emptyResult) {
            try await generator(drafting: generated, checker: checker)
                .generateCV(from: CVGenerationRequest(userPrompt: "I know Swift and Python. In my free time I like chess and hiking."))
        }
    }

    @Test("A cancelled check gives no draft")
    func cancelledCheckGivesNoDraft() async {
        let checker = FakeClaimChecker(failure: CancellationError())
        let useCase = generator(drafting: example.draft, checker: checker)

        await #expect(throws: CancellationError.self) {
            try await useCase.generateCV(from: CVGenerationRequest(userPrompt: example.description))
        }
    }

    @Test("A check that fails with an error of its own after the task was cancelled gives no draft")
    func failureAfterCancellationGivesNoDraft() async {
        let checker = FakeClaimChecker(failure: CVGenerationError.generationFailed, cancelsItsTask: true)
        let useCase = generator(drafting: example.draft, checker: checker)
        let request = CVGenerationRequest(userPrompt: example.description)

        let generation = Task { try await useCase.generateCV(from: request) }

        await #expect(throws: CancellationError.self) {
            try await generation.value
        }
    }
}
