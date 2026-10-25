import Combine
import Foundation
import PrestoCVCore
import CVGeneratorAI

@MainActor
final class AIGenerationViewModel: ObservableObject {
    /// The description, kept in the session as it is typed, so that it survives leaving the screen until a draft is
    /// made from it.
    @Published var prompt: String {
        didSet { session?.text = prompt }
    }
    @Published private(set) var isGenerating: Bool = false
    @Published private(set) var errorMessage: String = ""
    /// The generated CV, not stored yet: the editor opens it for review, with the notice it calls for, and stores it as it is.
    @Published private(set) var draft: AIDraft?

    /// The running generation started by `startGenerating()`, kept so `cancel()` can stop it.
    private(set) var generationTask: Task<Void, Never>?

    private let cvGenerationUseCase: CVGeneratorUseCase
    private let mapper: AIDraftMapper
    private let languageData: LanguageDataPreparation
    private let appLanguageCode: String?
    private let platform: AIPlatform
    /// Where the description of this creation is kept, until a draft is made from it. The screen then lets go of it for
    /// good: its own text stays, to adjust and generate again, but nothing it does reaches the next creation.
    private var session: AIDescriptionSession?

    /// The generation allowed to report its outcome. It is set before its task runs and cleared by `cancel()`,
    /// so a cancelled generation, even one that returns later, finds it changed and stays silent.
    private var activeGeneration: UUID?

    /// One request to the generator: its identity, and the request as it was when the person tapped Generate.
    private struct Generation {
        let id = UUID()
        let request: CVGenerationRequest
    }

    /// - Parameters:
    ///   - languageData: The wait for the language data that grounding a description needs, when the device has not got it.
    ///   - platform: Where the app runs, for the words of an unavailable model. The factory gives the platform of the process; the
    ///     default keeps the tests the same on every machine.
    init(
        cvGenerationUseCase: CVGeneratorUseCase, mapper: AIDraftMapper, languageData: LanguageDataPreparation, appLanguageCode: String?,
        session: AIDescriptionSession, platform: AIPlatform = .iPhoneOrIPad
    ) {
        self.cvGenerationUseCase = cvGenerationUseCase
        self.mapper = mapper
        self.languageData = languageData
        self.appLanguageCode = appLanguageCode
        self.platform = platform
        self.session = session
        self.prompt = session.text
    }

    // MARK: - Description

    var characterLimit: Int { CVGenerationLimits.maximumDescriptionLength }

    var characterCount: Int { prompt.count }

    var isOverCharacterLimit: Bool { characterCount > characterLimit }

    var canGenerate: Bool {
        let hasText = !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText && !isOverCharacterLimit && !isGenerating
    }

    // MARK: - Generation

    /// Starts a generation that `cancel()` can stop. The screen is busy at once, before the task first runs, and
    /// a `cancel()` right after this call stops the generation before it reaches the model.
    func startGenerating() {
        guard canGenerate else { return }
        let generation = begin()
        generationTask = Task { await run(generation) }
    }

    func generateCV() async {
        guard canGenerate else { return }
        await run(begin())
    }

    private func begin() -> Generation {
        let generation = Generation(request: CVGenerationRequest(userPrompt: prompt, fallbackLanguageCode: appLanguageCode))
        activeGeneration = generation.id
        isGenerating = true
        errorMessage = ""
        return generation
    }

    private func run(_ generation: Generation) async {
        guard mayAct(generation) else { return finish(generation) }

        do {
            let generated = try await generateWithLanguageData(generation)
            guard mayAct(generation) else { return finish(generation) }
            draft = mapper.map(generated, writtenIn: generation.request.userPrompt)
            // The draft goes to the editor and this creation is complete: the next one starts with an empty description
            session?.text = ""
            session = nil
        } catch is CancellationError {
            // Neither an error nor a draft; cancel() has already reset the screen.
        } catch {
            guard mayAct(generation) else { return finish(generation) }
            errorMessage = message(for: error)
        }

        finish(generation)
    }

    /// The draft of `generation`. When the device has not got the language data that grounding the description needs, the system is
    /// asked for it while the screen stays busy, and once the data is there the draft is generated once more, without another tap.
    /// Only once: data the device still lacks then, or that does not come, ends as `languageDataUnavailable`.
    private func generateWithLanguageData(_ generation: Generation) async throws -> GeneratedDraft {
        do {
            return try await cvGenerationUseCase.generateCV(from: generation.request)
        } catch CVGenerationError.languageDataUnavailable(let language) {
            guard mayAct(generation) else { throw CancellationError() }
            guard await languageData.prepare(language: language) == .available else {
                throw CVGenerationError.languageDataUnavailable(languageCode: language)
            }
            guard mayAct(generation) else { throw CancellationError() }
            return try await cvGenerationUseCase.generateCV(from: generation.request)
        }
    }

    /// The generation still owns the screen, and nothing has cancelled its task.
    private func mayAct(_ generation: Generation) -> Bool {
        activeGeneration == generation.id && !Task.isCancelled
    }

    /// Returns the screen to idle, unless a newer generation or `cancel()` has taken over.
    private func finish(_ generation: Generation) {
        guard activeGeneration == generation.id else { return }
        activeGeneration = nil
        isGenerating = false
    }

    /// Stops the running generation, if any, and returns the screen to its idle state.
    func cancel() {
        generationTask?.cancel()
        generationTask = nil
        activeGeneration = nil
        isGenerating = false
    }

    func clearError() {
        errorMessage = ""
    }

    private func message(for error: Error) -> String {
        // An error the generator did not type comes from the system, not from the description
        let key = ((error as? CVGenerationError) ?? .serviceFailed).messageKey(on: platform)
        return key.localized
    }
}
