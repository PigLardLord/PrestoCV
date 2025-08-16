import SwiftUI
import PrestoCVCore

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var router: AppRouter
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xxl) {
                headerSection
                contentSection
                actionSection
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .alert("Error", isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
            Button("OK") {
                viewModel.errorMessage = ""
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "doc.text.fill")
                .font(DesignTokens.IconSize.hero.font)
                .foregroundColor(DesignTokens.Colors.accent)
            
            Text("Welcome to PrestoCV")
                .typography(.title1)
                .foregroundColor(DesignTokens.Colors.primary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var contentSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Create professional CVs in minutes")
                .typography(.title2)
                .foregroundColor(DesignTokens.Colors.primary)
                .multilineTextAlignment(.center)
            
            Text("Build, customize, and export beautiful CVs tailored to your career goals. Start by creating your first CV or browse our templates.")
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
                action: viewModel.performCreateFirstCV
            )
            
            // Browse templates first
            SecondaryButton.text(title: "Browse templates first") {
                router.navigate(to: .templateSelection)
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
        OnboardingView(viewModel: createMockViewModel())
    }
    
    private static func createMockViewModel() -> OnboardingViewModel {
        let container = DependencyContainer()
        do {
            let onboardingUseCase = try container.makeOnboardingUseCase()
            let sampleRepository = try container.makeSampleCVRepository()
            return OnboardingViewModel(
                onboardingUseCase: onboardingUseCase,
                sampleRepository: sampleRepository
            )
        } catch {
            fatalError("Failed to create mock view model: \(error)")
        }
    }
}