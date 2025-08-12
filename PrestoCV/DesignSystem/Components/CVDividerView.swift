import SwiftUI

/// A consistent divider component for separating content sections in CV views
/// Follows the design system tokens for consistent styling
struct CVDividerView: View {
    let style: Style
    
    enum Style {
        case solid
        case dashed
        case inset
    }
    
    init(style: Style = .solid) {
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .solid:
            solidDivider
        case .dashed:
            dashedDivider
        case .inset:
            insetDivider
        }
    }
    
    private var solidDivider: some View {
        SwiftUI.Divider()
            .background(DesignTokens.Colors.divider)
    }
    
    private var insetDivider: some View {
        SwiftUI.Divider()
            .background(DesignTokens.Colors.divider)
            .padding(.horizontal, DesignTokens.Spacing.lg)
    }
    
    private var dashedDivider: some View {
        // Simplified dashed divider to avoid GeometryReader issues
        Rectangle()
            .fill(DesignTokens.Colors.divider)
            .frame(height: 1)
            .padding(.vertical, DesignTokens.Spacing.xxs)
    }
}

// MARK: - Previews
struct CVDividerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Text("Content above solid divider")
            
            CVDividerView()
            
            Text("Content below solid divider")
            
            CVDividerView(style: .inset)
            
            Text("Content below inset divider")
            
            CVDividerView(style: .dashed)
            
            Text("Content below dashed divider")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}