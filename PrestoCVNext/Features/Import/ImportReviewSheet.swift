import PrestoCVPresentation
import SwiftUI

/// The review of an import, over the editor (#404): the values to check, one row each in the order the import gave
/// them, then the text not imported, whole and selectable, with Copy all. A part with nothing in it is not drawn. Done,
/// or a swipe down, closes it; the shell keeps it open after the editor stored, so that the text to copy is never taken
/// from under the person.
struct ImportReviewSheet: View {
    let review: ImportReviewViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            List {
                if review.hasEntries {
                    checkSection
                }
                if review.hasNotImported {
                    notImportedSection
                }
            }
            .navigationTitle(Text("import.review.title"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        review.closeSheet()
                    } label: {
                        Label("import.done", systemImage: "checkmark")
                    }
                    .accessibilityIdentifier("import.review.done")
                }
            }
        }
        // A medium sheet at an accessibility size shows one row
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationSizing(.form)
        // Each copy is told, the second too: the count changes with every tap, and is nil until the first
        .announce(review.didCopy ? review.copyCount : nil, words: { _ in "import.review.copied.announcement" })
    }

    private var checkSection: some View {
        Section {
            // The entries may repeat and never change, so their place tells them apart
            ForEach(Array(review.entries.enumerated()), id: \.offset) { offset, entry in
                entryRow(entry)
                    .accessibilityIdentifier("import.review.entry.\(offset + 1)")
            }
        } header: {
            WholeWordsText("import.review.checkTitle")
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// Where the value is, the person's text, and why to check it: one element for VoiceOver, read in that order. The
    /// words say what each line is, so no colour tells it.
    private func entryRow(_ entry: ReviewEntry) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small / 2) {
            WholeWordsText(entry.field.label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            WholeWordsText(verbatim: entry.text)
                .font(.body)
                .foregroundStyle(.primary)
            WholeWordsText(entry.reason.words)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var notImportedSection: some View {
        Section {
            // The person may select a part and copy it with the system's menu, hence "Copy all" below
            Text(verbatim: review.notImported)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("import.review.notImported")
            Button {
                copyToPasteboard(review.notImported)
                review.noteCopied()
            } label: {
                Group {
                    if review.didCopy {
                        Label("import.review.copied", systemImage: "checkmark")
                    } else {
                        Label("import.review.copy", systemImage: "doc.on.doc")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: TapTarget.minimumHeight, alignment: .leading)
            }
            .accessibilityIdentifier("import.review.copy")
        } header: {
            WholeWordsText("import.review.notImportedTitle")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("import.review.notImportedFooter")
                .footerTextStyle()
                .accessibilityIdentifier("import.review.footer")
        }
    }
}
