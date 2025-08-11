import SwiftUI

// MARK: - Reusable Error Component
/// A consistent error display component with configurable content and actions
/// following design system standards and accessibility best practices
struct ErrorView: View {
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
                .foregroundColor(DesignTokens.Colors.error)
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
extension ErrorView {
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

// MARK: - Common Error States
extension ErrorView {
    
    /// Generic network or general error state
    static func generic(
        title: String = "Something Went Wrong",
        message: String = "We encountered an unexpected error. Please try again.",
        onRetry: @escaping () -> Void
    ) -> ErrorView {
        ErrorView(
            icon: "exclamationmark.triangle",
            title: title,
            message: message,
            primaryAction: ActionButton(
                title: "Try Again",
                action: onRetry
            )
        )
    }
    
    /// Network connectivity error state
    static func network(
        message: String = "Please check your internet connection and try again.",
        onRetry: @escaping () -> Void
    ) -> ErrorView {
        ErrorView(
            icon: "wifi.exclamationmark",
            title: "Connection Error",
            message: message,
            primaryAction: ActionButton(
                title: "Try Again",
                icon: "arrow.clockwise",
                action: onRetry
            )
        )
    }
    
    /// Resource not found error state
    static func notFound(
        title: String = "Not Found",
        message: String = "The requested resource could not be found.",
        onRetry: @escaping () -> Void
    ) -> ErrorView {
        ErrorView(
            icon: "magnifyingglass",
            title: title,
            message: message,
            primaryAction: ActionButton(
                title: "Go Back",
                icon: "arrow.left",
                action: onRetry
            )
        )
    }
}

// MARK: - Previews
struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Generic error
            ErrorView.generic(onRetry: {})
                .previewDisplayName("Generic Error")
            
            // Network error
            ErrorView.network(onRetry: {})
                .previewDisplayName("Network Error")
            
            // Not found error
            ErrorView.notFound(onRetry: {})
                .previewDisplayName("Not Found")
            
            // Custom error with actions
            ErrorView(
                icon: "lock.shield",
                title: "Access Denied",
                message: "You don't have permission to view this content.",
                primaryAction: ErrorView.ActionButton(
                    title: "Request Access",
                    icon: "envelope",
                    action: {}
                ),
                secondaryAction: ErrorView.ActionButton(
                    title: "Contact Support",
                    action: {}
                )
            )
            .previewDisplayName("Custom with Actions")
        }
        .previewLayout(.device)
        .preferredColorScheme(.light)
    }
}