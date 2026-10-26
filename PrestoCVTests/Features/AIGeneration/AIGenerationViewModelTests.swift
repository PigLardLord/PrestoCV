import Testing
import Foundation
import CVGeneratorAI
@testable import PrestoCV
@testable import PrestoCVCore

/// What a scripted generator answers.
enum ScriptedAnswer: Sendable {
    case draft
    case error
}

/// How a cancelled generation that ignored its cancellation finally ends.
enum LateEnd: Sendable {
    case result
    case cancellation
}

@MainActor
@Suite("AIGenerationViewModel Tests", .timeLimit(.minutes(1)))
struct AIGenerationViewModelTests {
    private let service = FakeCVGenerationService()
    private let labels = AIDraftLabels(present: "Oggi")
    private let validPrompt = "I am John Doe, an engineer at Tech Corp since 2020. I speak Italian (native) and French."

    private let languageData = LanguageDataSpy()
    /// The bound on the wait for the language data, which the test ends.
    private let sleeps = HeldSleeps()

    private func makeViewModel(
        appLanguageCode: String? = "it", session: AIDescriptionSession = AIDescriptionSession(),
        lexicalClasses: any LexicalTagger = FakeLexicalTagger.english, platform: AIPlatform = .iPhoneOrIPad,
        claimChecker: FakeClaimChecker = FakeClaimChecker()
    ) -> AIGenerationViewModel {
        let sleeps = sleeps
        return AIGenerationViewModel(
            cvGenerationUseCase: CVGeneratorUseCase(
                service: service, claimChecker: claimChecker, sanitizer: CVDataSanitizer(lexicalClasses: lexicalClasses)
            ),
            mapper: AIDraftMapper(labels: labels, languageOfText: { _ in "pt-PT" }),
            languageData: LanguageDataPreparation(requester: languageData, sleep: { try await sleeps.sleep(for: $0) }),
            appLanguageCode: appLanguageCode,
            session: session,
            platform: platform
        )
    }

    // MARK: - Keeping the description

    @Test("The description typed before leaving the screen is there when the screen opens again")
    func descriptionSurvivesLeavingTheScreen() {
        let session = AIDescriptionSession()
        let left = makeViewModel(session: session)
        left.prompt = validPrompt

        let reopened = makeViewModel(session: session)

        #expect(reopened.prompt == validPrompt)
        #expect(reopened.canGenerate, "Generate is on again for the description that was kept")
    }

    @Test("A description cleared before leaving stays cleared")
    func clearedDescriptionStaysCleared() {
        let session = AIDescriptionSession()
        let first = makeViewModel(session: session)
        first.prompt = validPrompt
        first.prompt = ""

        #expect(makeViewModel(session: session).prompt.isEmpty)
    }

    @Test("A new session starts with an empty description")
    func newSessionStartsEmpty() {
        #expect(makeViewModel().prompt.isEmpty)
    }

    @Test("Once a draft is made and handed to the editor, the next AI screen starts empty")
    func madeDraftLeavesTheNextScreenEmpty() async {
        let session = AIDescriptionSession()
        let finished = makeViewModel(session: session)
        finished.prompt = validPrompt

        await finished.generateCV()

        #expect(finished.draft != nil)
        #expect(finished.prompt == validPrompt, "The screen the draft came from still shows its description")
        let next = makeViewModel(session: session)
        #expect(next.prompt.isEmpty, "One CV's description does not carry into the next creation")
        #expect(!next.canGenerate)
    }

    @Test("After a draft, editing the screen it came from does not reach the next creation")
    func editsAfterADraftStayOnTheirScreen() async {
        let session = AIDescriptionSession()
        let finished = makeViewModel(session: session)
        finished.prompt = validPrompt
        await finished.generateCV()
        #expect(finished.draft != nil)

        finished.prompt = validPrompt + " I also speak Spanish."

        #expect(makeViewModel(session: session).prompt.isEmpty, "The edit stays on the screen it was made on")
    }

