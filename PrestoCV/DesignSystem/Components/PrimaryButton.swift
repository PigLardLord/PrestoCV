import SwiftUI

// MARK: - Primary Button Component
/// A primary action button with loading state and icon support following design system standards
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
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: DesignTokens.IconSize.medium.size, height: DesignTokens.IconSize.medium.size)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(DesignTokens.Typography.callout.font)
                }
                
                Text(title)
                    .typography(.callout)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .opacity(isDisabled ? 0.6 : 1.0)
            .scaleEffect(isDisabled ? 1.0 : 1.0)
        }
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
    
    private var foregroundColor: Color {
        if isDisabled {
            return DesignTokens.Colors.primaryButtonText.opacity(0.6)
        }
        return DesignTokens.Colors.primaryButtonText
    }
    
    private var backgroundColor: Color {
        if isDisabled {
            return DesignTokens.Colors.accent.opacity(0.6)
        }
        return DesignTokens.Colors.accent
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
        }
        .previewLayout(.sizeThatFits)
        .padding()
        .preferredColorScheme(.light)
    }
}