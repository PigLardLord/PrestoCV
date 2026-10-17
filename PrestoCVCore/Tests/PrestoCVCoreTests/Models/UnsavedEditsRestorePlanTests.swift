import Testing
import Foundation
@testable import PrestoCVCore

/// How kept edits go back into the editor, given what is stored under their CV's id and under the id of their copy.
@Suite("Unsaved edits restore plan Tests")
struct UnsavedEditsRestorePlanTests {

    private let stored = CVTestDataBuilder.minimalCV().withName("Ward nurse").build()

    private func edits(_ cv: CVModel, over base: CVModel?) -> UnsavedEdits {
        UnsavedEdits(id: UUID(), cv: cv, base: base, keptAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private func edited(_ cv: CVModel) -> CVModel {
        var edited = cv
        edited.personalInfo.title = "Senior nurse"
        return edited
    }

    @Test("Edits of a CV that nothing is stored under make it under their id")
    func nothingStoredMakesTheCV() {
        #expect(edits(stored, over: nil).restorePlan(over: nil, copy: nil) == .create)
        #expect(edits(stored, over: stored).restorePlan(over: nil, copy: nil) == .create, "A CV deleted since is made again, not lost")
    }

    @Test("Edits that the stored CV already holds are already saved")
    func editsTheStoredCVHoldsAreSaved() {
        #expect(edits(stored, over: stored).restorePlan(over: stored, copy: nil) == .alreadySaved)
        #expect(edits(stored, over: nil).restorePlan(over: stored, copy: nil) == .alreadySaved, "A first save ended before its edits were removed")
    }

    @Test("Edits made on the stored CV as it is now update it")
    func editsOnTheStoredCVUpdateIt() {
        #expect(edits(edited(stored), over: stored).restorePlan(over: stored, copy: nil) == .update)
    }

    @Test("The id of a copy comes from the edits: the same every time, and of no other CV")
    func copyIDComesFromTheEdits() {
        let kept = edits(edited(stored), over: stored)
        let sameEditsReadAgain = UnsavedEdits(id: kept.id, cv: kept.cv, base: kept.base, keptAt: kept.keptAt.addingTimeInterval(60))
        let otherEditing = edits(edited(stored), over: stored)

        #expect(kept.copyID == sameEditsReadAgain.copyID, "Restoring the edits as a copy again targets the same CV")
        #expect(kept.copyID != kept.cv.id)
        #expect(kept.copyID != otherEditing.copyID)
        #expect(kept.copyID.uuidString.dropFirst(14).first == "5", "A name-based identifier, version 5")
    }

    @Test("Edits made on a version of the CV that was saved over since become a separate copy, so nothing newer is replaced")
    func editsOnAnOlderVersionBecomeACopy() {
        var newer = stored
        newer.personalInfo.location = "Bristol"

        #expect(edits(edited(stored), over: stored).restorePlan(over: newer, copy: nil) == .copy)
        #expect(edits(edited(stored), over: nil).restorePlan(over: newer, copy: nil) == .copy, "Edits on no stored CV never replace one")
    }

    @Test("Edits whose copy is stored were restored as it before: the copy opens as it is stored, whatever the CV is now")
    func editsWhoseCopyIsStoredOpenTheCopy() {
        let kept = edits(edited(stored), over: stored)
        var newer = stored
        newer.personalInfo.location = "Bristol"
        var copy = kept.cv
        copy.id = kept.copyID
        copy.personalInfo.title = "Charge nurse"

        #expect(kept.restorePlan(over: newer, copy: copy) == .restoredAsCopy(copy))
        #expect(kept.restorePlan(over: stored, copy: copy) == .restoredAsCopy(copy))
        #expect(kept.restorePlan(over: nil, copy: copy) == .restoredAsCopy(copy), "The CV they were made on was deleted since")
        #expect(kept.restorePlan(over: kept.cv, copy: copy) == .restoredAsCopy(copy))
    }

    @Test("Edits open as a CV of their own when they become a copy, or were restored as one before")
    func whichPlansOpenACopy() {
        #expect(UnsavedEdits.RestorePlan.copy.opensAsCopy)
        #expect(UnsavedEdits.RestorePlan.restoredAsCopy(stored).opensAsCopy)
        #expect(!UnsavedEdits.RestorePlan.update.opensAsCopy)
        #expect(!UnsavedEdits.RestorePlan.create.opensAsCopy)
        #expect(!UnsavedEdits.RestorePlan.alreadySaved.opensAsCopy)
    }
}
