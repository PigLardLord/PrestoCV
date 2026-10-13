import SwiftUI
import PrestoCVCore

/// What the user sees before having any CV: it fills the empty state of the CV list.
struct FirstRunView: View {
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
        PrimaryButton(
            title: "onboarding.create.button".localized,
            icon: "plus.circle.fill"
        ) {
            router.navigateToEditorWithTemplate(CVModel())
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
}

// MARK: - Previews

struct FirstRunView_Previews: PreviewProvider {
    static var previews: some View {
        FirstRunView()
            .environmentObject(AppRouter())
    }
}
