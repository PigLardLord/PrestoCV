import SwiftUI

// MARK: - Primary Button Component
/// A reusable primary button component following design system standards
/// with loading states, accessibility support, and consistent styling
struct PrimaryButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    init(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if isLoading {
                    LoadingView.button()
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(DesignTokens.IconSize.medium.font)
                }
                
                Text(title)
                    .typography(.buttonText)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: buttonHeight)
            .background(backgroundColor)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .designShadow(isDisabled ? .none : .small)
        }
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(accessibilityTraits)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
    
    // MARK: - Computed Properties
    
    private var buttonHeight: CGFloat {
        48 // Standard touch target size
    }
    
    private var foregroundColor: Color {
        if isDisabled {
            return DesignTokens.Colors.disabledButtonText
        }
        return DesignTokens.Colors.primaryButtonText
    }
    
    private var backgroundColor: Color {
        if isDisabled {
            return DesignTokens.Colors.disabledButtonBackground
        }
        return DesignTokens.Colors.accent
    }
    
    private var accessibilityLabel: String {
        if isLoading {
            return "\(title), loading"
        }
        return title
    }
    
    private var accessibilityTraits: AccessibilityTraits {
        let traits: AccessibilityTraits = [.isButton]
        // Note: In iOS 16+, disabled buttons are handled automatically
        // Older versions may need explicit trait management
        return traits
    }
}

// MARK: - Convenience Initializers
extension PrimaryButton {
    
    /// Creates a primary button with loading state
    static func loading(title: String) -> PrimaryButton {
        PrimaryButton(title: title, isLoading: true, action: {})
    }
    
    /// Creates a disabled primary button
    static func disabled(title: String) -> PrimaryButton {
        PrimaryButton(title: title, isDisabled: true, action: {})
    }
}

// MARK: - Previews
struct PrimaryButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Default state
            PrimaryButton(title: "Create CV", action: {})
            
            // With icon
            PrimaryButton(
                title: "Add New CV",
                icon: "plus.circle.fill",
                action: {}
            )
            
            // Loading state
            PrimaryButton.loading(title: "Creating...")
            
            // Disabled state
            PrimaryButton.disabled(title: "Create CV")
            
            // Long text
            PrimaryButton(
                title: "Create Your First Professional CV",
                action: {}
            )
        }
        .padding()
        .background(DesignTokens.Colors.background)
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.light)
        
        // Dark mode preview
        VStack(spacing: DesignTokens.Spacing.lg) {
            PrimaryButton(title: "Create CV", action: {})
            PrimaryButton.loading(title: "Creating...")
            PrimaryButton.disabled(title: "Create CV")
        }
        .padding()
        .background(DesignTokens.Colors.background)
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}