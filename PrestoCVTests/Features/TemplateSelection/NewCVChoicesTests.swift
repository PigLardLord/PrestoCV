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
        isAIShipped: Bool = true,
        platform: AIPlatform = .iPhoneOrIPad
    ) async -> NewCVChoicesViewModel {
        let repository = MockSampleCVRepository()
        repository.samples = samples
        let viewModel = NewCVChoicesViewModel(
            aiAvailability: { availability }, sampleRepository: repository, isAIShipped: isAIShipped, platform: platform
        )
        await viewModel.loadSamples()
        return viewModel
    }

    @Test("Where the device can run the model, the AI draft leads, before a blank CV, the examples and the import, and the welcome promises it")
    func availableLeadsWithTheAIDraft() async {
        let viewModel = await makeViewModel(.available)

        #expect(viewModel.choices == [.aiDraft, .blank, .example, .importCV])
        #expect(viewModel.aiEntry.welcomeKey == "welcome.description.ai")
    }

    @Test("Where the AI draft cannot be made now, it comes last, dimmed, with its reason, and the welcome does not promise it",
          arguments: zip(
              [
                  AIAvailability.unavailable(.modelNotReady), .unavailable(.appleIntelligenceNotEnabled),
                  .unavailable(.deviceNotEligible), .unavailable(.unknown),
              ],
              [
                  AIEntry.Reason.modelStillDownloading, .turnOnAppleIntelligence, .notOnThisDevice, .notAvailableRightNow,
              ]
          ))
    func unavailableComesLastWithItsReason(availability: AIAvailability, reason: AIEntry.Reason) async {
        let viewModel = await makeViewModel(availability)

        #expect(viewModel.choices == [.blank, .example, .importCV, .aiDraftUnavailable(reason)])
        #expect(viewModel.aiEntry.welcomeKey == "welcome.description")
    }

    @Test("On a Mac, a device found not eligible gets the AI draft last with the way to turn it on in System Settings")
    func theMacPointsToSystemSettings() async {
        let viewModel = await makeViewModel(.unavailable(.deviceNotEligible), platform: .mac)

        #expect(viewModel.choices == [.blank, .example, .importCV, .aiDraftUnavailable(.turnOnAppleIntelligenceInSystemSettings)])
        #expect(viewModel.aiEntry.explanationKey == "ai.unavailable.not_enabled.mac")
    }

    @Test("A release that does not ship AI drafting offers a blank CV, the examples and the import, and does not promise AI",
          arguments: [
              AIAvailability.available,
              .unavailable(.deviceNotEligible),
              .unavailable(.appleIntelligenceNotEnabled),
              .unavailable(.modelNotReady),
              .unavailable(.unknown),
          ])
    func notShippedOffersNoAI(availability: AIAvailability) async {
        let viewModel = await makeViewModel(availability, isAIShipped: false)

        #expect(viewModel.choices == [.blank, .example, .importCV])
        #expect(viewModel.aiEntry.welcomeKey == "welcome.description")
    }

    @Test("Without examples there is no example to start from, whatever the availability",
          arguments: [AIAvailability.available, .unavailable(.appleIntelligenceNotEnabled), .unavailable(.deviceNotEligible)])
    func noExamplesNoExampleChoice(availability: AIAvailability) async {
        let viewModel = await makeViewModel(availability, samples: [])

        #expect(!viewModel.choices.contains(.example))
        #expect(viewModel.choices.contains(.blank))
        #expect(viewModel.choices.contains(.importCV), "A CV the person has can be imported without examples")
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

        #expect(viewModel.choices == [.aiDraft, .blank, .example, .importCV])
    }
}
