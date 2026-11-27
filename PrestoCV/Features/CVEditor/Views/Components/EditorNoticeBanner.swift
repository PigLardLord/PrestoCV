import SwiftUI

/// A short message above the editor, such as the reminder to check a CV drafted by AI, one paragraph for each of its lines.
/// A CV imported from the person's text also names the sections left out, leads to what to check and to the text that was
/// not imported, and stays until the person dismisses it (#452).
struct EditorNoticeBanner: View {
    let notice: EditorNotice
    /// What dismissing the notice does; nil when the notice offers no way to dismiss it.
    let onDismiss: (() -> Void)?
    @State private var showingReview = false
    @State private var confirmingDismissal = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                message
                if let onDismiss {
                    Button {
                        if notice.confirmsDismissal {
                            confirmingDismissal = true
                        } else {
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(DesignTokens.Colors.secondary)
                            .frame(minWidth: DesignTokens.InputSize.minimumTapTarget,
                                   minHeight: DesignTokens.InputSize.minimumTapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, -DesignTokens.Spacing.sm)
                    .padding(.trailing, -DesignTokens.Spacing.sm)
                    .accessibilityLabel("editor.notice.dismiss".localized)
                    .accessibilityIdentifier("editor.notice.dismiss")
                }
            }

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
        .alert("editor.notice.dismiss.title".localized, isPresented: $confirmingDismissal) {
            Button("editor.notice.dismiss.confirm".localized, role: .destructive) { onDismiss?() }
            Button("common.cancel".localized, role: .cancel) {}
        } message: {
            Text("editor.notice.dismiss.message".localized)
        }
    }

    /// The icon and the lines of the message, read as one.
    private var message: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: notice.iconName)
                .foregroundColor(DesignTokens.Colors.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                ForEach(notice.messageKeys, id: \.self) { key in
                    line(key.localized)
                }
                if let sections = notice.sectionsLine {
                    line(sections.key.localizedWithArgs(sections.headings))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func line(_ text: String) -> some View {
        Text(text)
            .typography(.caption1)
            .foregroundColor(DesignTokens.Colors.primary)
    }
}

// MARK: - Previews

struct EditorNoticeBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            EditorNoticeBanner(notice: .aiDraft, onDismiss: nil)
            EditorNoticeBanner(notice: .aiDraftUnchecked, onDismiss: nil)
            EditorNoticeBanner(notice: .imported(ImportReview(
                items: [ImportReview.Item(field: .name, reason: .byPosition, text: "Tobias Renn")],
                passages: [
                    ImportReview.Passage(place: .top, text: "EU citizen", isWholeSection: false),
                    ImportReview.Passage(place: .section("OWN VENTURES"), text: "Tidepool Notes | 2021 – today", isWholeSection: true),
                ]
            )), onDismiss: {})
            EditorNoticeBanner(notice: .importedDescription(ImportReview(
                items: [ImportReview.Item(field: .language, reason: .languageNotAdded, text: "Welsh")], notImported: ""
            )), onDismiss: {})
        }
    }
}
