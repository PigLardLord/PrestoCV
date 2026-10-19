import Testing
import CVGeneratorAI
@testable import PrestoCV

@Suite("AIEntry Tests - where the AI draft goes, whether it works and what it says, for each availability and platform")
struct AIEntryTests {

    /// One row of the table: what an availability on a platform gives.
    struct Row: CustomTestStringConvertible, Sendable {
        let availability: AIAvailability
        let platform: AIPlatform
        let entry: AIEntry
        let position: AIEntry.Position?
        let isDimmed: Bool
        let lineKey: String?
        let explanationKey: String?
        let welcomeKey: String

        var testDescription: String { "\(availability) on \(platform)" }
    }

    static let table: [Row] = [
        // iPhone and iPad
        Row(availability: .available, platform: .iPhoneOrIPad, entry: .available, position: .first, isDimmed: false,
            lineKey: nil, explanationKey: nil, welcomeKey: "welcome.description.ai"),
        Row(availability: .unavailable(.modelNotReady), platform: .iPhoneOrIPad, entry: .disabled(.modelStillDownloading),
            position: .last, isDimmed: true, lineKey: "ai.entry.line.model_not_ready",
            explanationKey: "ai.unavailable.model_not_ready", welcomeKey: "welcome.description"),
        Row(availability: .unavailable(.appleIntelligenceNotEnabled), platform: .iPhoneOrIPad,
            entry: .disabled(.turnOnAppleIntelligence), position: .last, isDimmed: true, lineKey: "ai.entry.line.not_enabled",
            explanationKey: "ai.unavailable.not_enabled", welcomeKey: "welcome.description"),
        Row(availability: .unavailable(.deviceNotEligible), platform: .iPhoneOrIPad, entry: .disabled(.notOnThisDevice),
            position: .last, isDimmed: true, lineKey: "ai.entry.line.not_on_this_device",
            explanationKey: "ai.unavailable.not_on_this_device", welcomeKey: "welcome.description"),
        Row(availability: .unavailable(.unknown), platform: .iPhoneOrIPad, entry: .disabled(.notAvailableRightNow),
            position: .last, isDimmed: true, lineKey: "ai.entry.line.unknown", explanationKey: "ai.unavailable.unknown",
            welcomeKey: "welcome.description"),
        // The Mac: the device is never the reason, and Apple Intelligence is turned on in System Settings
        Row(availability: .available, platform: .mac, entry: .available, position: .first, isDimmed: false,
            lineKey: nil, explanationKey: nil, welcomeKey: "welcome.description.ai"),
        Row(availability: .unavailable(.modelNotReady), platform: .mac, entry: .disabled(.modelStillDownloading),
            position: .last, isDimmed: true, lineKey: "ai.entry.line.model_not_ready",
            explanationKey: "ai.unavailable.model_not_ready", welcomeKey: "welcome.description"),
        Row(availability: .unavailable(.appleIntelligenceNotEnabled), platform: .mac,
            entry: .disabled(.turnOnAppleIntelligenceInSystemSettings), position: .last, isDimmed: true,
            lineKey: "ai.entry.line.not_enabled", explanationKey: "ai.unavailable.not_enabled.mac",
            welcomeKey: "welcome.description"),
        Row(availability: .unavailable(.deviceNotEligible), platform: .mac,
            entry: .disabled(.turnOnAppleIntelligenceInSystemSettings), position: .last, isDimmed: true,
            lineKey: "ai.entry.line.not_enabled", explanationKey: "ai.unavailable.not_enabled.mac",
            welcomeKey: "welcome.description"),
        Row(availability: .unavailable(.unknown), platform: .mac, entry: .disabled(.notAvailableRightNow),
            position: .last, isDimmed: true, lineKey: "ai.entry.line.unknown", explanationKey: "ai.unavailable.unknown",
            welcomeKey: "welcome.description"),
    ]

    @Test("Each availability on each platform gives its entry, position, state and texts", arguments: table)
    func mapping(row: Row) {
        let entry = AIEntry(availability: row.availability, platform: row.platform, isShipped: true)

        #expect(entry == row.entry)
        #expect(entry.position == row.position)
        #expect(entry.isDimmed == row.isDimmed)
        #expect(entry.lineKey == row.lineKey)
        #expect(entry.explanationKey == row.explanationKey)
        #expect(entry.welcomeKey == row.welcomeKey)
    }

    @Test("The table covers every availability on every platform")
    func tableIsComplete() {
        let availabilities: [AIAvailability] = [
            .available, .unavailable(.modelNotReady), .unavailable(.appleIntelligenceNotEnabled),
            .unavailable(.deviceNotEligible), .unavailable(.unknown),
        ]
        for platform in AIPlatform.allCases {
            for availability in availabilities {
                #expect(Self.table.contains { $0.platform == platform && $0.availability == availability },
                        "\(availability) on \(platform) is missing from the table")
            }
        }
    }

    @Test("On a Mac no availability says that the device cannot draft", arguments: table.filter { $0.platform == .mac })
    func theMacNeverBlamesTheDevice(row: Row) {
        let entry = AIEntry(availability: row.availability, platform: .mac, isShipped: true)

        #expect(entry != .disabled(.notOnThisDevice))
        #expect(entry.explanationKey != "ai.unavailable.not_on_this_device")
    }

    @Test("The kill switch hides the entry whatever the availability and the platform", arguments: table)
    func killSwitchHidesTheEntry(row: Row) {
        let entry = AIEntry(availability: row.availability, platform: row.platform, isShipped: false)

        #expect(entry == .hidden)
        #expect(entry.position == nil)
        #expect(!entry.isDimmed)
        #expect(entry.welcomeKey == "welcome.description")
    }

    @Test("Each line and each explanation is a sentence in every language, not a key", arguments: [
        AIEntry.Reason.modelStillDownloading, .turnOnAppleIntelligence, .turnOnAppleIntelligenceInSystemSettings,
        .notOnThisDevice, .notAvailableRightNow,
    ])
    func textsAreLocalized(reason: AIEntry.Reason) {
        #expect(reason.lineKey.localized != reason.lineKey)
        #expect(reason.explanationKey.localized != reason.explanationKey)
    }
}
