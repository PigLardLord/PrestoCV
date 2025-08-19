import SwiftUI

/// A reusable navigation card/row component
struct NavigationCard<Content: View>: View {
    let action: () -> Void
    let showChevron: Bool
    @ViewBuilder let content: () -> Content
    
    init(
        action: @escaping () -> Void,
        showChevron: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.showChevron = showChevron
        self.content = content
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                content()
                
                if showChevron {
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(DesignTokens.IconSize.small.font)
                        .foregroundColor(DesignTokens.Colors.secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// A specialized navigation row for list items
struct NavigationRow: View {
    let title: String
    let subtitle: String?
    let caption: String?
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String? = nil,
        caption: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.caption = caption
        self.action = action
    }
    
    var body: some View {
        NavigationCard(action: action) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .typography(.headline)
                    .foregroundColor(DesignTokens.Colors.primary)
                    .lineLimit(1)
                
                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .typography(.subheadline)
                        .foregroundColor(DesignTokens.Colors.secondary)
                        .lineLimit(1)
                }
                
                if let caption = caption, !caption.isEmpty {
                    Text(caption)
                        .typography(.caption1)
                        .foregroundColor(DesignTokens.Colors.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .accessibilityLabel("accessibility.navigate_to".localizedWithArgs(title))
        .accessibilityAddTraits(.isButton)
    }
}