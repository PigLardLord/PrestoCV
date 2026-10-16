import SwiftUI

/// A one-line notice above the content of a screen, for something that went wrong without stopping the screen.
/// It can offer one action, such as dismissing the notice.
struct InlineNotice: View {
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(DesignTokens.Typography.caption1.font)
                .foregroundColor(DesignTokens.Colors.primary)
                .symbolRenderingMode(.multicolor)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(DesignTokens.Typography.caption1.font)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xxs)
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: false))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.backgroundSecondary)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    InlineNotice(message: "2 CVs could not be opened", actionTitle: "OK", action: {})
}
#endif
