import SwiftUI
import PrestoCVCore

struct TemplateSelectionView: View {
    @EnvironmentObject var router: AppRouter
    @StateObject private var viewModel: TemplateSelectionViewModel
    
    init(viewModel: TemplateSelectionViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if !viewModel.errorMessage.isEmpty {
                errorView
            } else {
                templateListView
            }
        }
        .navigationTitle("Choose Template")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadTemplates()
        }
        .alert("Error", isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
            Button("OK") {
                viewModel.errorMessage = ""
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        LoadingView.fullscreen(message: "Loading templates...")
    }
    
    private var errorView: some View {
        ErrorView.generic(
            message: viewModel.errorMessage,
            onRetry: {
                Task {
                    await viewModel.loadTemplates()
                }
            }
        )
    }
    
    private var templateListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.lg) {
                Section(header: templatesHeader) {
                    ForEach(viewModel.templates) { template in
                        TemplateCardView(
                            template: template,
                            onTap: {
                                router.navigate(to: .cvEditor(cvId: nil))
                            }
                        )
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
    }
    
    private var templatesHeader: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Select a Template")
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
            .shadow(color: DesignTokens.Colors.shadow, radius: DesignTokens.Shadow.radius)
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
            let templateRepository = try container.makeTemplateRepository()
            return TemplateSelectionViewModel(templateRepository: templateRepository)
        } catch {
            fatalError("Failed to create mock view model: \(error)")
        }
    }
}