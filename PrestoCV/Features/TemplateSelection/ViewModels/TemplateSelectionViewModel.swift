import SwiftUI
import CVGeneratorAI

/// Reports whether AI drafting can run now. It is read again whenever the screen may have been away.
typealias AIAvailabilityProvider = @MainActor () -> AIAvailability

/// The wait between two reads of an availability that is still changing. It throws when the wait is cancelled.
typealias AIAvailabilityPause = @MainActor () async throws -> Void

/// What the "New CV" screen shows for the AI card.
@MainActor
final class TemplateSelectionViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published private(set) var aiEntry: AIEntry

    // MARK: - Private Properties
    private let aiAvailability: AIAvailabilityProvider
    private let pause: AIAvailabilityPause
    private let isAIShipped: Bool

    /// How long the screen waits before it reads again whether the model has finished downloading.
    nonisolated static let downloadCheckInterval: Duration = .seconds(5)

    // MARK: - Initialization
    init(
        aiAvailability: @escaping AIAvailabilityProvider,
        pause: @escaping AIAvailabilityPause = { try await Task.sleep(for: TemplateSelectionViewModel.downloadCheckInterval) },
        isAIShipped: Bool = AIFeature.isShipped
    ) {
        self.aiAvailability = aiAvailability
        self.pause = pause
        self.isAIShipped = isAIShipped
        self.aiEntry = AIEntry(availability: aiAvailability(), isShipped: isAIShipped)
    }

    // MARK: - Public Methods

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
}
