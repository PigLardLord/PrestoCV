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
}

