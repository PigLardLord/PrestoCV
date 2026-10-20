import Testing
@testable import PrestoCV

@Suite("EditorNotice Tests")
struct EditorNoticeTests {

    @Test("The AI draft notice has a message in the string catalog")
    func aiDraftMessageIsTranslated() {
        let key = EditorNotice.aiDraft.messageKey
        #expect(key.localized != key, "\(key) is missing from the string catalog")
    }
}

@Suite("EditorNotice of an import")
struct ImportEditorNoticeTests {

    @Test("The notice of an import has a message in the string catalog, and leads to its review")
    func importedNotice() {
        let review = ImportReview(items: [], notImported: "Geburtsdatum: 14.05.1992")
        let notice = EditorNotice.imported(review)

        #expect(notice.messageKey.localized != notice.messageKey, "\(notice.messageKey) is missing from the string catalog")
        #expect(notice.review == review)
        #expect(EditorNotice.aiDraft.review == nil)
    }

    @Test("An import with nothing to check and nothing left over offers no review")
    func emptyReview() {
        #expect(EditorNotice.imported(ImportReview(items: [], notImported: "")).review == nil)
    }
}
