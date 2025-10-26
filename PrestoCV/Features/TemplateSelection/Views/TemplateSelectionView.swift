import SwiftUI
import PrestoCVCore

struct TemplateSelectionView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: NewTemplateSelectionViewModel
    let isAIGenerationAvailable: Bool

    init(viewModel: NewTemplateSelectionViewModel, isAIGenerationAvailable: Bool = false) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.isAIGenerationAvailable = isAIGenerationAvailable
    }
    
    var body: some View {
        ViewStateContainer(
            viewState: viewModel.viewState,
            loadingMessage: "template.loading".asLoclizedKey,
            onRetry: viewModel.loadTemplates
        ) { templates in
            templateListView
        }
        .overlay(
            viewModel.isCreatingCV ? LoadingView.fullscreen(message: "cv.creating".asLoclizedKey) : nil
        )
        .navigationTitle("template.choose.title".localized)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadTemplates()
        }
        .alert("common.error".localized, isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
            Button("common.ok".localized) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - View Components
    
    private var templateListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.lg) {
                // Create New Section
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
                
                // Sample Templates Section
                if !viewModel.templates.isEmpty {
                    Section(header:
                        SectionHeaderView(
                            title: "template.sample.title".localized,
                            subtitle: "template.sample.subtitle".localized,
                            titleStyle: .title1,
                            subtitleStyle: .body
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, DesignTokens.Spacing.sm)
                    ) {
                        ForEach(viewModel.templates) { template in
                            TemplateCardView(
                                template: template,
                                onTap: {
                                    let cvModel = viewModel.createCVFromTemplate(template)
                                    router.navigateToEditorWithTemplate(cvModel)
                                }
                            )
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
    }
    
    
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

// MARK: - Template Card Views

/// Old card view for CVModel (will be removed in Step 13)
private struct OldTemplateCardView: View {
    let template: CVModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            CardView(padding: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    // Template preview image
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .fill(DesignTokens.Colors.backgroundSecondary)
                        .aspectRatio(1.0, contentMode: .fit)
                        .overlay(
                            Image(systemName: "doc.text")
                                .font(DesignTokens.IconSize.hero.font)
                                .foregroundColor(DesignTokens.Colors.secondary)
                        )

                    // Template info
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        Text(template.name.isEmpty ? "template.default.name".localized : template.name)
                            .typography(.headline)
                            .foregroundColor(DesignTokens.Colors.primary)

                        Text("template.tags".localized)
                            .typography(.caption1)
                            .foregroundColor(DesignTokens.Colors.secondary)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// New card view for TemplateDisplayModel with preview images
private struct TemplateCardView: View {
    let template: TemplateDisplayModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            CardView(padding: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    // Template preview image
                    if let previewURL = template.previewURL {
                        AsyncImage(url: previewURL) { phase in
                            switch phase {
                            case .empty:
                                // Loading placeholder
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                                    .fill(DesignTokens.Colors.backgroundSecondary)
                                    .aspectRatio(1.0, contentMode: .fit)
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                    )
                            case .success(let image):
                                // Successfully loaded image
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1.0, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md))
                            case .failure:
                                // Failed to load - show fallback icon
                                fallbackPreview
                            @unknown default:
                                fallbackPreview
                            }
                        }
                    } else {
                        // No preview URL - show fallback icon
                        fallbackPreview
                    }

                    // Template info
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        Text(template.name)
                            .typography(.headline)
                            .foregroundColor(DesignTokens.Colors.primary)

                        Text(template.description)
                            .typography(.caption1)
                            .foregroundColor(DesignTokens.Colors.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var fallbackPreview: some View {
        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
            .fill(DesignTokens.Colors.backgroundSecondary)
            .aspectRatio(1.0, contentMode: .fit)
            .overlay(
                Image(systemName: "doc.text")
                    .font(DesignTokens.IconSize.hero.font)
                    .foregroundColor(DesignTokens.Colors.secondary)
            )
    }
}

// MARK: - Previews

struct TemplateSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TemplateSelectionView(viewModel: createMockViewModel())
        }
        .environmentObject(AppRouter())
    }

    private static func createMockViewModel() -> NewTemplateSelectionViewModel {
        let container = DependencyContainer()
        let factory = ViewModelFactory(dependencyContainer: container)
        do {
            return try factory.makeTemplateSelectionViewModel()
        } catch {
            fatalError("Failed to create mock view model: \(error)")
        }
    }
}