    @Test("A screen that made a draft and generates again leaves the description of a new creation alone")
    func regeneratingAfterADraftLeavesTheSessionAlone() async {
        let session = AIDescriptionSession()
        let finished = makeViewModel(session: session)
        finished.prompt = validPrompt
        await finished.generateCV()
        let newCreation = makeViewModel(session: session)
        let otherPrompt = "I am Anna Bianchi, a nurse in Turin since 2019. I speak Italian (native) and English."
        newCreation.prompt = otherPrompt

        finished.prompt = validPrompt + " I also speak Spanish."
        await finished.generateCV()

        #expect(finished.draft != nil)
        #expect(makeViewModel(session: session).prompt == otherPrompt)
    }

    @Test("A failed generation keeps the description, so that the person can try again")
    func failedGenerationKeepsTheDescription() async {
        service.generateResult = .failure(CVGenerationError.busy)
        let session = AIDescriptionSession()
        let failed = makeViewModel(session: session)
        failed.prompt = validPrompt

        await failed.generateCV()

        #expect(failed.draft == nil)
        #expect(makeViewModel(session: session).prompt == validPrompt)
    }

    @Test("A cancelled generation keeps the description")
    func cancelledGenerationKeepsTheDescription() async {
        service.holdsGeneration = true
        let session = AIDescriptionSession()
        let cancelled = makeViewModel(session: session)
        cancelled.prompt = validPrompt

        cancelled.startGenerating()
        await service.waitUntilGenerationsAreHeld()
        let generation = cancelled.generationTask
        cancelled.cancel()
        await generation?.value

        #expect(cancelled.draft == nil)
        #expect(makeViewModel(session: session).prompt == validPrompt)
    }

    // MARK: - Generating

    @Test("generateCV publishes the mapped CV as an unsaved draft")
    func generateCVPublishesDraft() async {
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        await viewModel.generateCV()

        #expect(viewModel.draft?.cv.personalInfo.name == "John Doe")
        #expect(viewModel.draft?.cv.name.isEmpty == true, "The list calls the draft by its person until it is renamed")
        #expect(viewModel.draft?.cv.relevant_experience.first?.period == "2020 – Oggi")
        #expect(viewModel.draft?.cv.languages.map(\.name) == ["Italian"], "A language without a level is skipped")
        #expect(viewModel.draft?.cv.documentLanguage == "pt", "The CV follows the language of the description")
        #expect(viewModel.draft?.notice == .aiDraft, "The claim check answered, so the draft opens with the usual notice")
        #expect(viewModel.errorMessage.isEmpty)
        #expect(!viewModel.isGenerating)
    }

    @Test("A claim check that gives no answer still gives a draft, without its personal items and with the notice that says so (ADR 0028)")
    func uncheckedDraftSaysSo() async {
        let viewModel = makeViewModel(claimChecker: FakeClaimChecker(fails: true))
        viewModel.prompt = validPrompt

        await viewModel.generateCV()

        #expect(viewModel.draft?.personalItemsUnchecked == true)
        #expect(viewModel.draft?.notice == .aiDraftUnchecked)
        #expect(viewModel.draft?.cv.personalInfo.name == "John Doe", "What the check does not judge stays")
        #expect(viewModel.draft?.cv.relevant_experience.map(\.company) == ["Tech Corp"])
        #expect(viewModel.draft?.cv.languages.isEmpty == true, "The languages are withdrawn for the person to add")
        #expect(viewModel.errorMessage.isEmpty, "A check without an answer is not an error")
    }

    @Test("A description of nothing but personal items, with a claim check that gives no answer, still opens a draft with the notice (ADR 0028)")
    func uncheckedEmptyDraftStillOpens() async {
        service.generateResult = .success(CVData(skills: [CVGeneratorAI.Skill(name: "Excel")]))
        let viewModel = makeViewModel(claimChecker: FakeClaimChecker(fails: true))
        viewModel.prompt = "I use Excel every day."

        await viewModel.generateCV()

        #expect(viewModel.draft?.notice == .aiDraftUnchecked)
        #expect(viewModel.draft?.cv.skills.isEmpty == true, "The skill the check could not judge is left for the person to add")
        #expect(viewModel.errorMessage.isEmpty, "A check without an answer is not an error, even when it leaves nothing")
    }

    @Test("generateCV sends the description and the app language")
    func generateCVSendsTheRequest() async {
        let viewModel = makeViewModel(appLanguageCode: "de")
        viewModel.prompt = validPrompt

        await viewModel.generateCV()

        #expect(service.generateRequests == [CVGenerationRequest(userPrompt: validPrompt, fallbackLanguageCode: "de")])
    }

