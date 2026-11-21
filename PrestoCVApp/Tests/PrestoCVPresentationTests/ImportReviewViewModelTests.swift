import Testing
@testable import PrestoCVPresentation

/// The review beside the editor: shown while it has something to check, until the person dismisses it or the editor
/// stored the CV (ADR 0027).
@MainActor
@Suite("Import review")
struct ImportReviewViewModelTests {

    private let entries = [
        ReviewEntry(field: .experiencePeriod(2), reason: .periodOpenEnd, text: "03/2019 –"),
        ReviewEntry(field: .name, reason: .nameByPosition, text: "Ada Ferro"),
    ]

    private func review(_ entries: [ReviewEntry], notImported: String) -> ImportReviewViewModel {
        ImportReviewViewModel(review: ImportReview(entries: entries, notImported: notImported, source: .file))
    }

    @Test("it shows the entries in their order and the text not imported whole")
    func showsEntriesAndNotImported() {
        let model = review(entries, notImported: "Hobbies:\n  chess, sailing\n")

        #expect(model.entries == entries)
        #expect(model.notImported == "Hobbies:\n  chess, sailing\n")
        #expect(model.hasEntries && model.hasNotImported)
        #expect(model.isShown)
    }

    @Test("once the editor stored the CV the review ends")
    func editorStoredEndsTheReview() {
        let model = review(entries, notImported: "Hobbies: chess")

        model.editorStored()

        #expect(model.isShown == false)
        #expect(model.entries == entries)
    }

    @Test("once the person dismissed it the review ends")
    func dismissEndsTheReview() {
        let model = review(entries, notImported: "Hobbies: chess")

        model.dismiss()

        #expect(model.isShown == false)
        #expect(model.notImported == "Hobbies: chess")
    }

    @Test("entries alone or a text not imported alone are shown, until one of the two calls")
    func shownUntilEitherCall() {
        let onlyEntries = review(entries, notImported: "")
        let onlyText = review([], notImported: "Hobbies: chess")

        #expect(onlyEntries.isShown && !onlyEntries.hasNotImported)
        #expect(onlyText.isShown && !onlyText.hasEntries)
        #expect(onlyEntries.isShown && onlyText.isShown)
    }

    @Test("a review with nothing to check is never shown")
    func emptyReviewIsNotShown() {
        let model = review([], notImported: "")

        #expect(model.isShown == false)
        #expect(!model.hasEntries && !model.hasNotImported)
    }

    @Test("a second store, or a dismiss after it, changes nothing")
    func storedTwiceIsHarmless() {
        let model = review(entries, notImported: "Hobbies: chess")

        model.editorStored()
        model.editorStored()
        model.dismiss()

        #expect(model.isShown == false)
        #expect(model.entries == entries && model.notImported == "Hobbies: chess")
    }

    @Test("the notice's words follow what the review holds: values to check, a text to copy, or both")
    func noticeKindFollowsWhatTheReviewHolds() {
        #expect(review(entries, notImported: "Hobbies: chess").noticeKind == .checkAndCopy)
        #expect(review(entries, notImported: "").noticeKind == .checkOnly)
        #expect(review([], notImported: "Hobbies: chess").noticeKind == .copyOnly)
        #expect(review([], notImported: "").noticeKind == nil)
    }

    @Test("the sheet opens only while the review is shown, and closes")
    func sheetOpensOnlyWhileShown() {
        let model = review(entries, notImported: "Hobbies: chess")
        let empty = review([], notImported: "")
        let dismissed = review(entries, notImported: "Hobbies: chess")
        dismissed.dismiss()

        model.openSheet()
        empty.openSheet()
        dismissed.openSheet()

        #expect(model.isSheetShown)
        #expect(!empty.isSheetShown)
        #expect(!dismissed.isSheetShown)
        model.closeSheet()
        #expect(!model.isSheetShown)
    }

    @Test("a sheet open when the review ends stays until the person closes it")
    func sheetOutlivesTheNotice() {
        let model = review(entries, notImported: "Hobbies: chess")
        model.openSheet()

        model.editorStored()

        #expect(!model.isShown)
        #expect(model.isSheetShown)
        model.closeSheet()
        #expect(!model.isSheetShown)
    }

    @Test("each copy of the text not imported is counted, so that each is told, until the sheet closes")
    func copyCountsEachTap() {
        let model = review(entries, notImported: "Hobbies: chess")
        model.openSheet()
        #expect(model.copyCount == 0 && !model.didCopy)

        model.noteCopied()
        #expect(model.copyCount == 1 && model.didCopy)
        model.noteCopied()
        #expect(model.copyCount == 2 && model.didCopy)
        model.closeSheet()
        model.openSheet()
        #expect(model.copyCount == 0 && !model.didCopy)
    }
}
