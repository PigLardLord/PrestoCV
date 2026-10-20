import Combine
import Foundation
import PrestoCVCore
import CVGeneratorAI
import enum PrestoCVDomain.ExampleDraft
import os

private let newCVLogger = Logger(subsystem: "com.PigLardLord.prestocv", category: "new-cv")

/// Reports whether AI drafting can run now. It is read again whenever the screen may have been away.
typealias AIAvailabilityProvider = @MainActor () -> AIAvailability

/// The wait between two reads of an availability that is still changing. It throws when the wait is cancelled.
typealias AIAvailabilityPause = @MainActor () async throws -> Void

/// The ways to start a new CV that the first run and the "New CV" screen offer: an AI draft, which is dimmed with the
/// reason where it cannot be made now, a blank CV, the example CVs, and a CV the person already has, pasted or from a
/// PDF.
@MainActor
final class NewCVChoicesViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var aiEntry: AIEntry
    @Published private(set) var samples: [CVModel] = []

    // MARK: - Private Properties
    private let aiAvailability: AIAvailabilityProvider
    private let pause: AIAvailabilityPause
    private let isAIShipped: Bool
    private let platform: AIPlatform
    private let sampleRepository: SampleCVRepositoryProtocol

    /// How long the screen waits before it reads again whether the model has finished downloading.
    nonisolated static let downloadCheckInterval: Duration = .seconds(5)

    // MARK: - Initialization

    /// - Parameter platform: Where the app runs. The factory gives the platform of the process; the default keeps the
    ///   tests and the previews the same on every machine.
    init(
        aiAvailability: @escaping AIAvailabilityProvider,
        sampleRepository: SampleCVRepositoryProtocol,
        pause: @escaping AIAvailabilityPause,
        isAIShipped: Bool = AIFeature.isShipped,
        platform: AIPlatform = .iPhoneOrIPad
    ) {
        self.aiAvailability = aiAvailability
        self.sampleRepository = sampleRepository
        self.pause = pause
        self.isAIShipped = isAIShipped
        self.platform = platform
        self.aiEntry = AIEntry(availability: aiAvailability(), platform: platform, isShipped: isAIShipped)
    }

    // MARK: - Choices

    /// The ways to start, in the order the screens show them: the AI draft where `aiEntry` puts it, a blank CV, the
    /// examples once they are loaded, and the import, on every device.
    var choices: [NewCVChoice] {
        let others: [NewCVChoice] = samples.isEmpty ? [.blank, .importCV] : [.blank, .example, .importCV]
        guard let ai = aiChoice, let position = aiEntry.position else { return others }
        switch position {
        case .first: return [ai] + others
        case .last: return others + [ai]
        }
    }

    private var aiChoice: NewCVChoice? {
        switch aiEntry {
        case .available: return .aiDraft
        case .disabled(let reason): return .aiDraftUnavailable(reason)
        case .hidden: return nil
        }
    }

    // MARK: - AI Drafting

    /// Reads whether AI drafting can run again, for example after the person turned Apple Intelligence on in Settings.
    func refreshAIAvailability() {
        aiEntry = AIEntry(availability: aiAvailability(), platform: platform, isShipped: isAIShipped)
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

    // MARK: - Blank CV

    /// The CV the editor opens for a blank start: empty, with an identity of its own. Nothing is stored until the
    /// person saves it.
    func makeBlankDraft() -> CVModel {
        CVModel()
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

    /// The CV the editor opens for a sample: its content under a new identity, with what `ExampleDraft` leaves blank.
    /// Nothing is stored until the person saves it.
    func makeDraft(from sample: CVModel) -> CVModel {
        sample.copy().clearing(ExampleDraft.clearedFields)
    }
}