    @Test("generateCV shows the unavailable reason instead of a draft")
    func generateCVWhenUnavailable() async {
        service.availabilityResult = .unavailable(.modelNotReady)
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        await viewModel.generateCV()

        #expect(viewModel.draft == nil)
        #expect(viewModel.errorMessage == "ai.unavailable.model_not_ready".localized)
        #expect(service.generateRequests.isEmpty)
        #expect(!viewModel.isGenerating)
    }

    @Test("A model that cannot run is explained for the platform: on a Mac, where to turn it on in System Settings",
          arguments: zip(
              [AIPlatform.iPhoneOrIPad, .mac],
              ["ai.unavailable.not_on_this_device", "ai.unavailable.not_enabled.mac"]
          ))
    func unavailableIsExplainedForThePlatform(platform: AIPlatform, key: String) async {
        service.availabilityResult = .unavailable(.deviceNotEligible)
        let viewModel = makeViewModel(platform: platform)
        viewModel.prompt = validPrompt

        await viewModel.generateCV()

        #expect(viewModel.errorMessage == key.localized)
        #expect(viewModel.draft == nil)
    }

    // MARK: - Language data

    @Test("A description whose language data the device has not got asks the system for it, and ends with the message at once when the system cannot give it")
    func missingLanguageDataIsRequested() async {
        let viewModel = makeViewModel(lexicalClasses: FakeLexicalTagger.withoutData)
        viewModel.prompt = validPrompt

        await viewModel.generateCV()

        #expect(languageData.requests == ["en"])
        #expect(viewModel.errorMessage == "ai.unavailable.language_data_not_ready".localized)
        #expect(viewModel.draft == nil)
        #expect(service.generateRequests.isEmpty, "The model does not write a draft that could not be grounded")
        #expect(!viewModel.isGenerating)
        #expect(viewModel.canGenerate, "Generate is on again, for a description in another language")
    }

    @Test("While the app waits for the data the screen stays busy; a system that never answers ends at the 60-second bound with the message")
    func languageDataThatNeverComesEndsAtTheBound() async {
        languageData.outcome = nil
        let viewModel = makeViewModel(lexicalClasses: FakeLexicalTagger.withoutData)
        viewModel.prompt = validPrompt

        viewModel.startGenerating()
        await languageData.waitUntilHeld(1)
        await sleeps.waitUntilStarted(1)

        #expect(await sleeps.durations == [.seconds(60)], "The person waits at most a minute")
        #expect(viewModel.isGenerating, "The generating screen stays up while the app waits")
        #expect(viewModel.isWaitingForLanguageData, "The screen says it waits for the data, not that the model writes")
        #expect(viewModel.errorMessage.isEmpty)

        await sleeps.endAll()
        await viewModel.generationTask?.value

        #expect(viewModel.errorMessage == "ai.unavailable.language_data_not_ready".localized)
        #expect(viewModel.draft == nil)
        #expect(languageData.requests == ["en"])
        #expect(service.generateRequests.isEmpty)
        #expect(!viewModel.isGenerating)
        #expect(!viewModel.isWaitingForLanguageData)
        #expect(viewModel.canGenerate)
        languageData.answerHeld(.notAvailable)  // Lets go of the request that was held; the test needs no answer from it
    }

    @Test("The wait for the data is a phase of its own on the busy screen, and the screen goes back to the model's writing once the data is there")
    func waitingForTheDataIsItsOwnPhase() async {
        let tagger = ArrivingLexicalTagger()
        languageData.outcome = nil
        languageData.onAvailable = tagger.dataArrives
        service.holdsGeneration = true
        let viewModel = makeViewModel(lexicalClasses: tagger)
        viewModel.prompt = validPrompt
        #expect(!viewModel.isWaitingForLanguageData, "Nothing is awaited before Generate")

        viewModel.startGenerating()
        await languageData.waitUntilHeld(1)

        #expect(viewModel.isWaitingForLanguageData)
        #expect(service.generateRequests.isEmpty, "The model is not writing yet")

        languageData.answerHeld(.available)
        await service.waitUntilGenerationsAreHeld()

        #expect(viewModel.isGenerating)
        #expect(!viewModel.isWaitingForLanguageData, "The data is there: now the model writes")

        service.releaseOldestGeneration(returning: FakeCVGenerationService.sample)
        await viewModel.generationTask?.value

        #expect(viewModel.draft?.cv.personalInfo.name == "John Doe")
        #expect(!viewModel.isWaitingForLanguageData)
    }

