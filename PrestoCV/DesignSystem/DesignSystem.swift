import SwiftUI

// MARK: - Typography View Modifier
struct TypographyModifier: ViewModifier {
    let style: DesignTokens.Typography
    
    func body(content: Content) -> some View {
        content
            .font(style.font)
    }
}

// MARK: - View Extensions
extension View {
    func typography(_ style: DesignTokens.Typography) -> some View {
        self.modifier(TypographyModifier(style: style))
    }
}