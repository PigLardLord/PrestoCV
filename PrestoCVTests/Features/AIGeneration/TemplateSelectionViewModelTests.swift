import Testing
import CVGeneratorAI
@testable import PrestoCV

@MainActor
@Suite("TemplateSelectionViewModel Tests - the AI card follows what the device can run now")
struct TemplateSelectionViewModelTests {

    /// An availability that a test can change between two reads, as turning Apple Intelligence on does.
    private final class Availability {
        var current: AIAvailability
        private(set) var reads = 0

        init(_ current: AIAvailability) { self.current = current }

        func read() -> AIAvailability {
            reads += 1
            return current
        }
    }

    /// The wait between two reads, without the clock: it counts the waits and can do something during one, as the
    /// model finishing its download does.
    @MainActor
    private final class Pauses {
        private(set) var count = 0
        var during: (Int) -> Void = { _ in }

        func pause() async throws {
            try Task.checkCancellation()
            count += 1
            during(count)
        }
    }

    private func makeViewModel(_ availability: Availability, pauses: Pauses) -> TemplateSelectionViewModel {
        TemplateSelectionViewModel(aiAvailability: { availability.read() }, pause: { try await pauses.pause() })
    }

    private func makeViewModel(_ availability: Availability) -> TemplateSelectionViewModel {
        makeViewModel(availability, pauses: Pauses())
    }

    @Test("The entry is read from the provider when the view model is made")
    func entryIsReadAtStart() {
        let availability = Availability(.unavailable(.appleIntelligenceNotEnabled))

        let viewModel = makeViewModel(availability)

        #expect(viewModel.aiEntry == .disabled(.turnOnAppleIntelligence))
        #expect(availability.reads == 1)
    }

    @Test("Refreshing reads the availability again, so that turning Apple Intelligence on enables the card")
    func refreshReadsAgain() {
        let availability = Availability(.unavailable(.appleIntelligenceNotEnabled))
        let viewModel = makeViewModel(availability)

        availability.current = .available
        viewModel.refreshAIAvailability()

        #expect(viewModel.aiEntry == .available)
        #expect(availability.reads == 2)
    }

    @Test("A model that finished downloading enables the card on the next refresh")
    func downloadFinishing() {
        let availability = Availability(.unavailable(.modelNotReady))
        let viewModel = makeViewModel(availability)
        #expect(viewModel.aiEntry == .disabled(.modelStillDownloading))

        availability.current = .available
        viewModel.refreshAIAvailability()

        #expect(viewModel.aiEntry == .available)
    }

    @Test("While the model downloads, the card is read again after each pause and turns on by itself when it is ready")
    func followingEnablesTheCardWhenTheDownloadEnds() async {
        let availability = Availability(.unavailable(.modelNotReady))
        let pauses = Pauses()
        pauses.during = { count in
            if count == 3 { availability.current = .available }
        }
        let viewModel = makeViewModel(availability, pauses: pauses)

        await viewModel.followAIAvailability()

        #expect(viewModel.aiEntry == .available)
        #expect(pauses.count == 3, "The reads stop once the card works")
        #expect(availability.reads == 4)
    }

    @Test("Following reads nothing again when the entry cannot change by itself",
          arguments: [AIAvailability.available, .unavailable(.deviceNotEligible), .unavailable(.appleIntelligenceNotEnabled)])
    func followingStopsAtOnceForASettledEntry(start: AIAvailability) async {
        let availability = Availability(start)
        let pauses = Pauses()
        let viewModel = makeViewModel(availability, pauses: pauses)

        await viewModel.followAIAvailability()

        #expect(pauses.count == 0)
        #expect(availability.reads == 1)
    }

    @Test("A model that stops being ready for good, on a device found not eligible, ends the reads and hides the card")
    func followingStopsAtAFinalState() async {
        let availability = Availability(.unavailable(.modelNotReady))
        let pauses = Pauses()
        pauses.during = { _ in availability.current = .unavailable(.deviceNotEligible) }
        let viewModel = makeViewModel(availability, pauses: pauses)

        await viewModel.followAIAvailability()

        #expect(viewModel.aiEntry == .hidden)
        #expect(pauses.count == 1)
    }

    @Test("When the screen goes away its task is cancelled, and the availability is not read again",
          .timeLimit(.minutes(1)))
    func cancellingEndsTheReads() async {
        let availability = Availability(.unavailable(.modelNotReady))
        let pauses = Pauses()
        // The first pause is long: only the cancellation ends it
        let viewModel = TemplateSelectionViewModel(aiAvailability: { availability.read() }, pause: {
            try await pauses.pause()
            try await Task.sleep(for: .seconds(3600))
        })

        let screen = Task { await viewModel.followAIAvailability() }
        while pauses.count == 0 { await Task.yield() }
        screen.cancel()
        await screen.value
        availability.current = .available

        #expect(availability.reads == 1, "No read after the cancellation")
        #expect(viewModel.aiEntry == .disabled(.modelStillDownloading))
    }

    @Test("A device that is not eligible has no entry, and still has none after a refresh")
    func notEligibleStaysHidden() {
        let availability = Availability(.unavailable(.deviceNotEligible))
        let viewModel = makeViewModel(availability)

        viewModel.refreshAIAvailability()

        #expect(viewModel.aiEntry == .hidden)
    }
}
