import PrestoCVPresentation
import SwiftUI

/// The notice of an editor the person left whose text is not stored (#402, decisions 16 and 17): the CV's name, why its
/// text is not stored, and the ways on: write it again, when another write may store it as it is, and open it. Where it
/// stands, what it names and whether it offers to write again are the list's and the shell's (`KeptNotice`).
struct KeptNoticeView: View {
    let notice: KeptNotice
    let retry: (Int) -> Void
    let open: (Int) -> Void

    var body: some View {
        InlineNotice(actions: actions) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(verbatim: notice.label)
                    .font(.headline)
                WholeWordsText(notice.status.keptWords)
            }
        }
        .accessibilityIdentifier("list.kept")
    }

    private var actions: [NoticeAction] {
        let opening = NoticeAction(
            "list.kept.open", actionIdentifier: "list.kept.open", label: "list.kept.open.label \(notice.label)"
        ) { open(notice.id) }
        guard notice.canRetry else { return [opening] }
        let retrying = NoticeAction(
            "list.retry", actionIdentifier: "list.kept.retry", label: "list.kept.retry.label \(notice.label)"
        ) { retry(notice.id) }
        return [retrying, opening]
    }
}

extension SaveStatus {
    /// What the notice of a kept editor says about its text. A Retry that runs shows the editor's own "Saving…"; the
    /// field that cannot be read is named where the list knows a sentence for it.
    var keptWords: LocalizedStringResource {
        switch self {
        case .failed: "list.kept.failed"
        case .pending: "list.kept.pending"
        case .saving: words
        case .conflict: "list.kept.conflict"
        case .deletedElsewhere: "list.kept.deletedElsewhere"
        case .tooLarge: "list.kept.tooLarge"
        case .textTooLong: "list.kept.textTooLong"
        case .tooManyEntries: "list.kept.tooManyEntries"
        case .unreadable(.email): "list.kept.unreadable.email"
        case .unreadable(.phone): "list.kept.unreadable.phone"
        case .unreadable(.website): "list.kept.unreadable.website"
        case .unreadable: "list.kept.unreadable"
        // Never kept: the shell lets such an editor go.
        case .saved, .notEnoughContent: words
        }
    }
}
