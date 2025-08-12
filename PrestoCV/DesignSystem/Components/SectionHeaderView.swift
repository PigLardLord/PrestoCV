import SwiftUI

/// A consistent section header component for grouping related content
/// Follows the design system tokens for consistent styling
struct SectionHeaderView: View {
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(title)
                .typography(.headline)
                .foregroundColor(DesignTokens.Colors.primary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .typography(.footnote)
                    .foregroundColor(DesignTokens.Colors.secondary)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

// MARK: - Previews
struct SectionHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            SectionHeaderView(title: "Personal Information")
            
            SectionHeaderView(
                title: "Skills",
                subtitle: "Add skills and rate your proficiency"
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}