import SwiftUI

/// The full explanation of the dimmed AI draft, which a tap on it shows: the line it shows in place, then the text that
/// says why and what the person can do.
struct AIEntryExplanationView: View {
    let reason: AIEntry.Reason

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text(reason.lineKey.localized)
                        .typography(.title2)
                        .foregroundColor(DesignTokens.Colors.primary)
                        .accessibilityAddTraits(.isHeader)

                    Text(reason.explanationKey.localized)
                        .typography(.body)
                        .foregroundColor(DesignTokens.Colors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.Spacing.lg)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    BarButton(title: "common.done".localized, systemImage: "checkmark", screenTextSize: dynamicTypeSize) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Presenting

extension View {
    /// Shows the full explanation of the dimmed AI draft while `reason` is set.
    func aiEntryExplanation(for reason: Binding<AIEntry.Reason?>) -> some View {
        sheet(item: reason) { reason in
            AIEntryExplanationView(reason: reason)
        }
    }

    /// Announces the dimmed AI draft as unavailable, with its full explanation: VoiceOver reads its title, "Unavailable"
    /// and why, in one stop. It stays an enabled button, so that VoiceOver, Voice Control and Switch Control can activate
    /// it as a tap does, and see the explanation.
    func announcedAsUnavailableAIDraft(title: String, reason: AIEntry.Reason) -> some View {
        let unavailable = "ai.entry.unavailable".localized
        let explanation = reason.explanationKey.localized
        return accessibilityLabel(title)
            .accessibilityValue("\(unavailable). \(explanation)")
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    AIEntryExplanationView(reason: .notOnThisDevice)
}
#endif
