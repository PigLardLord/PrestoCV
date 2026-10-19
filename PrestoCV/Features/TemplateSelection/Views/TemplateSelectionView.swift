import SwiftUI
import PrestoCVCore

/// The "New CV" screen: start from an AI draft where the device can run it, from a blank CV, or from an example.
/// Choosing the design of the PDF happens in the export sheet.
struct TemplateSelectionView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: NewCVChoicesViewModel
    @State private var showingExamples = false

    /// The cards show a wide picture. A square one fills the screen of an iPad, and on an iPhone it pushes the second
    /// card, and the sentence that says why it is dimmed, out of sight.
    private let previewAspectRatio: CGFloat = 2.4

    /// The view model is built once, when the screen first appears, and survives every re-render of the parent.
    init(viewModel: @autoclosure @escaping () -> NewCVChoicesViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ScrollView {
            // A plain stack: in a lazy one VoiceOver reads a text even when it is hidden from it, and the sentence under
            // a dimmed card would be read twice
            VStack(spacing: DesignTokens.Spacing.lg) {
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
                    ForEach(viewModel.choices, id: \.self) { choice in
                        card(for: choice)
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .readableContentWidth()
        .screenTitle("cv.new".localized, large: true)
        .task {
            await viewModel.loadSamples()
        }
        .followingAIAvailability(of: viewModel)
        .exampleSelection(isPresented: $showingExamples, from: viewModel) { draft in
            router.navigateToEditorWithTemplate(draft)
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private func card(for choice: NewCVChoice) -> some View {
        switch choice {
        case .aiDraft:
            aiGenerationCard
        case .aiDraftUnavailable(let explanation):
            disabledAIGenerationCard(explanation)
        case .blank:
            createNewCard
        case .example:
            exampleCard
        }
    }

    private var createNewCard: some View {
        Button(action: {
            router.navigateToEditorWithTemplate(viewModel.makeBlankDraft())
        }) {
            plainCard(
                icon: "plus.rectangle.on.rectangle",
                title: "template.empty.title".localized,
                description: "template.empty.description".localized
            )
        }
        .buttonStyle(CardButtonStyle())
    }

    private var exampleCard: some View {
        Button(action: {
            showingExamples = true
        }) {
            plainCard(
                icon: "doc.on.doc",
                title: "template.example.title".localized,
                description: "template.example.description".localized
            )
        }
        .buttonStyle(CardButtonStyle())
    }

    /// A card with a plain picture of a symbol, a title and a line that says what the choice does
    private func plainCard(icon: String, title: String, description: String) -> some View {
        CardView(padding: DesignTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .fill(DesignTokens.Colors.backgroundSecondary)
                    .aspectRatio(previewAspectRatio, contentMode: .fit)
                    .overlay(
                        Image(systemName: icon)
                            .font(DesignTokens.IconSize.hero.font)
                            .foregroundColor(DesignTokens.Colors.primary)
                    )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(title)
                        .typography(.headline)
                        .foregroundColor(DesignTokens.Colors.primary)

                    Text(description)
                        .typography(.caption1)
                        .foregroundColor(DesignTokens.Colors.secondary)
                }
            }
        }
    }

    /// The AI card, dimmed and disabled, with the sentence that says why. VoiceOver reads the sentence once, with the
    /// card: its title, the sentence, then that it is dimmed.
    private func disabledAIGenerationCard(_ explanation: AIEntry.Explanation) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            aiGenerationCard
                .disabled(true)
                .opacity(DesignTokens.Opacity.subtle)
                .accessibilityValue(explanation.key.localized)

            Text(explanation.key.localized)
                .typography(.caption1)
                .foregroundColor(DesignTokens.Colors.secondary)
                .accessibilityHidden(true)
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
        .buttonStyle(CardButtonStyle())
    }

}

// MARK: - Previews

#if DEBUG
#Preview {
    let viewModel = NewCVChoicesViewModel(aiAvailability: { .available }, sampleRepository: PreviewDependencies.samples)

    return NavigationStack {
        TemplateSelectionView(viewModel: viewModel)
    }
    .environmentObject(AppRouter())
}
#endif
