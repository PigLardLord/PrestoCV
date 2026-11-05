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
    /// The busy screen waits for the language data that the system downloads, up to `LanguageDataPreparation.bound`, and not for the
    /// model. The screen says so, because the model's "up to a minute" does not hold for this wait.
    @Published private(set) var isWaitingForLanguageData: Bool = false
    @Published private(set) var errorMessage: String = ""
    /// The generated CV, not stored yet: the editor opens it for review, with the notice it calls for, and stores it as it is.
    @Published private(set) var draft: AIDraft?
    /// The text was already a CV, and this is what the import read in it: the editor opens it as written, in place of a
    /// draft, and stores it as it is (ADR 0034).
    @Published private(set) var imported: ImportedDraft?

    /// The running generation started by `startGenerating()`, kept so `cancel()` can stop it.
    private(set) var generationTask: Task<Void, Never>?

    private let cvGenerationUseCase: CVGeneratorUseCase
    private let mapper: AIDraftMapper
    private let languageData: LanguageDataPreparation
    private let pastedCV: any PastedCVReading
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
    ///   - pastedCV: Reads a text that is already a CV with the import, before any model is asked.
    ///   - platform: Where the app runs, for the words of an unavailable model. The factory gives the platform of the process; the
    ///     default keeps the tests the same on every machine.
    init(
        cvGenerationUseCase: CVGeneratorUseCase, mapper: AIDraftMapper, languageData: LanguageDataPreparation,
        pastedCV: any PastedCVReading, appLanguageCode: String?, session: AIDescriptionSession, platform: AIPlatform = .iPhoneOrIPad
    ) {
        self.cvGenerationUseCase = cvGenerationUseCase
        self.mapper = mapper
        self.languageData = languageData
        self.pastedCV = pastedCV
        self.appLanguageCode = appLanguageCode
        self.platform = platform
        self.session = session
        self.prompt = session.text
    }

    // MARK: - Description

    var characterLimit: Int { CVGenerationLimits.maximumDescriptionLength }

    var characterCount: Int { prompt.count }

    var isOverCharacterLimit: Bool { characterCount > characterLimit }

    /// Generate stays on over the limit: a CV pasted whole is read by the import whatever its length, and the AI draft refuses
    /// a free description over its limit with its own message.
    var canGenerate: Bool {
        let hasText = !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText && !isGenerating
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
        isWaitingForLanguageData = false
        errorMessage = ""
        return generation
    }

    private func run(_ generation: Generation) async {
        guard mayAct(generation) else { return finish(generation) }

        if let read = pastedCV.read(generation.request.userPrompt) {
            imported = read
            // The CV goes to the editor as written and this creation is complete, as after a draft
            session?.text = ""
            session = nil
            return finish(generation)
        }

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
    /// asked for it while the screen stays busy and says so, and once the data is there the draft is generated once more, without
    /// another tap. Only once: data the device still lacks then, or that does not come, ends as `languageDataUnavailable`.
    private func generateWithLanguageData(_ generation: Generation) async throws -> GeneratedDraft {
        do {
            return try await cvGenerationUseCase.generateCV(from: generation.request)
        } catch CVGenerationError.languageDataUnavailable(let language) {
            guard mayAct(generation) else { throw CancellationError() }
            isWaitingForLanguageData = true
            let outcome = await languageData.prepare(language: language)
            // Only the generation that owns the screen changes it: a cancelled one finds `cancel()` has already reset it
            guard mayAct(generation) else { throw CancellationError() }
            isWaitingForLanguageData = false
            guard outcome == .available else {
                throw CVGenerationError.languageDataUnavailable(languageCode: language)
            }
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
        isWaitingForLanguageData = false
    }

    /// Stops the running generation, if any, and returns the screen to its idle state.
    func cancel() {
        generationTask?.cancel()
        generationTask = nil
        activeGeneration = nil
        isGenerating = false
        isWaitingForLanguageData = false
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
