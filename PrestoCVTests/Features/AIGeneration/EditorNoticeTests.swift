import Testing
@testable import PrestoCV

@Suite("EditorNotice Tests")
struct EditorNoticeTests {

    @Test("The AI draft notice has a message in the string catalog")
    func aiDraftMessageIsTranslated() {
        #expect(EditorNotice.aiDraft.messageKeys == ["editor.notice.ai_draft"])
        for key in EditorNotice.aiDraft.messageKeys {
            #expect(key.localized != key, "\(key) is missing from the string catalog")
        }
    }

    @Test("An AI draft whose personal items could not be checked says so after the reminder to check it (ADR 0028)")
    func uncheckedDraftSaysWhatIsLeftBlank() {
        let notice = EditorNotice.aiDraftUnchecked

        #expect(notice.messageKeys == ["editor.notice.ai_draft", "editor.notice.ai_draft.unchecked"])
        for key in notice.messageKeys {
            #expect(key.localized != key, "\(key) is missing from the string catalog")
        }
        #expect(notice.review == nil, "It leads to no review")
    }

    @Test("Each notice has its symbol: the AI drafts share one, the import has its own")
    func symbols() {
        #expect(EditorNotice.aiDraft.iconName == "sparkles")
        #expect(EditorNotice.aiDraftUnchecked.iconName == "sparkles")
        #expect(EditorNotice.imported(ImportReview(items: [], notImported: "")).iconName == "doc.on.clipboard")
    }
}

@Suite("EditorNotice of an import")
struct ImportEditorNoticeTests {

    @Test("The notice of an import has a message in the string catalog, and leads to its review")
    func importedNotice() {
        let review = ImportReview(items: [], notImported: "Geburtsdatum: 14.05.1992")
        let notice = EditorNotice.imported(review)

        #expect(notice.messageKeys == ["editor.notice.imported"])
        #expect(notice.messageKeys[0].localized != notice.messageKeys[0], "\(notice.messageKeys[0]) is missing from the string catalog")
        #expect(notice.review == review)
        #expect(EditorNotice.aiDraft.review == nil)
    }

    @Test("An import with nothing to check and nothing left over offers no review")
    func emptyReview() {
        #expect(EditorNotice.imported(ImportReview(items: [], notImported: "")).review == nil)
    }
}

@Suite("EditorNotice of a CV pasted in the AI screen")
struct ImportedDescriptionEditorNoticeTests {

    @Test("A CV pasted in the AI screen says it was read as written, then what an import says, and leads to its review")
    func importedDescriptionNotice() {
        let review = ImportReview(items: [], notImported: "Driving licence: B")
        let notice = EditorNotice.importedDescription(review)

        #expect(notice.messageKeys == ["editor.notice.imported.from_description", "editor.notice.imported"])
        for key in notice.messageKeys {
            #expect(key.localized != key, "\(key) is missing from the string catalog")
        }
        #expect(notice.iconName == "doc.on.clipboard", "The import's symbol: the CV was read, not drafted")
        #expect(notice.review == review)
    }

    @Test("A pasted CV with nothing to check and nothing left over offers no review")
    func emptyReview() {
        #expect(EditorNotice.importedDescription(ImportReview(items: [], notImported: "")).review == nil)
    }
}
