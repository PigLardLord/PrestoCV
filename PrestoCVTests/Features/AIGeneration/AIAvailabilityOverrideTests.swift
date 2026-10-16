#if DEBUG
import Testing
import CVGeneratorAI
@testable import PrestoCV

private let launchValueCases: [(String, AIAvailability)] = [
    ("available", .available),
    ("deviceNotEligible", .unavailable(.deviceNotEligible)),
    ("appleIntelligenceNotEnabled", .unavailable(.appleIntelligenceNotEnabled)),
    ("modelNotReady", .unavailable(.modelNotReady)),
    ("unknown", .unavailable(.unknown)),
]

@Suite("AIAvailabilityOverride Tests")
struct AIAvailabilityOverrideTests {

    @Test("Each launch value forces its availability", arguments: launchValueCases)
    func launchValueForcesAvailability(value: String, expected: AIAvailability) {
        #expect(AIAvailabilityOverride.availability(for: value) == expected)
    }

    @Test("No value or an unrecognised value leaves the real availability alone")
    func missingOrUnknownValueIsIgnored() {
        #expect(AIAvailabilityOverride.availability(for: nil) == nil)
        #expect(AIAvailabilityOverride.availability(for: "maybe") == nil)
    }

    @Test("The value that follows the launch argument forces its availability")
    func launchArgumentIsRead() {
        let arguments = ["PrestoCV", "-AIAvailabilityOverride", "modelNotReady"]

        #expect(AIAvailabilityOverride.current(arguments: arguments) == .unavailable(.modelNotReady))
    }

    @Test("Without the launch argument, or without a value after it, the real availability is left alone")
    func missingLaunchArgumentIsIgnored() {
        #expect(AIAvailabilityOverride.current(arguments: ["PrestoCV"]) == nil)
        #expect(AIAvailabilityOverride.current(arguments: ["PrestoCV", "-AIAvailabilityOverride"]) == nil)
    }
}
#endif
