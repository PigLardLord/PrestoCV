import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// A save is confirmed in the editor, briefly and without a dialog, and the editor can then be left with Done.
@MainActor
@Suite("CVEditorViewModel Tests - the inline confirmation of a save")
struct CVEditorSavedConfirmationTests {

    private func makeEditor(cvId: String? = nil, cvs: MockCVManagementUseCase = MockCVManagementUseCase()) -> (CVEditorViewModel, HeldSleeps) {
        let sleeps = HeldSleeps()
        let viewModel = CVEditorViewModel(cvId: cvId, cvManagementUseCase: cvs, sleep: { try await sleeps.sleep(for: $0) })
        return (viewModel, sleeps)
    }

    @Test("A save is confirmed for a few seconds, and then the confirmation goes by itself")
    func saveIsConfirmedForAFewSeconds() async {
        let (viewModel, sleeps) = makeEditor()
        viewModel.cv.personalInfo.name = "Marta Rinaldi"

        await viewModel.handleSaveButtonTap()
        #expect(viewModel.showsSavedConfirmation)
        #expect(viewModel.showingCancelConfirmation == false)

        await sleeps.waitUntilStarted(1)
        await sleeps.endAll()
        #expect(await finishes { await waitUntilHidden(viewModel) })
    }

    @Test("The next edit takes the confirmation away: the CV on screen is no longer the one saved")
    func nextEditTakesTheConfirmationAway() async {
        let (viewModel, _) = makeEditor()
        viewModel.cv.personalInfo.name = "Marta Rinaldi"
        await viewModel.handleSaveButtonTap()

        viewModel.cv.personalInfo.title = "Nurse"

        #expect(viewModel.showsSavedConfirmation == false)
    }

    @Test("A failed save is not confirmed")
    func failedSaveIsNotConfirmed() async {
        let cvs = MockCVManagementUseCase()
        await cvs.setCreateCVResult(.failure(AppError.fileSystemError("disk full")))
        let (viewModel, _) = makeEditor(cvs: cvs)
        viewModel.cv.personalInfo.name = "Marta Rinaldi"

        await viewModel.handleSaveButtonTap()

        #expect(viewModel.showsSavedConfirmation == false)
        #expect(viewModel.isShowingError)
    }

    @Test("The editor of a new CV is left with Cancel until the CV is saved, and with Done afterwards")
    func newCVIsLeftWithCancelUntilSaved() async {
        let (viewModel, _) = makeEditor()
        #expect(viewModel.exit == .cancel)

        viewModel.cv.personalInfo.name = "Marta Rinaldi"
        #expect(viewModel.exit == .cancel)

        await viewModel.handleSaveButtonTap()
        #expect(viewModel.exit == .done, "Everything is saved: leaving loses nothing")

        viewModel.cv.personalInfo.title = "Nurse"
        #expect(viewModel.exit == .cancel, "An edit after the save is not saved")
    }

    @Test("A stored CV opened without edits is left with Done")
    func storedCVWithoutEditsIsLeftWithDone() async {
        let stored = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi"))
        let cvs = MockCVManagementUseCase()
        await cvs.storeCV(stored)
        let (viewModel, _) = makeEditor(cvId: stored.id.uuidString, cvs: cvs)

        await viewModel.loadCV()

        #expect(viewModel.exit == .done)
        #expect(viewModel.requestLeaving())
    }

    private func waitUntilHidden(_ viewModel: CVEditorViewModel) async {
        for await isShown in viewModel.$showsSavedConfirmation.values where !isShown {
            return
        }
    }
}
