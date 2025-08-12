import SwiftUI

/// A tag component for displaying categorized content
/// Follows the design system tokens for consistent styling
struct TagView: View {
    let title: String
    let style: Style
    let action: (() -> Void)?
    
    enum Style {
        case primary
        case secondary
        case accent
        
        var backgroundColor: Color {
            switch self {
            case .primary: return DesignTokens.Colors.tagBackground
            case .secondary: return DesignTokens.Colors.backgroundSecondary
            case .accent: return DesignTokens.Colors.accent.opacity(0.1)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return DesignTokens.Colors.tagForeground
            case .secondary: return DesignTokens.Colors.primary
            case .accent: return DesignTokens.Colors.accent
            }
        }
        
        var borderColor: Color {
            switch self {
            case .primary: return DesignTokens.Colors.tagBorder
            case .secondary: return DesignTokens.Colors.border
            case .accent: return DesignTokens.Colors.accent.opacity(0.3)
            }
        }
    }
    
    init(title: String, style: Style = .primary, action: (() -> Void)? = nil) {
        self.title = title
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Text(title)
            .typography(.caption1)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .background(style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .cornerRadius(DesignTokens.CornerRadius.full)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.full)
                    .stroke(style.borderColor, lineWidth: 1)
            )
            .onTapGesture(perform: action ?? {})
            .opacity(action != nil ? 1.0 : 0.8)
    }
}

// MARK: - Previews
struct TagView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            HStack {
                TagView(title: "Design")
                TagView(title: "Development")
                TagView(title: "Marketing")
            }
            
            HStack {
                TagView(title: "New", style: .accent)
                TagView(title: "Popular", style: .accent)
                TagView(title: "Featured", style: .accent)
            }
            
            HStack {
                TagView(title: "Draft", style: .secondary)
                TagView(title: "Published", style: .secondary)
                TagView(title: "Archived", style: .secondary)
            }
            
            TagView(title: "Interactive Tag", action: {
                print("Tag tapped")
            })
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
