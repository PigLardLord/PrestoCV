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
    
    /// Applies a card-like appearance with shadow and corner radius
    func cardStyle() -> some View {
        self
            .background(DesignTokens.Colors.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .shadow(
                color: DesignTokens.Colors.shadow,
                radius: 4,
                x: 0,
                y: 2
            )
    }
}