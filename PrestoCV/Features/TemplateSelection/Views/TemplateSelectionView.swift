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
            loadingMessage: "Loading templates...",
            onRetry: viewModel.loadTemplates
        ) { templates in
            templateListView
        }
        .overlay(
            viewModel.isCreatingCV ? LoadingView.fullscreen(message: "Creating CV...") : nil
        )
        .navigationTitle("Choose Template")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadTemplates()
        }
        .alert("Error", isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
            Button("OK") {
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
                Section(header: createNewHeader) {
                    createNewCard
                }
                
                // Sample Templates Section
                if !viewModel.templates.isEmpty {
                    Section(header: templatesHeader) {
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
    
    private var createNewHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Create New")
                .typography(.title1)
                .foregroundColor(DesignTokens.Colors.primary)
            
            Text("Start with a blank canvas to create your CV from scratch.")
                .typography(.body)
                .foregroundColor(DesignTokens.Colors.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, DesignTokens.Spacing.sm)
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
                    Text("Empty CV")
                        .typography(.headline)
                        .foregroundColor(DesignTokens.Colors.primary)
                    
                    Text("Start from scratch with a blank template")
                        .typography(.caption1)
                        .foregroundColor(DesignTokens.Colors.secondary)
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.background)
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(
                color: DesignTokens.Colors.shadow,
                radius: DesignTokens.Shadow.medium.radius,
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var templatesHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Sample Templates")
                .typography(.title1)
                .foregroundColor(DesignTokens.Colors.primary)
            
            Text("Choose a template to start creating your professional CV.")
                .typography(.body)
                .foregroundColor(DesignTokens.Colors.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, DesignTokens.Spacing.sm)
    }
}

// MARK: - Template Card View

private struct TemplateCardView: View {
    let template: CVModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
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
                    Text(template.name.isEmpty ? "Default Template" : template.name)
                        .typography(.headline)
                        .foregroundColor(DesignTokens.Colors.primary)
                    
                    Text("Professional • Modern • Easy to customize")
                        .typography(.caption1)
                        .foregroundColor(DesignTokens.Colors.secondary)
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.background)
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(color: DesignTokens.Colors.shadow, radius: DesignTokens.Shadow.medium.radius)
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
