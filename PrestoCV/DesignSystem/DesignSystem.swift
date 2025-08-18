import SwiftUI

// MARK: - Typography View Modifier
struct TypographyModifier: ViewModifier {
    let style: DesignTokens.Typography
    
    func body(content: Content) -> some View {
        content
            .font(style.font)
            .foregroundColor(style.color)
    }
}

// MARK: - View Extensions
extension View {
    func typography(_ style: DesignTokens.Typography) -> some View {
        self.modifier(TypographyModifier(style: style))
    }
    
    /// Applies the standard app shadow
    func defaultShadow() -> some View {
        self.shadow(
            color: DesignTokens.Colors.shadow,
            radius: DesignTokens.Shadow.medium.radius,
            x: DesignTokens.Shadow.medium.x,
            y: DesignTokens.Shadow.medium.y
        )
    }
    
    /// Applies a card-like appearance with shadow and corner radius
    func cardStyle() -> some View {
        self
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .defaultShadow()
    }
    
    /// Applies a flat list item style with subtle separation
    func listItemStyle() -> some View {
        self
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.sm)
    }
    
    /// Applies a material-inspired list row style with no elevation
    func flatRowStyle() -> some View {
        self
            .padding(.vertical, DesignTokens.Spacing.md)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .fill(DesignTokens.Colors.backgroundSecondary.opacity(DesignTokens.Opacity.disabled))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .stroke(DesignTokens.Colors.border.opacity(DesignTokens.Opacity.subtle), lineWidth: DesignTokens.BorderWidth.thin)
            )
    }
    
    /// Applies iOS HIG-compliant list item style
    func iOSListItemStyle() -> some View {
        self
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(Color.clear)
            .listRowInsets(EdgeInsets(top: DesignTokens.Spacing.xs, 
                                     leading: DesignTokens.Spacing.md, 
                                     bottom: DesignTokens.Spacing.xs, 
                                     trailing: DesignTokens.Spacing.md))
            .listRowBackground(Color.clear)
    }
}

