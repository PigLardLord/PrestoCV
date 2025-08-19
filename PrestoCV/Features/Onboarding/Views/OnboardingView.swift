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
        .alert("common.error".localized, isPresented: .constant(!viewModel.errorMessage.isEmpty)) {
            Button("common.ok".localized) {
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
            
            Text("welcome.title".localized)
                .typography(.title1)
                .foregroundColor(DesignTokens.Colors.primary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var contentSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("welcome.subtitle".localized)
                .typography(.title2)
                .foregroundColor(DesignTokens.Colors.primary)
                .multilineTextAlignment(.center)
            
            Text("welcome.description".localized)
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
                title: viewModel.isCreatingCV ? "onboarding.creating".localized : "onboarding.create.button".localized,
                icon: viewModel.isCreatingCV ? nil : "plus.circle.fill",
                isLoading: viewModel.isCreatingCV,
                action: viewModel.performCreateFirstCV
            )
            
            // Browse templates first
            SecondaryButton.text(title: "onboarding.browse.templates".localized) {
                router.navigate(to: .templateSelection)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
}

// MARK: - Error Handling

extension OnboardingView {
    private var errorAlert: some View {
        Text("error.alert.todo".localized)
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