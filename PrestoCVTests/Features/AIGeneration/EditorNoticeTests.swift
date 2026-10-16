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
