import Testing
import Foundation
import CVGeneratorAI
@testable import PrestoCV
@testable import PrestoCVCore

/// A generation service that fails the way a test asks.
@MainActor
private final class FailingGenerationService: CVGenerationService {
    let error: Error

    init(error: Error) { self.error = error }

    func isAvailable() async -> Bool { true }

    func generateCV(from request: CVGenerationRequest) async throws -> CVGenerationResult {
        throw error
    }

    @available(iOS 26, macOS 26, *)
    func generateCVStream(from request: CVGenerationRequest) -> AsyncThrowingStream<CVData.PartiallyGenerated, Error> {
        AsyncThrowingStream { $0.finish(throwing: error) }
    }
}

@MainActor
@Suite("AIGenerationViewModel Tests - what the person reads when drafting fails")
struct AIGenerationViewModelErrorTests {

    private func makeViewModel(failingWith error: Error) -> AIGenerationViewModel {
        AIGenerationViewModel(
            cvGenerationUseCase: CVGeneratorUseCase(service: FailingGenerationService(error: error)),
            cvManagementUseCase: MockCVManagementUseCase()
        )
    }

    @Test("A system error is explained by the general sentence, not by its domain and code")
    func systemErrorIsExplainedInWords() async {
        let raw = NSError(domain: "com.apple.SensitiveContentAnalysisML", code: 15)
        let viewModel = makeViewModel(failingWith: raw)
        viewModel.prompt = "I'm a nurse in Rome with ten years of experience"

        await viewModel.generateCV()

        #expect(viewModel.errorMessage == "ai.error.failed".localized)
        #expect(!viewModel.errorMessage.contains("com.apple"))
        #expect(viewModel.generatedCVId == nil)
        #expect(!viewModel.isGenerating)
    }

    @Test("A failure the service wrapped in its own error carries none of the system's words")
    func wrappedSystemErrorIsExplainedInWords() async {
        let wrapped = CVGenerationError.unknown("Failed to generate CV: The operation couldn’t be completed. (com.apple.SensitiveContentAnalysisML error 15.)")
        let viewModel = makeViewModel(failingWith: wrapped)
        viewModel.prompt = "I'm a nurse in Rome with ten years of experience"

        await viewModel.generateCV()

        #expect(viewModel.errorMessage == "ai.error.failed".localized)
    }

    @Test("A model that cannot run says so in words")
    func unavailableServiceIsExplained() async {
        let viewModel = makeViewModel(failingWith: CVGenerationError.serviceUnavailable)
        viewModel.prompt = "I'm a nurse in Rome with ten years of experience"

        await viewModel.generateCV()

        #expect(viewModel.errorMessage == "ai.unavailable.unknown".localized)
    }

    @Test("A description that is too long for the model says so in words")
    func tooLongDescriptionIsExplained() async {
        let viewModel = makeViewModel(failingWith: CVGenerationError.descriptionTooLong)
        viewModel.prompt = "I'm a nurse in Rome with ten years of experience"

        await viewModel.generateCV()

        #expect(viewModel.errorMessage == "ai.error.too_long".localized)
    }

    @Test("An empty description is answered in the language of the app, not in English")
    func emptyDescriptionIsLocalized() async {
        let viewModel = makeViewModel(failingWith: CVGenerationError.serviceUnavailable)
        viewModel.prompt = "   "

        await viewModel.generateCV()

        #expect(viewModel.errorMessage == "ai.error.empty_description".localized)
    }
}
