import SwiftUI

// MARK: - Secondary Button Component
/// A secondary button style with multiple configurations following design system standards
struct SecondaryButton: View {
    let title: String
    let style: Style
    let icon: String?
    let action: () -> Void
    
    enum Style {
        case text
        case compact
        case outlined
        
        var textStyle: DesignTokens.Typography {
            switch self {
            case .text: return .callout
            case .compact: return .footnote
            case .outlined: return .callout
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .text: return EdgeInsets(top: DesignTokens.Spacing.xs, leading: 0, bottom: DesignTokens.Spacing.xs, trailing: 0)
            case .compact: return EdgeInsets(top: DesignTokens.Spacing.xxs, leading: DesignTokens.Spacing.xs, bottom: DesignTokens.Spacing.xxs, trailing: DesignTokens.Spacing.xs)
            case .outlined: return EdgeInsets(top: DesignTokens.Spacing.sm, leading: DesignTokens.Spacing.lg, bottom: DesignTokens.Spacing.sm, trailing: DesignTokens.Spacing.lg)
            }
        }
    }
    
    init(title: String, style: Style = .outlined, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(style.textStyle.font)
                }
                // The font of the style only: the colour of the title is the button's own
                Text(title)
                    .font(style.textStyle.font)
            }
            .padding(style.padding)
        }
        .buttonStyle(AccentTextButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Convenience Initializers

extension SecondaryButton {
    static func text(title: String, icon: String? = nil, action: @escaping () -> Void) -> SecondaryButton {
        SecondaryButton(title: title, style: .text, icon: icon, action: action)
    }
    
    static func compact(title: String, icon: String? = nil, action: @escaping () -> Void) -> SecondaryButton {
        SecondaryButton(title: title, style: .compact, icon: icon, action: action)
    }
    
    static func outlined(title: String, icon: String? = nil, action: @escaping () -> Void) -> SecondaryButton {
        SecondaryButton(title: title, style: .outlined, icon: icon, action: action)
    }
}

// MARK: - Previews

struct SecondaryButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Text Style
            SecondaryButton.text(title: "Skip for now") {}
                .previewDisplayName("Text Style")
            
            // Compact Style
            SecondaryButton.compact(title: "Edit", icon: "pencil") {}
                .previewDisplayName("Compact Style")
            
            // Outlined Style
            SecondaryButton.outlined(title: "common.cancel".localized, icon: "xmark") {}
                .previewDisplayName("Outlined Style")
        }
        .previewLayout(.sizeThatFits)
        .padding()
        .preferredColorScheme(.light)
    }
}
