import SwiftUI
import UIKit

/// What to check in a CV imported from the person's text, and the text that was not imported, ready to copy.
struct ImportReviewSheet: View {
    let review: ImportReview
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                if !review.items.isEmpty {
                    Section {
                        ForEach(review.items, id: \.self) { item in
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                                Text(label(of: item))
                                    .typography(.caption1)
                                    .foregroundColor(DesignTokens.Colors.secondary)
                                Text(item.text)
                                    .typography(.body)
                                    .foregroundColor(DesignTokens.Colors.primary)
                                Text(item.reasonKey.localized)
                                    .typography(.caption1)
                                    .foregroundColor(DesignTokens.Colors.warning)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    } header: {
                        Text("import.review.check_title".localized)
                    }
                }
                if !review.notImported.isEmpty {
                    Section {
                        Text(review.notImported)
                            .typography(.body)
                            .foregroundColor(DesignTokens.Colors.primary)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("import.review.not_imported")
                        Button {
                            UIPasteboard.general.string = review.notImported
                            copied = true
                        } label: {
                            Label(copied ? "import.review.copied".localized : "import.review.copy".localized,
                                  systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(AccentTextButtonStyle())
                    } header: {
                        Text("import.review.not_imported_title".localized)
                    } footer: {
                        Text("import.review.not_imported_footer".localized)
                    }
                }
            }
            .navigationTitle("import.review.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done".localized) { dismiss() }
                }
            }
        }
    }

    /// The field, with the entry's number when it is one of a list.
    private func label(of item: ImportReview.Item) -> String {
        switch item.field {
        case .experience(let number), .education(let number):
            return item.fieldKey.localizedWithArgs(number)
        default:
            return item.fieldKey.localized
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    ImportReviewSheet(review: ImportReview(
        items: [
            ImportReview.Item(field: .experience(2), reason: .partsByOrder, text: "Night Shift — Corner Market Example"),
            ImportReview.Item(field: .language, reason: .languageNotAdded, text: "Englisch — verhandlungssicher"),
        ],
        notImported: "Geburtsdatum: 14.05.1992\nEhrenamt: Trainerin im Kletterverein"
    ))
}
#endif
