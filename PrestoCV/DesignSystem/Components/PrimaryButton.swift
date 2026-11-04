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
                
                // The font of the style only: the colour of the title is the button's own
                Text(title)
                    .font(size.textStyle.font)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
        }
        .buttonStyle(PrimaryButtonStyle(isDisabled: isDisabled))
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Look

extension PrimaryButton {
    /// What a primary button draws: its label colour, its fill and its opacity. A pressed button takes the pressed
    /// accent, opaque, so that its label keeps its contrast; a disabled one is greyed out.
    struct Look {
        let foreground: Color
        let background: Color
        let opacity: Double

        init(isDisabled: Bool, isPressed: Bool) {
            if isDisabled {
                foreground = DesignTokens.Colors.disabledButtonForeground
                background = DesignTokens.Colors.disabledButtonBackground
                opacity = 0.6
            } else {
                foreground = DesignTokens.Colors.primaryButtonForeground
                background = isPressed
                    ? DesignTokens.Colors.primaryButtonPressedBackground
                    : DesignTokens.Colors.primaryButtonBackground
                opacity = 1
            }
        }
    }
}

// MARK: - Button Style

/// Draws any label as a primary button (see `PrimaryButton.Look`), instead of the system's press, which fades the
/// label and its fill.
struct PrimaryButtonStyle: ButtonStyle {
    let isDisabled: Bool
    /// The least width and height of what a finger can hit, when the button is smaller than that. The fill stays as small
    /// as the label; the space around it, up to the target, is part of the button, whatever it draws.
    var minimumTarget: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        let look = PrimaryButton.Look(isDisabled: isDisabled, isPressed: configuration.isPressed)
        return configuration.label
            .foregroundColor(look.foreground)
            .background(look.background)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .opacity(look.opacity)
            .frame(minWidth: minimumTarget, minHeight: minimumTarget)
            .contentShape(Rectangle())
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