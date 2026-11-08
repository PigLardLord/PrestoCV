import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// From the import port's values to the screen's: one to one, in order, with the person's words as they are.
@Suite("Import mapping")
struct ImportProblemMappingTests {

    @Test("each reason an import gives no CV has a problem of its own")
    func eachImportFailureHasItsProblem() {
        let pairs: [(ImportFailure, ImportProblem)] = [
            (.empty, .empty), (.tooLarge, .tooLarge), (.tooManyPages, .tooManyPages), (.encrypted, .encrypted),
            (.unreadable, .unreadable), (.noText, .noText), (.fileNotRead, .fileNotRead),
        ]
        #expect(pairs.map(\.0) == ImportValues.everyFailure)
        for (failure, problem) in pairs {
            #expect(ImportProblem(failure) == problem)
        }
        #expect(Set(ImportValues.everyFailure.map(ImportProblem.init)) == Set(ImportProblem.allCases))
    }

    @Test("every reason to check a value has a mirror of the same name, and no two share one")
    func everyReviewReasonHasAMirror() {
        let mirrored = ImportReviewReason.allCases.map(ReviewReason.init)
        #expect(Set(mirrored) == Set(ReviewReason.allCases))
        #expect(mirrored.count == ReviewReason.allCases.count)
        for reason in ImportReviewReason.allCases {
            #expect(String(describing: ReviewReason(reason)) == reason.rawValue)
        }
    }

    @Test("every field to check has a mirror that keeps its entry number, and no two share one")
    func everyReviewFieldHasAMirror() {
        let expected: [ReviewedField] = [.name, .title, .location, .summary, .experience(1), .experiencePeriod(2),
                                         .education(3), .educationPeriod(4), .educationLocation(5), .language(6),
                                         .languageNotKept(7), .certificationYear(8)]
        let mirrored = ImportValues.everyField.map(ReviewedField.init)
        #expect(mirrored == expected)
        #expect(Set(mirrored).count == ImportValues.everyField.count)
    }

    @Test("the entries keep the import's order, its counting from one and the text as the person wrote it")
    func entriesKeepOrderCountingAndTheTextAsWritten() {
        let items = [
            ImportReviewItem(field: .experiencePeriod(2), reason: .periodOpenEnd, text: "03/2019 –"),
            ImportReviewItem(field: .name, reason: .nameByPosition, text: "  Ada   Ferro "),
            ImportReviewItem(field: .language(1), reason: .levelsDiffer, text: "Deutsch: B2 / C1\n"),
        ]
        let draft = ImportedDraft(ImportValues.outcome(review: items), from: .pasted)
        #expect(draft.review.entries == [
            ReviewEntry(field: .experiencePeriod(2), reason: .periodOpenEnd, text: "03/2019 –"),
            ReviewEntry(field: .name, reason: .nameByPosition, text: "  Ada   Ferro "),
            ReviewEntry(field: .language(1), reason: .levelsDiffer, text: "Deutsch: B2 / C1\n"),
        ])
        #expect(draft.review.source == .pasted)
    }

    @Test("the text not imported is whole, with its lines and spaces")
    func notImportedTextIsWhole() {
        let notImported = "Hobbies: sailing, chess\n\n  References on request  \nDriving licence B"
        let draft = ImportedDraft(ImportValues.outcome(notImported: notImported), from: .file)
        #expect(draft.review.notImported == notImported)
        #expect(draft.review.source == .file)
    }

    @Test("a CV that cannot be saved carries the reason the editor gives for it")
    func aCVThatCannotBeSavedCarriesItsReason() {
        let verdicts: [(SaveVerdict, SaveStatus)] = [
            (.notEnoughContent, .notEnoughContent), (.cvTooLarge, .tooLarge),
            (.textTooLong(.summary), .textTooLong(.summary)),
            (.tooManyEntries(.experiences), .tooManyEntries(.experiences)),
        ]
        for (verdict, status) in verdicts {
            #expect(ImportedDraft(ImportValues.outcome(saving: verdict), from: .pasted).saving == status)
        }
    }

    @Test("a CV that can be saved carries no reason, and its draft holds the CV of the import")
    func aCVThatCanBeSavedCarriesNone() throws {
        let outcome = ImportValues.outcome(name: "Bea Lund")
        let draft = ImportedDraft(outcome, from: .pasted)
        #expect(draft.saving == nil)
        guard case .draft(let opened) = draft.start else {
            Issue.record("no draft in \(draft.start)")
            return
        }
        #expect(opened.cv == outcome.cv)
    }
}
