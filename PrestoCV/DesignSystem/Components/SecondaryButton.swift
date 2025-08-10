import SwiftUI

// MARK: - Secondary Button Component
/// A reusable secondary button component with multiple styles
/// for less prominent actions throughout the app
struct SecondaryButton: View {
    let title: String
    let icon: String?
    let style: Style
    let isDisabled: Bool
    let action: () -> Void
    
    init(
        title: String,
        icon: String? = nil,
        style: Style = .outline,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(DesignTokens.IconSize.medium.font)
                }
                
                Text(title)
                    .typography(style.textStyle)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: style.fillsWidth ? .infinity : nil)
            .frame(minHeight: style.height)
            .padding(.horizontal, style.horizontalPadding)
            .background(backgroundColor)
            .cornerRadius(style.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .stroke(borderColor, lineWidth: style.borderWidth)
            )
        }
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityAddTraits(accessibilityTraits)
        .opacity(isDisabled ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
    
    // MARK: - Style Options
    enum Style {
        case outline    // Border with transparent background
        case filled     // Filled background with accent color
        case text       // Text-only button (no border/background)
        case compact    // Smaller padding for inline use
        
        var textStyle: DesignTokens.Typography {
            switch self {
            case .text: return .callout
            case .compact: return .footnote
            default: return .buttonText
            }
        }
        
        var height: CGFloat {
            switch self {
            case .compact: return 32
            case .text: return 44
            default: return 48
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .text: return DesignTokens.Spacing.sm
            case .compact: return DesignTokens.Spacing.md
            default: return DesignTokens.Spacing.lg
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .text: return 0
            case .compact: return DesignTokens.CornerRadius.sm
            default: return DesignTokens.CornerRadius.md
            }
        }
        
        var borderWidth: CGFloat {
            switch self {
            case .outline: return 1
            default: return 0
            }
        }
        
        var fillsWidth: Bool {
            switch self {
            case .text, .compact: return false
            default: return true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var foregroundColor: Color {
        switch style {
        case .filled:
            return DesignTokens.Colors.primaryButtonText
        case .outline, .text, .compact:
            return DesignTokens.Colors.secondaryButtonText
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .filled:
            return DesignTokens.Colors.accent
        case .outline, .text, .compact:
            return .clear
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .outline:
            return DesignTokens.Colors.secondaryButtonText
        default:
            return .clear
        }
    }
    
    private var accessibilityTraits: AccessibilityTraits {
        let traits: AccessibilityTraits = [.isButton]
        // Note: In iOS 16+, disabled buttons are handled automatically
        // Older versions may need explicit trait management
        return traits
    }
}

// MARK: - Convenience Initializers
extension SecondaryButton {
    
    /// Creates a text-only secondary button
    static func text(title: String, action: @escaping () -> Void) -> SecondaryButton {
        SecondaryButton(title: title, style: .text, action: action)
    }
    
    /// Creates a compact secondary button for inline use
    static func compact(title: String, icon: String? = nil, action: @escaping () -> Void) -> SecondaryButton {
        SecondaryButton(title: title, icon: icon, style: .compact, action: action)
    }
    
    /// Creates a filled secondary button
    static func filled(title: String, icon: String? = nil, action: @escaping () -> Void) -> SecondaryButton {
        SecondaryButton(title: title, icon: icon, style: .filled, action: action)
    }
}

// MARK: - Previews
struct SecondaryButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Outline style (default)
            SecondaryButton(title: "Cancel", action: {})
            
            // With icon
            SecondaryButton(
                title: "Skip for now",
                icon: "arrow.right",
                action: {}
            )
            
            // Filled style
            SecondaryButton.filled(
                title: "Save Draft",
                icon: "square.and.arrow.down",
                action: {}
            )
            
            // Text style
            SecondaryButton.text(title: "Learn More", action: {})
            
            // Compact style
            HStack {
                SecondaryButton.compact(title: "Edit", action: {})
                SecondaryButton.compact(
                    title: "Delete",
                    icon: "trash",
                    action: {}
                )
            }
            
            // Disabled state
            SecondaryButton(
                title: "Disabled",
                isDisabled: true,
                action: {}
            )
        }
        .padding()
        .background(DesignTokens.Colors.background)
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.light)
        
        // Dark mode preview
        VStack(spacing: DesignTokens.Spacing.lg) {
            SecondaryButton(title: "Cancel", action: {})
            SecondaryButton.filled(title: "Save Draft", action: {})
            SecondaryButton.text(title: "Learn More", action: {})
        }
        .padding()
        .background(DesignTokens.Colors.background)
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
    }
}