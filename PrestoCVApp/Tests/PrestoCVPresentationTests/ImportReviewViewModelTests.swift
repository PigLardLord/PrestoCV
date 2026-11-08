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
}
