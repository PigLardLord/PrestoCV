import SwiftUI

// MARK: - Error View Component
/// A reusable error display component with consistent styling and actions
/// for handling various error states throughout the app
struct ErrorView: View {
    let title: String
    let message: String
    let icon: String
    let primaryAction: ActionButton?
    let secondaryAction: ActionButton?
    let style: Style
    
    init(
        title: String = "Something Went Wrong",
        message: String,
        icon: String = "exclamationmark.triangle",
        primaryAction: ActionButton? = nil,
        secondaryAction: ActionButton? = nil,
        style: Style = .fullscreen
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: style.contentSpacing) {
            if style.showsSpacer {
                Spacer()
            }
            
            // Error Icon
            Image(systemName: icon)
                .font(style.iconFont)
                .foregroundColor(iconColor)
                .accessibilityHidden(true)
            
            // Content
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .typography(style.titleTypography)
                    .foregroundColor(DesignTokens.Colors.primary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .typography(style.messageTypography)
                    .foregroundColor(DesignTokens.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, style.horizontalPadding)
            }
            
            // Actions
            if let primaryAction = primaryAction {
                VStack(spacing: DesignTokens.Spacing.md) {
                    if style == .inline {
                        SecondaryButton(
                            title: primaryAction.title,
                            icon: primaryAction.icon,
                            style: .compact,
                            action: primaryAction.action
                        )
                    } else {
                        PrimaryButton(
                            title: primaryAction.title,
                            icon: primaryAction.icon,
                            action: primaryAction.action
                        )
                        .padding(.horizontal, DesignTokens.Spacing.xxl)
                    }
                    
                    if let secondaryAction = secondaryAction {
                        SecondaryButton(
                            title: secondaryAction.title,
                            icon: secondaryAction.icon,
                            style: .text,
                            action: secondaryAction.action
                        )
                    }
                }
            }
            
            if style.showsSpacer {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: style.fillsContainer ? .infinity : nil)
        .padding(style.containerPadding)
        .background(style.backgroundColor)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error: \(title). \(message)")
    }
    
    // MARK: - Style Options
    enum Style {
        case fullscreen  // Full screen error with spacers
        case card        // Card-style error for sections
        case inline      // Compact inline error
        case alert       // Alert-style error (compact with accent colors)
        
        var iconFont: Font {
            switch self {
            case .fullscreen: return DesignTokens.IconSize.hero.font
            case .card: return DesignTokens.IconSize.xlarge.font
            case .inline, .alert: return DesignTokens.IconSize.large.font
            }
        }
        
        var titleTypography: DesignTokens.Typography {
            switch self {
            case .fullscreen, .card: return .title2
            case .inline, .alert: return .headline
            }
        }
        
        var messageTypography: DesignTokens.Typography {
            switch self {
            case .fullscreen, .card: return .body
            case .inline, .alert: return .callout
            }
        }
        
        var contentSpacing: CGFloat {
            switch self {
            case .fullscreen: return DesignTokens.Spacing.xl
            case .card: return DesignTokens.Spacing.lg
            case .inline, .alert: return DesignTokens.Spacing.md
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .fullscreen: return DesignTokens.Spacing.md
            case .card, .inline, .alert: return DesignTokens.Spacing.sm
            }
        }
        
        var containerPadding: CGFloat {
            switch self {
            case .fullscreen: return DesignTokens.Spacing.xl
            case .card: return DesignTokens.Spacing.lg
            case .inline, .alert: return DesignTokens.Spacing.md
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .alert: return DesignTokens.Colors.error.opacity(0.1)
            default: return .clear
            }
        }
        
        var showsSpacer: Bool {
            switch self {
            case .fullscreen: return true
            default: return false
            }
        }
        
        var fillsContainer: Bool {
            switch self {
            case .fullscreen: return true
            default: return false
            }
        }
    }
    
    private var iconColor: Color {
        switch style {
        case .alert: return DesignTokens.Colors.error
        default: return DesignTokens.Colors.secondary
        }
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
    
    /// Network connectivity error
    static func networkError(onRetry: @escaping () -> Void) -> ErrorView {
        ErrorView(
            title: "No Internet Connection",
            message: "Please check your connection and try again.",
            icon: "wifi.exclamationmark",
            primaryAction: ActionButton(
                title: "Try Again",
                icon: "arrow.clockwise",
                action: onRetry
            )
        )
    }
    
    /// Loading/data fetch error
    static func loadingError(message: String, onRetry: @escaping () -> Void) -> ErrorView {
        ErrorView(
            title: "Failed to Load",
            message: message,
            icon: "exclamationmark.triangle",
            primaryAction: ActionButton(
                title: "Retry",
                icon: "arrow.clockwise",
                action: onRetry
            )
        )
    }
    
    /// Save operation error
    static func saveError(onRetry: @escaping () -> Void, onDismiss: @escaping () -> Void) -> ErrorView {
        ErrorView(
            title: "Save Failed",
            message: "Your changes could not be saved. Please try again.",
            icon: "exclamationmark.circle",
            primaryAction: ActionButton(
                title: "Try Again",
                action: onRetry
            ),
            secondaryAction: ActionButton(
                title: "Dismiss",
                action: onDismiss
            ),
            style: .card
        )
    }
    
    /// Generic error with custom message
    static func generic(
        message: String,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> ErrorView {
        ErrorView(
            message: message,
            primaryAction: onRetry.map { retry in
                ActionButton(title: "Try Again", action: retry)
            },
            secondaryAction: onDismiss.map { dismiss in
                ActionButton(title: "Dismiss", action: dismiss)
            }
        )
    }
    
    /// Inline error for forms or specific sections
    static func inline(message: String, onDismiss: (() -> Void)? = nil) -> ErrorView {
        ErrorView(
            title: "Error",
            message: message,
            icon: "exclamationmark.circle.fill",
            secondaryAction: onDismiss.map { dismiss in
                ActionButton(title: "Dismiss", action: dismiss)
            },
            style: .inline
        )
    }
}

// MARK: - Previews
struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Network error
            ErrorView.networkError(onRetry: {})
                .previewDisplayName("Network Error")
            
            // Loading error
            ErrorView.loadingError(
                message: "Unable to load your CVs. Please check your connection.",
                onRetry: {}
            )
            .previewDisplayName("Loading Error")
            
            // Save error (card style)
            ErrorView.saveError(onRetry: {}, onDismiss: {})
                .padding()
                .previewDisplayName("Save Error - Card")
                .previewLayout(.sizeThatFits)
            
            // Inline error
            VStack {
                Text("Form Content")
                ErrorView.inline(message: "Invalid email format", onDismiss: {})
                Text("More Form Content")
            }
            .padding()
            .previewDisplayName("Inline Error")
            .previewLayout(.sizeThatFits)
            
            // Alert style error
            ErrorView(
                title: "Validation Error",
                message: "Please fill in all required fields.",
                style: .alert
            )
            .padding()
            .previewDisplayName("Alert Style")
            .previewLayout(.sizeThatFits)
        }
        .preferredColorScheme(.light)
    }
}