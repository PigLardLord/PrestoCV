import SwiftUI
import PrestoCVCore
import CVGeneratorAI
import os

private let newCVLogger = Logger(subsystem: "com.PigLardLord.prestocv", category: "new-cv")

/// Reports whether AI drafting can run now. It is read again whenever the screen may have been away.
typealias AIAvailabilityProvider = @MainActor () -> AIAvailability

/// The wait between two reads of an availability that is still changing. It throws when the wait is cancelled.
typealias AIAvailabilityPause = @MainActor () async throws -> Void

/// The ways to start a new CV that the first run and the "New CV" screen offer: an AI draft where the device can run
/// it, a blank CV, and the example CVs.
@MainActor
final class NewCVChoicesViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var aiEntry: AIEntry
    @Published private(set) var samples: [CVModel] = []

    // MARK: - Private Properties
    private let aiAvailability: AIAvailabilityProvider
    private let pause: AIAvailabilityPause
    private let isAIShipped: Bool
    private let sampleRepository: SampleCVRepositoryProtocol

    /// How long the screen waits before it reads again whether the model has finished downloading.
    nonisolated static let downloadCheckInterval: Duration = .seconds(5)

    // MARK: - Initialization
    init(
        aiAvailability: @escaping AIAvailabilityProvider,
        sampleRepository: SampleCVRepositoryProtocol,
        pause: @escaping AIAvailabilityPause = { try await Task.sleep(for: NewCVChoicesViewModel.downloadCheckInterval) },
        isAIShipped: Bool = AIFeature.isShipped
    ) {
        self.aiAvailability = aiAvailability
        self.sampleRepository = sampleRepository
        self.pause = pause
        self.isAIShipped = isAIShipped
        self.aiEntry = AIEntry(availability: aiAvailability(), isShipped: isAIShipped)
    }

    // MARK: - Choices

    /// The ways to start, in the order the screens show them. The AI draft leads where it works. Where it does not
    /// work yet, it follows the choices that do, with the sentence that says what to do. The examples are there once
    /// they are loaded.
    var choices: [NewCVChoice] {
        let others: [NewCVChoice] = samples.isEmpty ? [.blank] : [.blank, .example]
        switch aiEntry {
        case .available:
            return [.aiDraft] + others
        case .disabled(let explanation):
            return others + [.aiDraftUnavailable(explanation)]
        case .hidden:
            return others
        }
    }

    /// Whether the screens may speak of AI drafting: only where the device can make a draft, now or once the person
    /// has turned Apple Intelligence on or the model has finished downloading.
    var offersAI: Bool {
        aiEntry != .hidden
    }

    // MARK: - AI Drafting

    /// Reads whether AI drafting can run again, for example after the person turned Apple Intelligence on in Settings.
    func refreshAIAvailability() {
        aiEntry = AIEntry(availability: aiAvailability(), isShipped: isAIShipped)
    }

    /// Reads the availability again after each pause for as long as the model is still downloading, so that the card
    /// turns on by itself when it is ready. It returns once the entry cannot change by itself any more (the card works,
    /// the device cannot run the model, or only the person can turn Apple Intelligence on), and as soon as the task
    /// that runs it is cancelled, as the screen's task is when the screen goes away.
    func followAIAvailability() async {
        while aiEntry == .disabled(.modelStillDownloading) {
            do {
                try await pause()
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            refreshAIAvailability()
        }
    }

    // MARK: - Examples

    /// Loads the sample CVs the person can start from. Without samples the person can still start from a blank CV.
    func loadSamples() async {
        guard samples.isEmpty else { return }

        do {
            samples = try await sampleRepository.getAllSamples()
        } catch {
            newCVLogger.error("The sample CVs were not loaded: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The examples as the sheet of examples lists them.
    var examples: [ExampleChoice] {
        samples.map { sample in
            let job = sample.personalInfo.title
            return ExampleChoice(sample: sample, title: job.isEmpty ? "cv.untitled".localized : job, summary: sample.personalInfo.profile)
        }
    }

    /// The CV the editor opens for a sample: its content under a new identity, with the details of the person
    /// the sample describes left blank. Nothing is stored until the person saves it.
    func makeDraft(from sample: CVModel) -> CVModel {
        var draft = sample.copy()
        draft.name = ""
        draft.personalInfo.name = ""
        draft.personalInfo.email = ""
        draft.personalInfo.phone = ""
        draft.personalInfo.location = ""
        draft.personalInfo.portfolio = ""
        draft.social = draft.social.map { Social(id: $0.id, platform: $0.platform, url: "") }
        return draft
    }
}
