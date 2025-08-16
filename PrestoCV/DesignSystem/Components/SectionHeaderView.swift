import SwiftUI

/// A consistent section header component for grouping related content
/// Follows the design system tokens for consistent styling
struct SectionHeaderView: View {
    let title: String
    let subtitle: String?
    let titleStyle: DesignTokens.Typography
    let subtitleStyle: DesignTokens.Typography
    
    init(
        title: String, 
        subtitle: String? = nil,
        titleStyle: DesignTokens.Typography = .headline,
        subtitleStyle: DesignTokens.Typography = .footnote
    ) {
        self.title = title
        self.subtitle = subtitle
        self.titleStyle = titleStyle
        self.subtitleStyle = subtitleStyle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            Text(title)
                .typography(titleStyle)
                .foregroundColor(DesignTokens.Colors.primary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .typography(subtitleStyle)
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
            
            SectionHeaderView(
                title: "Create New",
                subtitle: "Start with a blank canvas to create your CV from scratch.",
                titleStyle: .title1,
                subtitleStyle: .body
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}