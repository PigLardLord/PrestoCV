import SwiftUI

/// A short message above the editor, such as the reminder to check a CV drafted by AI, one paragraph for each of its lines.
/// A CV imported from the person's text also leads to what to check and to the text that was not imported.
struct EditorNoticeBanner: View {
    let notice: EditorNotice
    @State private var showingReview = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                Image(systemName: notice.iconName)
                    .foregroundColor(DesignTokens.Colors.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    ForEach(notice.messageKeys, id: \.self) { key in
                        Text(key.localized)
                            .typography(.caption1)
                            .foregroundColor(DesignTokens.Colors.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)

            if let review = notice.review {
                Button("editor.notice.imported.review".localized) {
                    showingReview = true
                }
                .buttonStyle(AccentTextButtonStyle())
                .typography(.caption1)
                .accessibilityIdentifier("editor.notice.review")
                .sheet(isPresented: $showingReview) {
                    ImportReviewSheet(review: review)
                }
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.accent.opacity(0.12))
        .cornerRadius(DesignTokens.CornerRadius.md)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.top, DesignTokens.Spacing.xs)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Previews

struct EditorNoticeBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            EditorNoticeBanner(notice: .aiDraft)
            EditorNoticeBanner(notice: .aiDraftUnchecked)
            EditorNoticeBanner(notice: .imported(ImportReview(
                items: [ImportReview.Item(field: .name, reason: .byPosition, text: "Lena Hartmann")], notImported: "Geburtsdatum: 14.05.1992"
            )))
        }
    }
}
