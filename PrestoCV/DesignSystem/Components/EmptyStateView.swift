import SwiftUI

// MARK: - Reusable Empty State Component
/// A consistent empty state component with configurable content and actions
/// following design system standards and accessibility best practices
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let primaryAction: ActionButton?
    let secondaryAction: ActionButton?
    
    init(
        icon: String,
        title: String,
        message: String,
        primaryAction: ActionButton? = nil,
        secondaryAction: ActionButton? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()
            
            // Icon
            Image(systemName: icon)
                .font(DesignTokens.IconSize.hero.font)
                .foregroundColor(DesignTokens.Colors.secondary)
                .accessibilityHidden(true)
            
            // Content
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .typography(.title2)
                    .foregroundColor(DesignTokens.Colors.primary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .typography(.body)
                    .foregroundColor(DesignTokens.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.md)
            }
            
            // Actions
            if let primaryAction = primaryAction {
                VStack(spacing: DesignTokens.Spacing.md) {
                    PrimaryButton(
                        title: primaryAction.title,
                        icon: primaryAction.icon,
                        action: primaryAction.action
                    )
                    .padding(.horizontal, DesignTokens.Spacing.xxl)
                    
                    if let secondaryAction = secondaryAction {
                        SecondaryButton(
                            title: secondaryAction.title,
                            style: .text,
                            action: secondaryAction.action
                        )
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xl)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - Action Button Configuration
extension EmptyStateView {
    struct ActionButton {
        let title: String
        let icon: String?
        let action: () -> Void
        
        init(title: String, icon: String? = nil, action: @escaping () -> Void) {
            self.title = title
            self.icon = icon
            self.action = action
        }
    }
}

// MARK: - Common Empty States
extension EmptyStateView {
    
    /// Empty CVs list state
    static func noCVs(onCreateCV: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "doc.text",
            title: "empty.no_cvs_title".localized,
            message: "empty.no_cvs_message".localized,
            primaryAction: ActionButton(
                title: "empty.no_cvs_button".localized,
                icon: "plus.circle.fill",
                action: onCreateCV
            )
        )
    }
    
    /// Search results empty state
    static func noSearchResults(query: String = "") -> EmptyStateView {
        let message = query.isEmpty
            ? "empty.search_no_results_default".localized
            : "empty.search_no_results_for".localizedWithArgs(query)

        return EmptyStateView(
            icon: "magnifyingglass",
            title: "empty.search_no_results_title".localized,
            message: message
        )
    }
    
    /// Network error empty state
    static func networkError(onRetry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "wifi.exclamationmark",
            title: "error.connection_error_title".localized,
            message: "error.connection_error_message".localized,
            primaryAction: ActionButton(
                title: "common.retry".localized,
                icon: "arrow.clockwise",
                action: onRetry
            )
        )
    }

    /// Generic error state
    static func error(
        title: String = "error.generic_title".localized,
        message: String = "error.generic_message".localized,
        onRetry: @escaping () -> Void
    ) -> EmptyStateView {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: title,
            message: message,
            primaryAction: ActionButton(
                title: "common.retry".localized,
                action: onRetry
            )
        )
    }
}

// MARK: - Previews
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // No CVs state
            EmptyStateView.noCVs(onCreateCV: {})
                .previewDisplayName("No CVs")
            
            // Search results
            EmptyStateView.noSearchResults(query: "designer")
                .previewDisplayName("No Search Results")
            
            // Network error
            EmptyStateView.networkError(onRetry: {})
                .previewDisplayName("Network Error")
            
            // Custom empty state
            EmptyStateView(
                icon: "star",
                title: "Coming Soon",
                message: "This feature will be available in a future update.",
                primaryAction: EmptyStateView.ActionButton(
                    title: "Get Notified",
                    icon: "bell",
                    action: {}
                ),
                secondaryAction: EmptyStateView.ActionButton(
                    title: "Learn More",
                    action: {}
                )
            )
            .previewDisplayName("Custom with Actions")
        }
        .previewLayout(.device)
        .preferredColorScheme(.light)
    }
}