    @Test("Data that comes after the bound is not lost: the next Generate writes the draft at once, without asking the system again")
    func dataAfterTheBoundServesTheNextTap() async {
        let tagger = ArrivingLexicalTagger()
        languageData.outcome = nil
        languageData.onAvailable = tagger.dataArrives
        let viewModel = makeViewModel(lexicalClasses: tagger)
        viewModel.prompt = validPrompt
        viewModel.startGenerating()
        await languageData.waitUntilHeld(1)
        await sleeps.waitUntilStarted(1)
        await sleeps.endAll()
        await viewModel.generationTask?.value
        #expect(viewModel.errorMessage == "ai.unavailable.language_data_not_ready".localized)

        languageData.outcome = .notAvailable  // A second request, if the screen made one, would end at once and fail below
        languageData.answerHeld(.available)
        await viewModel.generateCV()

        #expect(languageData.requests == ["en"], "The data is on the device: nothing is asked for again")
        #expect(viewModel.draft?.cv.personalInfo.name == "John Doe")
        #expect(viewModel.errorMessage.isEmpty)
        #expect(service.generateRequests.count == 1)
    }

    @Test("Once the data arrives the draft is generated again, without another tap")
    func arrivedLanguageDataGeneratesTheDraft() async {
        let tagger = ArrivingLexicalTagger()
        languageData.outcome = .available
        languageData.onAvailable = tagger.dataArrives
        let viewModel = makeViewModel(lexicalClasses: tagger)
        viewModel.prompt = validPrompt

        await viewModel.generateCV()

        #expect(languageData.requests == ["en"])
        #expect(service.generateRequests.count == 1, "The first try stops before the model; only the second asks it")
        #expect(viewModel.draft?.cv.personalInfo.name == "John Doe")
        #expect(viewModel.errorMessage.isEmpty)
        #expect(!viewModel.isGenerating)
    }

    @Test("Data that is still missing once the system gave it ends with the message: the draft is generated again only once")
    func stillMissingLanguageDataEndsAfterOneMoreTry() async {
        service.generateResult = .failure(CVGenerationError.languageDataUnavailable(languageCode: "de"))
        languageData.outcome = .available
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        await viewModel.generateCV()

        #expect(service.generateRequests.count == 2)
        #expect(languageData.requests == ["de"])
        #expect(viewModel.errorMessage == "ai.unavailable.language_data_not_ready".localized)
        #expect(viewModel.draft == nil)
        #expect(!viewModel.isGenerating)
    }

    @Test("cancel while the app waits for the data returns the screen to idle at once, with no message and no draft, and the model is never asked")
    func cancelWhileWaitingForLanguageData() async {
        languageData.outcome = nil
        let viewModel = makeViewModel(lexicalClasses: FakeLexicalTagger.withoutData)
        viewModel.prompt = validPrompt

        viewModel.startGenerating()
        await languageData.waitUntilHeld(1)
        let task = viewModel.generationTask
        #expect(viewModel.isWaitingForLanguageData)
        viewModel.cancel()
        #expect(!viewModel.isGenerating, "The screen is idle at once, before the task has ended")
        #expect(!viewModel.isWaitingForLanguageData)
        await task?.value

        #expect(!viewModel.isGenerating)
        #expect(!viewModel.isWaitingForLanguageData)
        #expect(viewModel.errorMessage.isEmpty)
        #expect(viewModel.draft == nil)
        #expect(viewModel.canGenerate)
        #expect(languageData.requests == ["en"])
        #expect(service.generateRequests.isEmpty)
        languageData.answerHeld(.notAvailable)  // Lets go of the request that was held; the test needs no answer from it
    }

    @Test("The same state follows the error wherever the generator raises it")
    func languageDataMissingAfterTheModel() async {
        service.generateResult = .failure(CVGenerationError.languageDataUnavailable(languageCode: "de"))
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        await viewModel.generateCV()

        #expect(languageData.requests == ["de"])
        #expect(viewModel.errorMessage == "ai.unavailable.language_data_not_ready".localized)
        #expect(viewModel.draft == nil)
    }

