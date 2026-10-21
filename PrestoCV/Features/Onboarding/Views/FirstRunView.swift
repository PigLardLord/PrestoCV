import SwiftUI
import PrestoCVCore

/// What the user sees before having any CV: it fills the empty state of the CV list. The import of a CV the person
/// already has leads; the AI draft, where the device shows it, the examples and a blank CV follow. At the accessibility
/// sizes and in landscape on an iPhone the ways to start come before the welcome (see `FirstRunLayout`).
struct FirstRunView: View {
    @StateObject private var viewModel: NewCVChoicesViewModel
    @EnvironmentObject var router: AppRouter
    @State private var showingExamples = false
    /// The reason of the dimmed AI draft while its full explanation is shown.
    @State private var explainedReason: AIEntry.Reason?
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
        .aiEntryExplanation(for: $explainedReason)
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
            
            Text(viewModel.aiEntry.welcomeKey.localized)
                .typography(.body)
                .foregroundColor(DesignTokens.Colors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.md)
        }
    }
    
    /// The choices in the order of the view model. The import leads, and is the primary button.
    private var actionSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ForEach(viewModel.choices, id: \.self) { choice in
                action(for: choice)
            }
        }
        .frame(maxWidth: DesignTokens.Layout.standaloneButtonWidth)
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
    
    @ViewBuilder
    private func action(for choice: NewCVChoice) -> some View {
        switch choice {
        case .importCV:
            PrimaryButton(title: "onboarding.import.button".localized, icon: "doc.on.clipboard") {
                router.navigate(to: .importCV)
            }
            .accessibilityIdentifier("firstrun.import")
        case .aiDraft:
            SecondaryButton.text(title: "onboarding.ai.button".localized, icon: "sparkles", action: openAIDraft)
        case .aiDraftUnavailable(let reason):
            unavailableAIDraft(reason)
        case .example:
            SecondaryButton.text(title: "onboarding.start_from_example".localized) {
                showingExamples = true
            }
        case .blank:
            SecondaryButton.text(title: "onboarding.create.button".localized, action: openBlankCV)
        }
    }
    
    /// The AI draft, dimmed, with the line that says why. A tap, or an activation by VoiceOver, Voice Control or Switch
    /// Control, shows the full explanation.
    private func unavailableAIDraft(_ reason: AIEntry.Reason) -> some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            SecondaryButton.text(title: "onboarding.ai.button".localized, icon: "sparkles") {
                explainedReason = reason
            }
            .opacity(DesignTokens.Opacity.subtle)
            .announcedAsUnavailableAIDraft(title: "onboarding.ai.button".localized, reason: reason)
            
            Text(reason.lineKey.localized)
                .typography(.caption1)
                .foregroundColor(DesignTokens.Colors.secondary)
                .multilineTextAlignment(.center)
                .accessibilityHidden(true)
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
    FirstRunView(viewModel: PreviewDependencies.newCVChoices())
        .environmentObject(AppRouter())
}
#endif
