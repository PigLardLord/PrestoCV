import Testing
import CVGeneratorAI
@testable import PrestoCV

@Suite("AIEntry Tests - what the New CV screen offers for each availability of the on-device model")
struct AIEntryTests {

    @Test("A model that is available gives a working card")
    func availableGivesTheCard() {
        #expect(AIEntry(availability: .available, isShipped: true) == .available)
    }

    @Test("Apple Intelligence turned off gives a disabled card that says how to turn it on")
    func appleIntelligenceOffGivesADisabledCard() {
        let entry = AIEntry(availability: .unavailable(.appleIntelligenceNotEnabled), isShipped: true)

        #expect(entry == .disabled(.turnOnAppleIntelligence))
        #expect(AIEntry.Explanation.turnOnAppleIntelligence.key == "ai.unavailable.not_enabled")
    }

    @Test("A model that is still downloading gives a disabled card that says to try later")
    func modelNotReadyGivesADisabledCard() {
        let entry = AIEntry(availability: .unavailable(.modelNotReady), isShipped: true)

        #expect(entry == .disabled(.modelStillDownloading))
        #expect(AIEntry.Explanation.modelStillDownloading.key == "ai.unavailable.model_not_ready")
    }

    @Test("A device that cannot run the model gives a disabled card that says so, and how to start without it")
    func deviceNotEligibleGivesADisabledCard() {
        let entry = AIEntry(availability: .unavailable(.deviceNotEligible), isShipped: true)

        #expect(entry == .disabled(.notOnThisDeviceYet))
        #expect(AIEntry.Explanation.notOnThisDeviceYet.key == "ai.unavailable.not_on_this_device_yet")
    }

    @Test("A reason this version does not know gets no entry at all")
    func unknownReasonGivesNoEntry() {
        #expect(AIEntry(availability: .unavailable(.unknown), isShipped: true) == .hidden)
    }

    @Test("The kill switch hides the card whatever the availability", arguments: [
        AIAvailability.available,
        .unavailable(.deviceNotEligible),
        .unavailable(.appleIntelligenceNotEnabled),
        .unavailable(.modelNotReady),
        .unavailable(.unknown),
    ])
    func killSwitchHidesCard(availability: AIAvailability) {
        #expect(AIEntry(availability: availability, isShipped: false) == .hidden)
    }

    @Test("Each explanation is a sentence in every language, not a key")
    func explanationsAreLocalized() {
        for explanation in [AIEntry.Explanation.turnOnAppleIntelligence, .modelStillDownloading, .notOnThisDeviceYet] {
            #expect(explanation.key.localized != explanation.key)
        }
    }
}