    @Test("An Italian description needs no language data: nothing is asked of the system")
    func italianNeedsNoLanguageData() async {
        let viewModel = makeViewModel(lexicalClasses: FakeLexicalTagger.withoutData)
        viewModel.prompt = "Sono John Doe, ingegnere presso Tech Corp dal 2020. Parlo italiano (madrelingua) e francese."

        await viewModel.generateCV()

        #expect(languageData.requests.isEmpty)
        #expect(viewModel.draft?.cv.personalInfo.name == "John Doe")
        #expect(viewModel.errorMessage.isEmpty)
    }

    @Test("Another failure asks the system for nothing")
    func otherFailureAsksForNoData() async {
        service.generateResult = .failure(CVGenerationError.busy)
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        await viewModel.generateCV()

        #expect(languageData.requests.isEmpty)
    }

    @Test("generateCV explains a failure with the message of its error", arguments: [
        CVGenerationError.contentNotAllowed,
        .unsupportedLanguage,
        .busy,
        .descriptionTooLong,
        .generationFailed,
        .serviceFailed,
    ])
    func generateCVFailure(error: CVGenerationError) async {
        service.generateResult = .failure(error)
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        await viewModel.generateCV()

        #expect(viewModel.errorMessage == error.messageKey(on: .iPhoneOrIPad).localized)
        #expect(viewModel.draft == nil)
        #expect(!viewModel.isGenerating)
    }

    @Test("generateCV never shows the system's own error text, and does not blame the description for it")
    func generateCVUnknownFailure() async {
        struct SystemError: LocalizedError {
            var errorDescription: String? { "Internal model failure 0x1F" }
        }
        service.generateResult = .failure(SystemError())
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        await viewModel.generateCV()

        #expect(viewModel.errorMessage == "ai.unavailable.unknown".localized)
        #expect(!viewModel.errorMessage.contains("0x1F"))
    }

    @Test("A description that is too short is explained, not sent")
    func tooShortDescription() async {
        let viewModel = makeViewModel()
        viewModel.prompt = "Nurse"

        await viewModel.generateCV()

        #expect(viewModel.errorMessage == "ai.error.too_short".localized)
        #expect(service.generateRequests.isEmpty)
    }

    @Test("clearError dismisses the message")
    func clearErrorDismisses() async {
        service.generateResult = .failure(CVGenerationError.busy)
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt
        await viewModel.generateCV()

        viewModel.clearError()

        #expect(viewModel.errorMessage.isEmpty)
    }

    // MARK: - Description limits

    @Test("The description counter follows the text and the limit is 2,000")
    func characterCounter() {
        let viewModel = makeViewModel()
        viewModel.prompt = "abc"

        #expect(viewModel.characterCount == 3)
        #expect(viewModel.characterLimit == 2000)
    }

    @Test("Generate is off for a blank description and on for text within the limit")
    func canGenerateWithinTheLimit() {
        let viewModel = makeViewModel()
        #expect(!viewModel.canGenerate)

        viewModel.prompt = "   \n"
        #expect(!viewModel.canGenerate)

        viewModel.prompt = String(repeating: "a", count: 2000)
        #expect(viewModel.canGenerate)
        #expect(!viewModel.isOverCharacterLimit)
    }

    @Test("Generate is off over the limit, and nothing is sent")
    func overTheLimit() async {
        let viewModel = makeViewModel()
        viewModel.prompt = String(repeating: "a", count: 2001)

        #expect(viewModel.isOverCharacterLimit)
        #expect(!viewModel.canGenerate)

        await viewModel.generateCV()

        #expect(service.generateRequests.isEmpty)
    }

    // MARK: - Cancelling

    @Test("cancel stops a running generation without an error or a draft")
    func cancelDuringGeneration() async throws {
        service.holdsGeneration = true
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        try #require(viewModel.canGenerate)
        viewModel.startGenerating()
        await service.waitUntilGenerationsAreHeld()
        #expect(viewModel.isGenerating)
        #expect(!viewModel.canGenerate, "A second generation cannot start meanwhile")

        let task = viewModel.generationTask
        viewModel.cancel()
        #expect(!viewModel.isGenerating, "The screen is idle at once")
        await task?.value

        #expect(viewModel.draft == nil)
        #expect(viewModel.errorMessage.isEmpty)
        #expect(!viewModel.isGenerating)
    }

