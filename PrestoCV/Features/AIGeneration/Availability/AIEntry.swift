import CVGeneratorAI

/// What the first run and the "New CV" screen offer for AI drafting, given whether the model can run now and where the
/// app runs: where the entry goes, whether it works, and the texts that say so. The views render it.
enum AIEntry: Equatable {
    /// The AI draft works.
    case available
    /// The AI draft is there, dimmed, with a line that says why it cannot be used and a full explanation.
    case disabled(Reason)
    /// No AI draft: the release does not ship AI drafting (`AIFeature.isShipped`).
    case hidden

    /// Why the AI draft cannot be used.
    enum Reason: Hashable, Identifiable {
        /// The model is still downloading: the entry turns on by itself when it is ready.
        case modelStillDownloading
        /// Apple Intelligence is turned off, in the Settings of the iPhone or iPad.
        case turnOnAppleIntelligence
        /// Apple Intelligence is turned off, in the System Settings of the Mac.
        case turnOnAppleIntelligenceInSystemSettings
        /// This iPhone or iPad cannot run the model: the person can still write the CV or start from an example.
        case notOnThisDevice
        /// The system gave a reason this version does not know.
        case notAvailableRightNow

        var id: Self { self }

        /// Catalog key of the line shown in place, with the dimmed entry.
        var lineKey: String {
            switch self {
            case .modelStillDownloading: return "ai.entry.line.model_not_ready"
            case .turnOnAppleIntelligence, .turnOnAppleIntelligenceInSystemSettings: return "ai.entry.line.not_enabled"
            case .notOnThisDevice: return "ai.entry.line.not_on_this_device"
            case .notAvailableRightNow: return "ai.entry.line.unknown"
            }
        }

        /// Catalog key of the full explanation of the dimmed entry.
        var explanationKey: String {
            switch self {
            case .modelStillDownloading: return "ai.unavailable.model_not_ready"
            case .turnOnAppleIntelligence: return "ai.unavailable.not_enabled"
            case .turnOnAppleIntelligenceInSystemSettings: return "ai.unavailable.not_enabled.mac"
            case .notOnThisDevice: return "ai.unavailable.not_on_this_device"
            case .notAvailableRightNow: return "ai.unavailable.unknown"
            }
        }
    }

    init(availability: AIAvailability, platform: AIPlatform, isShipped: Bool = AIFeature.isShipped) {
        guard isShipped else {
            self = .hidden
            return
        }
        switch (availability, platform) {
        case (.available, _):
            self = .available
        case (.unavailable(.modelNotReady), _):
            self = .disabled(.modelStillDownloading)
        case (.unavailable(.appleIntelligenceNotEnabled), .iPhoneOrIPad):
            self = .disabled(.turnOnAppleIntelligence)
        case (.unavailable(.deviceNotEligible), .iPhoneOrIPad):
            self = .disabled(.notOnThisDevice)
        // Every Mac that runs the app can run Apple Intelligence: there the device is never the reason
        case (.unavailable(.appleIntelligenceNotEnabled), .mac), (.unavailable(.deviceNotEligible), .mac):
            self = .disabled(.turnOnAppleIntelligenceInSystemSettings)
        case (.unavailable(.unknown), _):
            self = .disabled(.notAvailableRightNow)
        }
    }

    // MARK: - Presentation

    /// Where the entry goes among the ways to start.
    enum Position: Equatable {
        /// Before the others: the AI draft works.
        case first
        /// After the ways to start that work.
        case last
    }

    /// Where the entry goes, or nil where there is none.
    var position: Position? {
        switch self {
        case .available: return .first
        case .disabled: return .last
        case .hidden: return nil
        }
    }

    /// Whether the entry is shown dimmed: it cannot draft, and it says why.
    var isDimmed: Bool {
        if case .disabled = self { return true }
        return false
    }

    /// Catalog key of the line shown with the dimmed entry.
    var lineKey: String? {
        if case .disabled(let reason) = self { return reason.lineKey }
        return nil
    }

    /// Catalog key of the full explanation of the dimmed entry.
    var explanationKey: String? {
        if case .disabled(let reason) = self { return reason.explanationKey }
        return nil
    }

    /// Catalog key of the welcome paragraph of the first run: it promises the AI draft only where it works now.
    var welcomeKey: String {
        self == .available ? "welcome.description.ai" : "welcome.description"
    }
}
