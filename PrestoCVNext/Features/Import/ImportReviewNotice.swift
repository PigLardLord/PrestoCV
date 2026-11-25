import PrestoCVPresentation
import SwiftUI

/// The notice above the form while the review of an import is shown (#404): that the CV was imported, and what to check
/// or copy, with Review, which opens the review's sheet, and Dismiss. It goes with no announcement once the editor
/// stored a change the person made or the person dismissed it, since the person's focus is in the form.
struct ImportReviewNotice: View {
    let review: ImportReviewViewModel

    var body: some View {
        if let kind = review.noticeKind {
            InlineNotice(actions: [
                NoticeAction("import.notice.review", actionIdentifier: "import.review.notice.review",
                             label: "import.notice.review.label") { review.openSheet() },
                NoticeAction("import.notice.dismiss", actionIdentifier: "import.review.notice.dismiss",
                             label: "import.notice.dismiss.label") { review.dismiss() },
            ]) {
                WholeWordsText(kind.words)
            }
            .accessibilityIdentifier("import.review.notice")
        }
    }
}
