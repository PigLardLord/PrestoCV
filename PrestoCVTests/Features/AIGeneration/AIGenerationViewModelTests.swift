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
@Suite("AIGenerationViewModel Tests")
struct AIGenerationViewModelTests {
    private let service = FakeCVGenerationService()
    private let labels = AIDraftLabels(present: "Oggi", untitled: "Nuovo CV", cvNameFormat: "CV di %@")
    private let validPrompt = "I am John Doe, an engineer at Tech Corp since 2020. I speak Italian (native) and French."

    private func makeViewModel(appLanguageCode: String? = "it") -> AIGenerationViewModel {
        AIGenerationViewModel(
            cvGenerationUseCase: CVGeneratorUseCase(service: service),
            mapper: AIDraftMapper(labels: labels, languageOfText: { _ in "pt-PT" }),
            appLanguageCode: appLanguageCode
        )
    }

    // MARK: - Generating

    @Test("generateCV publishes the mapped CV as an unsaved draft")
    func generateCVPublishesDraft() async {
        let viewModel = makeViewModel()
        viewModel.prompt = validPrompt

        await viewModel.generateCV()

        #expect(viewModel.draft?.name == "CV di John Doe")
        #expect(viewModel.draft?.relevant_experience.first?.period == "2020 – Oggi")
        #expect(viewModel.draft?.languages.map(\.name) == ["Italian"], "A language without a level is skipped")
        #expect(viewModel.draft?.documentLanguage == "pt", "The CV follows the language of the description")
        #expect(viewModel.errorMessage.isEmpty)
        #expect(!viewModel.isGenerating)
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

        #expect(viewModel.errorMessage == error.messageKey.localized)
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
