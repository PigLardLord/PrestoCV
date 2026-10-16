import SwiftUI

/// A short message above the editor, such as the reminder to check a CV drafted by AI.
struct EditorNoticeBanner: View {
    let notice: EditorNotice

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "sparkles")
                .foregroundColor(DesignTokens.Colors.accent)
                .accessibilityHidden(true)

            Text(notice.messageKey.localized)
                .typography(.caption1)
                .foregroundColor(DesignTokens.Colors.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.accent.opacity(0.12))
        .cornerRadius(DesignTokens.CornerRadius.md)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.top, DesignTokens.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

struct EditorNoticeBanner_Previews: PreviewProvider {
    static var previews: some View {
        EditorNoticeBanner(notice: .aiDraft)
    }
}
