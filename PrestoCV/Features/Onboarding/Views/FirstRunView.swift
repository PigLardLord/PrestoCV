import SwiftUI
import PrestoCVCore

/// What the user sees before having any CV: it fills the empty state of the CV list. Where the device can run it, the
/// AI draft leads; a blank CV and the examples follow. At the accessibility sizes and in landscape on an iPhone the
/// ways to start come before the welcome (see `FirstRunLayout`).
struct FirstRunView: View {
    @StateObject private var viewModel: NewCVChoicesViewModel
    @EnvironmentObject var router: AppRouter
    @State private var showingExamples = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    /// The view model is built once, when the view first appears, and survives every re-render of the list.
    init(viewModel: @autoclosure @escaping () -> NewCVChoicesViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xxl) {
                switch FirstRunLayout.resolve(dynamicTypeSize: dynamicTypeSize, verticalSizeClass: verticalSizeClass) {
                case .welcomeFirst:
                    headerSection
                    contentSection
                    actionSection
                case .actionsFirst:
                    actionSection
                    headerSection
                    contentSection
                }
            }
            .padding(DesignTokens.Spacing.xl)
            .frame(maxWidth: DesignTokens.Layout.readableContentWidth)
            .frame(maxWidth: .infinity)
        }
        .task {
            await viewModel.loadSamples()
        }
        .followingAIAvailability(of: viewModel)
        .exampleSelection(isPresented: $showingExamples, from: viewModel) { draft in
            router.navigateToEditorWithTemplate(draft)
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
            
            // The welcome promises the AI draft only where the device can make it
            Text(viewModel.offersAI ? "welcome.description.ai".localized : "welcome.description".localized)
                .typography(.body)
                .foregroundColor(DesignTokens.Colors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }
    
    /// The choices in the order of the view model. The one that leads is the primary button.
    private var actionSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ForEach(viewModel.choices, id: \.self) { choice in
                action(for: choice, leads: choice == viewModel.choices.first)
            }
        }
        .frame(maxWidth: DesignTokens.Layout.standaloneButtonWidth)
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
    
    @ViewBuilder
    private func action(for choice: NewCVChoice, leads: Bool) -> some View {
        switch choice {
        case .aiDraft:
            PrimaryButton(title: "onboarding.ai.button".localized, icon: "sparkles", action: openAIDraft)
        case .aiDraftUnavailable(let explanation):
            unavailableAIDraft(explanation)
        case .blank:
            if leads {
                PrimaryButton(title: "onboarding.create.button".localized, icon: "plus.circle.fill", action: openBlankCV)
            } else {
                SecondaryButton.text(title: "onboarding.create.button".localized, action: openBlankCV)
            }
        case .example:
            SecondaryButton.text(title: "onboarding.start_from_example".localized) {
                showingExamples = true
            }
        }
    }
    
    /// The AI draft, dimmed and off, with the sentence that says what to do before it can be used
    private func unavailableAIDraft(_ explanation: AIEntry.Explanation) -> some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            SecondaryButton.text(title: "onboarding.ai.button".localized, icon: "sparkles", action: openAIDraft)
                .disabled(true)
                .opacity(DesignTokens.Opacity.subtle)
                .accessibilityHint(explanation.key.localized)
            
            Text(explanation.key.localized)
                .typography(.caption1)
                .foregroundColor(DesignTokens.Colors.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Actions
    
    private func openAIDraft() {
        router.navigate(to: .aiGeneration)
    }
    
    private func openBlankCV() {
        router.navigateToEditorWithTemplate(viewModel.makeBlankDraft())
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    let viewModel = NewCVChoicesViewModel(aiAvailability: { .available }, sampleRepository: PreviewDependencies.samples)
    
    return FirstRunView(viewModel: viewModel)
        .environmentObject(AppRouter())
}
#endif
