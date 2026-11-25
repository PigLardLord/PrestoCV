import PrestoCVPresentation
import SwiftUI

/// The notices above the form, in one block: first the status notice, while the text cannot be stored as it is, since it
/// keeps the person in the CV; then the notice of an import's review. Where the form is short of room, the block takes at
/// most a quarter of the editor's height and scrolls inside (`EditorChrome`): one cap for both, so that two notices never
/// take half the editor.
struct EditorNotices: View {
    let editor: EditorViewModel
    /// The review of the import whose draft the editor shows, nil for any other CV.
    let review: ImportReviewViewModel?
    /// The editor's height, 0 while it is not known yet.
    let editorHeight: Double
    /// Closes the editor without storing its text.
    let discard: () -> Void
    @Environment(\.isCompactHeight) private var isCompactHeight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The notices' own height, which the cap never exceeds.
    @State private var fullHeight: Double = 0

    var body: some View {
        if editor.saveStatus.blocksLeaving || review?.noticeKind != nil {
            placed
        }
    }

    @ViewBuilder
    private var placed: some View {
        let chrome = EditorChrome(isCompactHeight: isCompactHeight, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
        if let height = chrome.noticeHeight(fullHeight: fullHeight, editorHeight: editorHeight) {
            ScrollView { measured }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicatorsFlash(onAppear: true)
                .frame(height: height)
        } else {
            measured
        }
    }

    private var measured: some View {
        VStack(spacing: 0) {
            StatusNotice(editor: editor, discard: discard)
            if let review {
                ImportReviewNotice(review: review)
            }
        }
        .padding(.horizontal, Spacing.medium)
        .readableWidth()
        .onGeometryChange(for: Double.self) { Double($0.size.height) } action: { fullHeight = $0 }
    }
}
