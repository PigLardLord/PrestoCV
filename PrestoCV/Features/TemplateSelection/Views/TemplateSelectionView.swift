import SwiftUI
import PrestoCVCore

/// The "New CV" screen: start from a blank CV or, where the device can run it, from an AI draft.
/// Choosing the design of the PDF happens in the export sheet.
struct TemplateSelectionView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: TemplateSelectionViewModel
    @Environment(\.scenePhase) private var scenePhase

    /// The cards show a wide picture. A square one fills the screen of an iPad, and on an iPhone it pushes the second
    /// card, and the sentence that says why it is dimmed, out of sight.
    private let previewAspectRatio: CGFloat = 2.4

    /// The view model is built once, when the screen first appears, and survives every re-render of the parent.
    init(viewModel: @autoclosure @escaping () -> TemplateSelectionViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.lg) {
                Section(header:
                    SectionHeaderView(
                        title: "template.create.new".localized,
                        subtitle: "template.create.new.subtitle".localized,
                        titleStyle: .title1,
                        subtitleStyle: .body
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, DesignTokens.Spacing.sm)
                ) {
                    createNewCard

                    aiGenerationEntry
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .readableContentWidth()
        .screenTitle("cv.new".localized, large: true)
        // Turning Apple Intelligence on happens in Settings: the card is read again on the way back
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                viewModel.refreshAIAvailability()
            }
        }
        // While the model downloads, the card turns on by itself when it is ready. The task starts again when the
        // entry changes, and ends with the screen.
        .task(id: viewModel.aiEntry) {
            await viewModel.followAIAvailability()
        }
    }

    // MARK: - View Components

    private var createNewCard: some View {
        Button(action: {
            // For empty CV, just pass an empty CVModel - no need to load from repository
            router.navigateToEditorWithTemplate(CVModel())
        }) {
            CardView(padding: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    // Empty template preview
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .fill(DesignTokens.Colors.backgroundSecondary)
                        .aspectRatio(previewAspectRatio, contentMode: .fit)
                        .overlay(
                            Image(systemName: "plus.rectangle.on.rectangle")
                                .font(DesignTokens.IconSize.hero.font)
                                .foregroundColor(DesignTokens.Colors.primary)
                        )
                    
                    // Template info
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        Text("template.empty.title".localized)
                            .typography(.headline)
                            .foregroundColor(DesignTokens.Colors.primary)
                        
                        Text("template.empty.description".localized)
                            .typography(.caption1)
                            .foregroundColor(DesignTokens.Colors.secondary)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var aiGenerationEntry: some View {
        switch viewModel.aiEntry {
        case .available:
            aiGenerationCard
        case .disabled(let explanation):
            disabledAIGenerationCard(explanation)
        case .hidden:
            EmptyView()
        }
    }

    /// The AI card, dimmed and disabled, with the sentence that says what to do before it can be used
    private func disabledAIGenerationCard(_ explanation: AIEntry.Explanation) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            aiGenerationCard
                .disabled(true)
                .opacity(DesignTokens.Opacity.subtle)
                .accessibilityHint(explanation.key.localized)

            Text(explanation.key.localized)
                .typography(.caption1)
                .foregroundColor(DesignTokens.Colors.secondary)
        }
    }

    private var aiGenerationCard: some View {
        Button(action: {
            router.navigate(to: .aiGeneration)
        }) {
            CardView(padding: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    // AI generation preview
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    DesignTokens.Colors.accent.opacity(0.3),
                                    DesignTokens.Colors.accent.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(previewAspectRatio, contentMode: .fit)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(DesignTokens.IconSize.hero.font)
                                .foregroundColor(DesignTokens.Colors.accent)
                        )

                    // AI generation info
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Text("ai.card.title".localized)
                                .typography(.headline)
                                .foregroundColor(DesignTokens.Colors.primary)

                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundColor(DesignTokens.Colors.accent)
                        }

                        Text("ai.card.subtitle".localized)
                            .typography(.caption1)
                            .foregroundColor(DesignTokens.Colors.secondary)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

}

// MARK: - Previews

struct TemplateSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TemplateSelectionView(viewModel: TemplateSelectionViewModel(aiAvailability: { .available }))
        }
        .environmentObject(AppRouter())
    }
}
