// This file imports nothing of the domain, the application layer or the ports, and not `@testable`: what it uses is
// what a view sees. Foundation is there for the file's URL and the pasted PDF's bytes, as a view has them.
import Foundation
import Testing
import PrestoCVPresentation

/// Every public member of the import screen, of its review and of the values they show, each with its type spelled out.
/// It compiles only while each type is the presentation's own: a domain or port type in the public surface breaks it.
@MainActor
func useEveryPublicMember(of screen: ImportViewModel, file: URL, pdf: Data) {
    let _: String = screen.text
    screen.text = "Ada Ferro"
    let _: ImportSource? = screen.source
    let _: ImportStatus = screen.status
    let _: Bool = screen.canImportText
    if let draft: ImportedDraft = screen.result {
        let _: EditorStart = draft.start
        let _: SaveStatus? = draft.saving
        let review: ImportReview = draft.review
        let _: ImportSource = review.source
        let _: String = review.notImported
        for entry: ReviewEntry in review.entries {
            let _: ReviewedField = entry.field
            let _: ReviewReason = entry.reason
            let _: String = entry.text
        }
        let notice = ImportReviewViewModel(review: review)
        let _: [ReviewEntry] = notice.entries
        let _: String = notice.notImported
        let _: Bool = notice.hasEntries
        let _: Bool = notice.hasNotImported
        let _: Bool = notice.isShown
        notice.dismiss()
        notice.editorStored()
    }
    let _: [ReviewReason] = ReviewReason.allCases
    let _: [ImportProblem] = ImportProblem.allCases
    screen.paste(["Ada Ferro"], pdfs: [])
    screen.opened()
    screen.importText()
    screen.cancel()
    screen.paste([], pdfs: [pdf])
    screen.cancel()
    screen.importFile(at: file)
    screen.cancel()
    screen.fileNotOpened()
    screen.clearProblem()
}

@MainActor
@Suite("Import public surface")
struct ImportSurfaceTests {

    @Test("the import API holds no domain or port type: this file uses all of it importing only the presentation")
    func noDomainTypeInTheImportAPI() async {
        let world = ImportWorld()
        let screen = world.model()
        screen.text = "Ada Ferro"
        screen.importText()
        await waitUntil("the draft") { screen.status == .ready }

        useEveryPublicMember(of: screen, file: ImportValues.file, pdf: ImportValues.pdf)

        #expect(screen.status == .idle)
        #expect(screen.result == nil)
    }

    @Test("what the import screen shows of its state, its problems, its sources and its review are codes")
    func importStatusesCarryNoText() {
        let sources: [ImportSource] = [.pasted, .file]
        let values: [Any] = everyImportStatus() + ImportProblem.allCases + sources + ReviewReason.allCases
            + everyReviewedField()

        #expect(values.flatMap { strings(in: $0) }.isEmpty)
        #expect(Set(everyImportStatus()).count == everyImportStatus().count)
    }
}

func everyImportStatus() -> [ImportStatus] {
    let all: [ImportStatus] = [.idle, .importing, .ready] + ImportProblem.allCases.map(ImportStatus.failed)
    for status in all {
        switch status {
        case .idle, .importing, .failed, .ready: break
        }
    }
    return all
}

func everyReviewedField() -> [ReviewedField] {
    let all: [ReviewedField] = [.name, .title, .location, .summary, .experience(1), .experiencePeriod(1), .education(1),
                                .educationPeriod(1), .educationLocation(1), .language(1), .languageNotKept(1),
                                .certificationYear(1), .certification(1)]
    for field in all {
        switch field {
        case .name, .title, .location, .summary, .experience, .experiencePeriod, .education, .educationPeriod,
             .educationLocation, .language, .languageNotKept, .certificationYear, .certification:
            break
        }
    }
    return all
}
