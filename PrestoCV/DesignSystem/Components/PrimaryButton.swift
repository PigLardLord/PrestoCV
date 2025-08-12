import SwiftUI

// MARK: - Primary Button Component
/// A primary action button with loading state and icon support following design system standards
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let isDisabled: Bool
    let size: Size
    let action: () -> Void
    
    enum Size {
        case normal
        case large
        case small
        
        var verticalPadding: CGFloat {
            switch self {
            case .normal: return DesignTokens.Spacing.sm
            case .large: return DesignTokens.Spacing.md
            case .small: return DesignTokens.Spacing.xs
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .normal: return DesignTokens.Spacing.lg
            case .large: return DesignTokens.Spacing.xl
            case .small: return DesignTokens.Spacing.md
            }
        }
        
        var textStyle: DesignTokens.Typography {
            switch self {
            case .normal, .large: return .callout
            case .small: return .footnote
            }
        }
    }
    
    init(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        size: Size = .normal,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: DesignTokens.IconSize.medium.size, height: DesignTokens.IconSize.medium.size)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(size.textStyle.font)
                }
                
                Text(title)
                    .typography(size.textStyle)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
    
    private var foregroundColor: Color {
        return DesignTokens.Colors.primaryButtonForeground
    }
    
    private var backgroundColor: Color {
        if isDisabled {
            return DesignTokens.Colors.disabledButtonBackground
        }
        if isLoading {
            return DesignTokens.Colors.primaryButtonBackground.opacity(0.8)
        }
        return DesignTokens.Colors.primaryButtonBackground
    }
}

// MARK: - Convenience Initializers
extension PrimaryButton {
    static func large(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> PrimaryButton {
        PrimaryButton(
            title: title,
            icon: icon,
            isLoading: isLoading,
            isDisabled: isDisabled,
            size: .large,
            action: action
        )
    }
    
    static func small(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> PrimaryButton {
        PrimaryButton(
            title: title,
            icon: icon,
            isLoading: isLoading,
            isDisabled: isDisabled,
            size: .small,
            action: action
        )
    }
}

// MARK: - Previews

struct PrimaryButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default state
            PrimaryButton(
                title: "Create CV",
                icon: "plus.circle.fill"
            ) {}
            .previewDisplayName("Default")
            
            // Loading state
            PrimaryButton(
                title: "Creating...",
                isLoading: true
            ) {}
            .previewDisplayName("Loading")
            
            // Disabled state
            PrimaryButton(
                title: "Disabled",
                isDisabled: true
            ) {}
            .previewDisplayName("Disabled")
            
            // Large size
            PrimaryButton.large(
                title: "Large Button",
                icon: "arrow.right"
            ) {}
            .previewDisplayName("Large")
            
            // Small size
            PrimaryButton.small(
                title: "Small Button"
            ) {}
            .previewDisplayName("Small")
        }
        .previewLayout(.sizeThatFits)
        .padding()
        .preferredColorScheme(.light)
    }
}