import Testing
import CVGeneratorAI
@testable import PrestoCV

@Suite("AIEntry Tests - what the New CV screen offers for each availability of the on-device model")
struct AIEntryTests {

    @Test("A model that is available gives a working card")
    func availableGivesTheCard() {
        #expect(AIEntry(availability: .available) == .available)
    }

    @Test("Apple Intelligence turned off gives a disabled card that says how to turn it on")
    func appleIntelligenceOffGivesADisabledCard() {
        let entry = AIEntry(availability: .unavailable(.appleIntelligenceNotEnabled))

        #expect(entry == .disabled(.turnOnAppleIntelligence))
        #expect(AIEntry.Explanation.turnOnAppleIntelligence.key == "ai.unavailable.not_enabled")
    }

    @Test("A model that is still downloading gives a disabled card that says to try later")
    func modelNotReadyGivesADisabledCard() {
        let entry = AIEntry(availability: .unavailable(.modelNotReady))

        #expect(entry == .disabled(.modelStillDownloading))
        #expect(AIEntry.Explanation.modelStillDownloading.key == "ai.unavailable.model_not_ready")
    }

    @Test("A device that can never run the model gets no entry at all")
    func deviceNotEligibleGivesNoEntry() {
        #expect(AIEntry(availability: .unavailable(.deviceNotEligible)) == .hidden)
    }

    @Test("A reason this version does not know gets no entry at all")
    func unknownReasonGivesNoEntry() {
        #expect(AIEntry(availability: .unavailable(.unknown)) == .hidden)
    }

    @Test("Each explanation is a sentence in every language, not a key")
    func explanationsAreLocalized() {
        for explanation in [AIEntry.Explanation.turnOnAppleIntelligence, .modelStillDownloading] {
            #expect(explanation.key.localized != explanation.key)
        }
    }
}