    @Test("A cancelled generation that still finishes does not produce a draft")
    func lateResultOfCancelledGenerationIsIgnored() async throws {
        service.holdsGeneration = true
        service.honoursCancellation = false
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        try #require(viewModel.canGenerate)
        viewModel.startGenerating()
        await service.waitUntilGenerationsAreHeld()
        let cancelledTask = viewModel.generationTask
        viewModel.cancel()

        service.releaseOldestGeneration(returning: FakeCVGenerationService.sample)
        await cancelledTask?.value

        #expect(viewModel.draft == nil, "The person cancelled; no draft may appear")
        #expect(viewModel.errorMessage.isEmpty)
        #expect(!viewModel.isGenerating)
    }

    @Test("A cancelled generation that finishes late does not end the one started after it", arguments: [
        LateEnd.result,
        .cancellation,
    ])
    func lateEndOfCancelledGenerationLeavesTheNextOneAlone(lateEnd: LateEnd) async throws {
        service.holdsGeneration = true
        service.honoursCancellation = false
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        try #require(viewModel.canGenerate)
        viewModel.startGenerating()
        await service.waitUntilGenerationsAreHeld()
        let cancelledTask = viewModel.generationTask
        viewModel.cancel()

        try #require(viewModel.canGenerate, "cancel must make the screen ready for another generation")
        viewModel.startGenerating()
        let secondTask = viewModel.generationTask
        await service.waitUntilGenerationsAreHeld(2)

        switch lateEnd {
        case .result: service.releaseOldestGeneration(returning: FakeCVGenerationService.sample)
        case .cancellation: service.releaseOldestGeneration(throwing: CancellationError())
        }
        await cancelledTask?.value
        #expect(viewModel.isGenerating, "The second generation is still running")
        #expect(viewModel.draft == nil)

        service.releaseOldestGeneration(returning: FakeCVGenerationService.sample)
        await secondTask?.value

        #expect(viewModel.draft != nil)
        #expect(!viewModel.isGenerating)
    }

    @Test("cancel right after Generate, before the task has run, never reaches the model", arguments: [
        ScriptedAnswer.draft,
        .error,
    ])
    func cancelBeforeTheTaskStarts(answer: ScriptedAnswer) async {
        service.generateResult = answer == .draft ? .success(FakeCVGenerationService.sample) : .failure(CVGenerationError.busy)
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        viewModel.startGenerating()
        #expect(viewModel.isGenerating, "The screen is busy as soon as Generate is tapped")
        let task = viewModel.generationTask
        viewModel.cancel()
        #expect(!viewModel.isGenerating)
        await task?.value

        #expect(service.generateRequests.isEmpty, "The fake answers whatever the task's state, so a request would show here")
        #expect(viewModel.draft == nil)
        #expect(viewModel.errorMessage.isEmpty)
        #expect(!viewModel.isGenerating)
    }

    @Test("Generate tapped again right after a cancel runs once, and the cancelled one stays silent")
    func startAgainRightAfterCancel() async {
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        viewModel.startGenerating()
        let cancelledTask = viewModel.generationTask
        viewModel.cancel()
        viewModel.startGenerating()
        let secondTask = viewModel.generationTask
        await cancelledTask?.value
        await secondTask?.value

        #expect(service.generateRequests.count == 1)
        #expect(viewModel.draft != nil)
        #expect(!viewModel.isGenerating)
    }

    @Test("A task cancelled from outside returns the screen to idle without a draft or an error")
    func taskCancelledFromOutside() async {
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        viewModel.startGenerating()
        viewModel.generationTask?.cancel()
        await viewModel.generationTask?.value

        #expect(service.generateRequests.isEmpty)
        #expect(viewModel.draft == nil)
        #expect(viewModel.errorMessage.isEmpty)
        #expect(!viewModel.isGenerating)
    }

    @Test("cancel with nothing running is harmless")
    func cancelWhenIdle() {
        let viewModel = makeViewModel()

        viewModel.cancel()

        #expect(!viewModel.isGenerating)
        #expect(viewModel.draft == nil)
    }
}
