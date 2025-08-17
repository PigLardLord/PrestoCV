import SwiftUI
import PrestoCVCore

struct TemplateSelectionView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: TemplateSelectionViewModel
    
    init(viewModel: TemplateSelectionViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ViewStateContainer(
            viewState: viewModel.viewState,
            loadingMessage: LocalizedStringKey("template.loading"),
            onRetry: viewModel.loadTemplates
        ) { templates in
            templateListView
        }
        .overlay(
            viewModel.isCreatingCV ? LoadingView.fullscreen(message: LocalizedStringKey("cv.creating")) : nil
        )
        .navigationTitle(LocalizedString("template.choose.title"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadTemplates()
        }
        .alert(LocalizedString("common.error"), isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
            Button(LocalizedString("common.ok")) {
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
                        title: LocalizedString("template.create.new"),
                        subtitle: LocalizedString("template.create.new.subtitle"),
                        titleStyle: .title1,
                        subtitleStyle: .body
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, DesignTokens.Spacing.sm)
                ) {
                    createNewCard
                }
                
                // Sample Templates Section
                if !viewModel.templates.isEmpty {
                    Section(header: 
                        SectionHeaderView(
                            title: LocalizedString("template.sample.title"),
                            subtitle: LocalizedString("template.sample.subtitle"),
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
                                    Task {
                                        let cvId = await viewModel.createCVFromTemplate(template)
                                        if let cvId = cvId {
                                            router.navigate(to: .cvEditor(cvId: cvId))
                                        }
                                    }
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
            Task {
                let cvId = await viewModel.createNewEmptyCV()
                if let cvId = cvId {
                    router.navigate(to: .cvEditor(cvId: cvId))
                }
            }
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
                        Text(LocalizedString("template.empty.title"))
                            .typography(.headline)
                            .foregroundColor(DesignTokens.Colors.primary)
                        
                        Text(LocalizedString("template.empty.description"))
                            .typography(.caption1)
                            .foregroundColor(DesignTokens.Colors.secondary)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
}

// MARK: - Template Card View

private struct TemplateCardView: View {
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
                        Text(template.name.isEmpty ? LocalizedString("template.default.name") : template.name)
                            .typography(.headline)
                            .foregroundColor(DesignTokens.Colors.primary)
                        
                        Text(LocalizedString("template.tags"))
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
            TemplateSelectionView(viewModel: createMockViewModel())
        }
        .environmentObject(AppRouter())
    }
    
    private static func createMockViewModel() -> TemplateSelectionViewModel {
        let container = DependencyContainer()
        do {
            let sampleRepository = try container.makeSampleCVRepository()
            let cvManagementUseCase = try container.makeCVManagementUseCase()
            return TemplateSelectionViewModel(
                sampleRepository: sampleRepository,
                cvManagementUseCase: cvManagementUseCase
            )
        } catch {
            fatalError("Failed to create mock view model: \(error)")
        }
    }
}
