import SwiftUI

/// A card component for displaying content with elevation and rounded corners
/// Follows the design system tokens for consistent styling
struct CardView<ContentView: View>: View {
    let content: ContentView
    let paddingAmount: CGFloat
    
    init(
        padding: CGFloat = DesignTokens.Spacing.md,
        @ViewBuilder content: () -> ContentView
    ) {
        self.paddingAmount = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(EdgeInsets(top: paddingAmount, leading: paddingAmount, bottom: paddingAmount, trailing: paddingAmount))
            .background(DesignTokens.Colors.backgroundTertiary)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .shadow(
                color: DesignTokens.Colors.shadow,
                radius: 4, // Using direct value instead of tuple access
                x: 0,      // Using direct value instead of tuple access
                y: 2       // Using direct value instead of tuple access
            )
    }
}

// MARK: - Previews
struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            CardView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Default Card")
                        .font(.headline)
                    Text("This is a default card with medium padding.")
                        .font(.body)
                }
            }
            
            CardView(padding: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Tight Card")
                        .font(.headline)
                    Text("This card has smaller padding for compact content.")
                        .font(.body)
                }
            }
            
            CardView(padding: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Loose Card")
                        .font(.headline)
                    Text("This card has larger padding for spacious content.")
                        .font(.body)
                }
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}