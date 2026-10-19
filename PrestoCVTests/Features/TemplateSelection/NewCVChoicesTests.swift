import Testing
import CVGeneratorAI
@testable import PrestoCV
@testable import PrestoCVCore

@MainActor
@Suite("New CV choices - what the first run and the New CV screen offer, for each availability of the model")
struct NewCVChoicesTests {

    /// A view model of a release that ships AI drafting unless told otherwise, with its examples loaded.
    private func makeViewModel(
        _ availability: AIAvailability,
        samples: [CVModel] = [CVModel(name: "Nurse")],
        isAIShipped: Bool = true
    ) async -> NewCVChoicesViewModel {
        let repository = MockSampleCVRepository()
        repository.samples = samples
        let viewModel = NewCVChoicesViewModel(aiAvailability: { availability }, sampleRepository: repository, isAIShipped: isAIShipped)
        await viewModel.loadSamples()
        return viewModel
    }

    @Test("Where the device can run the model, the AI draft leads, before a blank CV and the examples")
    func availableLeadsWithTheAIDraft() async {
        let viewModel = await makeViewModel(.available)

        #expect(viewModel.choices == [.aiDraft, .blank, .example])
        #expect(viewModel.promisesAIDraft, "The welcome may promise the AI draft")
    }

    @Test("Where Apple Intelligence is off or the model is still downloading, the AI draft comes last, off, with what to do",
          arguments: zip(
              [AIAvailability.unavailable(.appleIntelligenceNotEnabled), .unavailable(.modelNotReady)],
              [AIEntry.Explanation.turnOnAppleIntelligence, .modelStillDownloading]
          ))
    func disabledComesLastWithItsReason(availability: AIAvailability, explanation: AIEntry.Explanation) async {
        let viewModel = await makeViewModel(availability)

        #expect(viewModel.choices == [.blank, .example, .aiDraftUnavailable(explanation)])
        #expect(viewModel.promisesAIDraft, "The device can draft once the person has done what the sentence says")
    }

    @Test("Where the device cannot run the model, the AI draft comes last, off, with the sentence that it cannot draft, and AI is not promised")
    func notEligibleShowsTheAIDraftOffWithoutPromisingIt() async {
        let viewModel = await makeViewModel(.unavailable(.deviceNotEligible))

        #expect(viewModel.choices == [.blank, .example, .aiDraftUnavailable(.notOnThisDevice)])
        #expect(!viewModel.promisesAIDraft, "The welcome does not promise a draft this device cannot make")
    }

    @Test("Where the device gives a reason this version does not know, only a blank CV and the examples are offered, and AI is not promised")
    func unknownReasonOffersOnlyWhatTheDeviceDoes() async {
        let viewModel = await makeViewModel(.unavailable(.unknown))

        #expect(viewModel.choices == [.blank, .example])
        #expect(!viewModel.promisesAIDraft)
    }

    @Test("A release that does not ship AI drafting offers a blank CV and the examples only, and does not promise AI",
          arguments: [
              AIAvailability.available,
              .unavailable(.deviceNotEligible),
              .unavailable(.appleIntelligenceNotEnabled),
              .unavailable(.modelNotReady),
              .unavailable(.unknown),
          ])
    func notShippedOffersNoAI(availability: AIAvailability) async {
        let viewModel = await makeViewModel(availability, isAIShipped: false)

        #expect(viewModel.choices == [.blank, .example])
        #expect(!viewModel.promisesAIDraft)
    }

    @Test("Without examples there is no example to start from, whatever the availability",
          arguments: [AIAvailability.available, .unavailable(.appleIntelligenceNotEnabled), .unavailable(.deviceNotEligible)])
    func noExamplesNoExampleChoice(availability: AIAvailability) async {
        let viewModel = await makeViewModel(availability, samples: [])

        #expect(!viewModel.choices.contains(.example))
        #expect(viewModel.choices.contains(.blank))
    }

    /// An availability that a test can change between two reads, as turning Apple Intelligence on does.
    private final class Availability {
        var current: AIAvailability
        init(_ current: AIAvailability) { self.current = current }
    }

    @Test("Turning Apple Intelligence on brings the AI draft to the front")
    func turningAppleIntelligenceOnMovesTheAIDraftToTheFront() async {
        let availability = Availability(.unavailable(.appleIntelligenceNotEnabled))
        let repository = MockSampleCVRepository()
        repository.samples = [CVModel(name: "Nurse")]
        let viewModel = NewCVChoicesViewModel(aiAvailability: { availability.current }, sampleRepository: repository, isAIShipped: true)
        await viewModel.loadSamples()
        #expect(viewModel.choices.first == .blank)

        availability.current = .available
        viewModel.refreshAIAvailability()

        #expect(viewModel.choices == [.aiDraft, .blank, .example])
    }
}
