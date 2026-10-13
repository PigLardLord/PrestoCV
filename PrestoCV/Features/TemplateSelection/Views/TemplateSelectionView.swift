import SwiftUI
import PrestoCVCore

/// The "New CV" screen: start from a blank CV or, where available, from an AI draft.
/// Choosing the design of the PDF happens in the export sheet.
struct TemplateSelectionView: View {
    @EnvironmentObject var router: AppRouter
    let isAIGenerationAvailable: Bool

    init(isAIGenerationAvailable: Bool = false) {
        self.isAIGenerationAvailable = isAIGenerationAvailable
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

                    if isAIGenerationAvailable {
                        aiGenerationCard
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .navigationTitle("cv.new".localized)
        .navigationBarTitleDisplayMode(.large)
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
                        .aspectRatio(1.0, contentMode: .fit)
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
                        .aspectRatio(1.0, contentMode: .fit)
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
            TemplateSelectionView(isAIGenerationAvailable: true)
        }
        .environmentObject(AppRouter())
    }
}
