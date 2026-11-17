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

    @Test("A section left out whole is named in a line of its own, by its heading as the CV writes it (#452)")
    func oneSectionLeftOut() {
        let review = ImportReview(items: [], passages: [
            ImportReview.Passage(place: .top, text: "EU citizen", isWholeSection: false),
            ImportReview.Passage(place: .section("OWN VENTURES"), text: "Tidepool Notes | 2021 – today", isWholeSection: true),
        ])

        let line = EditorNotice.imported(review).sectionsLine

        #expect(line == EditorNotice.SectionsLine(key: "editor.notice.imported.section", headings: "OWN VENTURES"))
        #expect(EditorNotice.importedDescription(review).sectionsLine == line, "A CV pasted in the AI screen names it too")
    }

    @Test("Several sections left out whole are named in one line, in the order of the CV")
    func severalSectionsLeftOut() {
        let review = ImportReview(items: [], passages: [
            ImportReview.Passage(place: .section("OWN VENTURES"), text: "Tidepool Notes", isWholeSection: true),
            ImportReview.Passage(place: .section("Experience"), text: "Lucca", isWholeSection: false),
            ImportReview.Passage(place: .section("VOLUNTEERING"), text: "Rowing coach", isWholeSection: true),
        ])

        #expect(EditorNotice.imported(review).sectionsLine == EditorNotice.SectionsLine(
            key: "editor.notice.imported.sections", headings: "OWN VENTURES, VOLUNTEERING"
        ))
    }

    @Test("A notice names no section when every section was read, even with text left over")
    func noSectionLeftOut() {
        let review = ImportReview(items: [], passages: [
            ImportReview.Passage(place: .top, text: "EU citizen", isWholeSection: false),
            ImportReview.Passage(place: .section("Experience"), text: "Lucca", isWholeSection: false),
            ImportReview.Passage(place: .elsewhere, text: "Driving licence: B", isWholeSection: false),
        ])

        #expect(EditorNotice.imported(review).sectionsLine == nil)
        #expect(EditorNotice.imported(ImportReview(items: [], notImported: "")).sectionsLine == nil)
        #expect(EditorNotice.aiDraft.sectionsLine == nil)
    }

    @Test("Dismissing a notice that leads to a review asks first, as the review goes with it; one with nothing to review does not")
    func confirmsDismissal() {
        let review = ImportReview(items: [], notImported: "Driving licence: B")

        #expect(EditorNotice.imported(review).confirmsDismissal)
        #expect(EditorNotice.importedDescription(review).confirmsDismissal)
        #expect(!EditorNotice.imported(ImportReview(items: [], notImported: "")).confirmsDismissal)
        #expect(!EditorNotice.aiDraft.confirmsDismissal)
        #expect(!EditorNotice.aiDraftUnchecked.confirmsDismissal)
    }

    @Test("The lines that name the sections and the texts of the dismissal are in the string catalog, with the headings in them")
    func sectionAndDismissalTextsAreTranslated() {
        for key in ["editor.notice.imported.section", "editor.notice.imported.sections"] {
            #expect(key.localized != key, "\(key) is missing from the string catalog")
            #expect(key.localizedWithArgs("OWN VENTURES").contains("OWN VENTURES"), "\(key) names the headings")
        }
        for key in ["editor.notice.dismiss", "editor.notice.dismiss.title", "editor.notice.dismiss.message", "editor.notice.dismiss.confirm"] {
            #expect(key.localized != key, "\(key) is missing from the string catalog")
        }
    }
}

@Suite("ImportReview passages by where they stood (#452)")
struct ImportReviewPassageTests {

    @Test("A passage's header says where it stood in the CV, and a section's names its heading")
    func headers() {
        let top = ImportReview.Passage(place: .top, text: "EU citizen", isWholeSection: false)
        let section = ImportReview.Passage(place: .section("OWN VENTURES"), text: "Tidepool Notes", isWholeSection: true)
        let elsewhere = ImportReview.Passage(place: .elsewhere, text: "Driving licence: B", isWholeSection: false)

        #expect(top.headerKey == "import.review.place.top")
        #expect(section.headerKey == "import.review.place.section")
        #expect(elsewhere.headerKey == "import.review.not_imported_title", "No place: the review's old header")
        #expect(top.heading == nil)
        #expect(section.heading == "OWN VENTURES")
        #expect(elsewhere.heading == nil)
    }

    @Test("Each header is in the string catalog, and a section's names the heading")
    func headersAreTranslated() {
        for place in [ImportReview.Passage.Place.top, .section("OWN VENTURES"), .elsewhere] {
            let key = ImportReview.Passage(place: place, text: "Tidepool Notes", isWholeSection: false).headerKey
            #expect(key.localized != key, "\(key) is missing from the string catalog")
        }
        #expect("import.review.place.section".localizedWithArgs("OWN VENTURES").contains("OWN VENTURES"))
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
