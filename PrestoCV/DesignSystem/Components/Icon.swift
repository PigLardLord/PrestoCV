import SwiftUI

/// A consistent icon component with standardized sizing and coloring
/// Follows the design system tokens for consistent styling
struct IconView: View {
    let systemName: String
    let style: Style
    let color: Color?
    
    enum Style {
        case small
        case medium
        case large
        case hero
        
        var iconSize: DesignTokens.IconSize {
            switch self {
            case .small: return .small
            case .medium: return .medium
            case .large: return .large
            case .hero: return .hero
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .small: return DesignTokens.Spacing.xxs
            case .medium: return DesignTokens.Spacing.xs
            case .large: return DesignTokens.Spacing.sm
            case .hero: return DesignTokens.Spacing.md
            }
        }
    }
    
    init(
        _ systemName: String,
        style: Style = .medium,
        color: Color? = nil
    ) {
        self.systemName = systemName
        self.style = style
        self.color = color
    }
    
    var body: some View {
        Image(systemName: systemName)
            .font(style.iconSize.font)
            .foregroundColor(color ?? DesignTokens.Colors.primary)
            .padding(style.padding)
    }
}

// MARK: - Convenience Initializers
extension IconView {
    static func small(
        _ systemName: String,
        color: Color? = nil
    ) -> IconView {
        IconView(systemName, style: .small, color: color)
    }
    
    static func large(
        _ systemName: String,
        color: Color? = nil
    ) -> IconView {
        IconView(systemName, style: .large, color: color)
    }
    
    static func hero(
        _ systemName: String,
        color: Color? = nil
    ) -> IconView {
        IconView(systemName, style: .hero, color: color)
    }
}

// MARK: - Previews
struct IconView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            IconView.small("heart", color: .red)
            IconView("star", color: .yellow)
            IconView.large("bell", color: .blue)
            IconView.hero("exclamationmark.triangle", color: .orange)
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
