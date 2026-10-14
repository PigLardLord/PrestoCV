import SwiftUI
import PrestoCVCore

/// What the user sees before having any CV: it fills the empty state of the CV list.
struct FirstRunView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject var router: AppRouter
    @State private var showingExamples = false
    /// The draft the user picked. The editor opens once the sheet is gone, because a screen pushed while a sheet is leaving is lost.
    @State private var pendingDraft: CVModel?
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xxl) {
                headerSection
                contentSection
                actionSection
            }
            .padding(DesignTokens.Spacing.xl)
            .frame(maxWidth: DesignTokens.Layout.readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        .task {
            await viewModel.loadSamples()
        }
        .sheet(isPresented: $showingExamples, onDismiss: openPendingDraft) {
            ExampleSelectionView(samples: viewModel.samples) { sample in
                pendingDraft = viewModel.makeDraft(from: sample)
                showingExamples = false
            }
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
            PrimaryButton(
                title: "onboarding.create.button".localized,
                icon: "plus.circle.fill"
            ) {
                router.navigateToEditorWithTemplate(CVModel())
            }
            
            if !viewModel.samples.isEmpty {
                SecondaryButton.text(title: "onboarding.start_from_example".localized) {
                    showingExamples = true
                }
            }
        }
        .frame(maxWidth: DesignTokens.Layout.standaloneButtonWidth)
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
    
    private func openPendingDraft() {
        guard let draft = pendingDraft else { return }
        pendingDraft = nil
        router.navigateToEditorWithTemplate(draft)
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    let container = DependencyContainer()
    let viewModel = OnboardingViewModel(
        onboardingUseCase: try! container.makeOnboardingUseCase(),
        sampleRepository: try! container.makeSampleCVRepository()
    )
    
    return FirstRunView(viewModel: viewModel)
        .environmentObject(AppRouter())
}
#endif
