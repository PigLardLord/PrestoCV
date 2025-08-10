import SwiftUI
import PrestoCVCore

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var router: AppRouter
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Spacer()
            
            // Welcome Section
            welcomeSection
            
            // Action Section
            actionSection
            
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .background(DesignTokens.Colors.background)
        .navigationTitle("Welcome")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var welcomeSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "doc.text.fill")
                .font(DesignTokens.IconSize.hero.font)
                .foregroundColor(DesignTokens.Colors.accent)
            
            Text("Welcome to PrestoCV")
                .typography(.largeTitle)
                .foregroundColor(DesignTokens.Colors.primary)
                .multilineTextAlignment(.center)
            
            Text("Create professional CVs easily and manage all your career documents in one place.")
                .typography(.body)
                .foregroundColor(DesignTokens.Colors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Create First CV Button
            PrimaryButton(
                title: viewModel.isCreatingCV ? "Creating..." : "Create Your First CV",
                icon: viewModel.isCreatingCV ? nil : "plus.circle.fill",
                isLoading: viewModel.isCreatingCV,
                action: {
                    Task {
                        await viewModel.createFirstCV()
                        // Navigation will be handled automatically via state change
                    }
                }
            )
            
            // Skip for now - placeholder for future feature
            SecondaryButton.text(title: "Skip for now") {
                router.replace(with: .cvList)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
}

// MARK: - Error Handling

extension OnboardingView {
    private var errorAlert: some View {
        Text("Error Alert - TODO")
    }
}

// MARK: - Previews

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            OnboardingView(viewModel: createMockViewModel())
        }
        .environmentObject(AppRouter())
    }
    
    private static func createMockViewModel() -> OnboardingViewModel {
        // This is a simplified mock for preview purposes
        // In a real implementation, we'd want proper mock dependencies
        let container = DependencyContainer()
        do {
            let onboardingUseCase = try container.makeOnboardingUseCase()
            let templateRepository = try container.makeTemplateRepository()
            return OnboardingViewModel(
                onboardingUseCase: onboardingUseCase,
                templateRepository: templateRepository
            )
        } catch {
            fatalError("Failed to create mock view model: \(error)")
        }
    }
}