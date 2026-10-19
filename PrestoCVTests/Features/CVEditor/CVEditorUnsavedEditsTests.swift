import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// What the editor keeps on the device while it has unsaved edits, so that they outlive the app when iOS ends it.
@MainActor
@Suite("CVEditorViewModel Tests - keeping unsaved edits")
struct CVEditorUnsavedEditsTests {

    private struct Editor {
        let viewModel: CVEditorViewModel
        let editing: UUID
        let repository: InMemoryUnsavedEditsRepository
        let sleeps: HeldSleeps
        let cvs: MockCVManagementUseCase

        /// What the editor has kept, if anything.
        var kept: UnsavedEdits? {
            get async { await repository.kept[editing] }
        }
    }

    private func makeEditor(
        cvId: String? = nil,
        restoring edits: UnsavedEdits? = nil,
        repository: InMemoryUnsavedEditsRepository = InMemoryUnsavedEditsRepository(),
        cvs: MockCVManagementUseCase = MockCVManagementUseCase(),
        useCase sharedUseCase: UnsavedEditsUseCase? = nil
    ) -> Editor {
        let sleeps = HeldSleeps()
        let editing = edits?.id ?? UUID()
        let useCase = sharedUseCase ?? UnsavedEditsUseCase(repository: repository, now: { Date(timeIntervalSince1970: 1_700_000_000) })
        let keeper = UnsavedEditsKeeper(editing: editing, useCase: useCase, wait: { try await sleeps.sleep(for: $0) })
        let viewModel = CVEditorViewModel(
            cvId: cvId,
            restoring: edits,
            cvManagementUseCase: cvs,
            unsavedEdits: keeper,
            sleep: { _ in }
        )
        return Editor(viewModel: viewModel, editing: editing, repository: repository, sleeps: sleeps, cvs: cvs)
    }

    private func edits(of cv: CVModel, over base: CVModel?) -> UnsavedEdits {
        UnsavedEdits(id: UUID(), cv: cv, base: base, keptAt: Date(timeIntervalSince1970: 1_600_000_000))
    }

    // MARK: - Keeping

    @Test("Edits are kept a few seconds after a change, with the form as it is then")
    func editsAreKeptAFewSecondsAfterAChange() async {
        let editor = makeEditor()
        await editor.viewModel.loadCV()

        editor.viewModel.cv.personalInfo.name = "Marta"
        await editor.sleeps.waitUntilStarted(1)
        #expect(await editor.repository.writeCount == 0, "Nothing is written on every keystroke")
        editor.viewModel.cv.personalInfo.name = "Marta Rinaldi"
        #expect(await editor.sleeps.startedCount == 1, "The changes of the next seconds share one write")

        await editor.sleeps.endAll()
        #expect(await finishes { await editor.repository.waitForWrites(1) })

        let kept = await editor.kept
        #expect(kept?.cv.personalInfo.name == "Marta Rinaldi")
        #expect(kept?.base == nil, "A CV never saved is kept as a new CV")
        #expect(kept?.cv.id == editor.viewModel.cv.id, "The edits name the id the CV will be stored under")
    }

    @Test("When the scene leaves the foreground the edits are kept at once; when it comes back nothing is written")
    func sceneLeavingTheForegroundKeepsTheEdits() async {
        let editor = makeEditor()
        await editor.viewModel.loadCV()
        editor.viewModel.cv.personalInfo.name = "Marta Rinaldi"

        await editor.viewModel.sceneDidChange(isActive: true)
        #expect(await editor.repository.writeCount == 0, "Coming back to the foreground writes nothing")

        await editor.viewModel.sceneDidChange(isActive: false)
        #expect(await editor.kept?.cv.personalInfo.name == "Marta Rinaldi")
    }

    @Test("Leaving the foreground keeps the edits at once")
    func leavingTheForegroundKeepsTheEditsAtOnce() async {
        let editor = makeEditor()
        await editor.viewModel.loadCV()
        editor.viewModel.cv.personalInfo.name = "Marta Rinaldi"

        await editor.viewModel.keepUnsavedEdits()

        #expect(await editor.kept?.cv.personalInfo.name == "Marta Rinaldi")
    }

    @Test("A form with nothing unsaved keeps nothing")
    func nothingUnsavedKeepsNothing() async {
        let editor = makeEditor()
        await editor.viewModel.loadCV()

        await editor.viewModel.keepUnsavedEdits()

        #expect(await editor.kept == nil)
    }

    @Test("Undoing every edit removes what was kept")
    func undoingEveryEditRemovesWhatWasKept() async {
        let editor = makeEditor()
        await editor.viewModel.loadCV()
        editor.viewModel.cv.personalInfo.name = "Marta Rinaldi"
        await editor.viewModel.keepUnsavedEdits()

        editor.viewModel.cv.personalInfo.name = ""
        await editor.viewModel.keepUnsavedEdits()

        #expect(await editor.kept == nil)
    }

    @Test("A failure to keep the edits leaves the form and Save as they were")
    func failureToKeepLeavesTheForm() async {
        let editor = makeEditor()
        await editor.viewModel.loadCV()
        await editor.repository.fail(with: AppError.fileSystemError("disk full"))
        editor.viewModel.cv.personalInfo.name = "Marta Rinaldi"

        await editor.viewModel.keepUnsavedEdits()

        #expect(editor.viewModel.cv.personalInfo.name == "Marta Rinaldi")
        #expect(editor.viewModel.saveError == nil, "Keeping a copy is not the person's save: it raises no alert")
        #expect(await editor.viewModel.saveCV())
    }

    // MARK: - Saving and leaving

    @Test("Saving removes what was kept, so that a relaunch does not create the CV again")
    func savingRemovesWhatWasKept() async {
        let editor = makeEditor()
        await editor.viewModel.loadCV()
        editor.viewModel.cv.personalInfo.name = "Marta Rinaldi"
        await editor.viewModel.keepUnsavedEdits()

        #expect(await editor.viewModel.saveCV())

        #expect(await editor.kept == nil)
    }

    @Test("Edits made after the first save are kept as edits of the stored CV, so that restoring them updates it")
    func editsAfterTheFirstSaveBelongToTheStoredCV() async {
        let editor = makeEditor()
        await editor.viewModel.loadCV()
        editor.viewModel.cv.personalInfo.name = "Marta Rinaldi"
        _ = await editor.viewModel.saveCV()
        let createdId = await editor.cvs.createdCVs.first?.id

        editor.viewModel.cv.personalInfo.email = "marta@example.com"
        await editor.viewModel.keepUnsavedEdits()

        let kept = await editor.kept
        #expect(kept?.cv.id == createdId)
        #expect(kept?.base == (await editor.cvs.createdCVs.first), "The edits were made on the CV as it was saved")
        #expect(kept?.cv.personalInfo.email == "marta@example.com")
    }

    // MARK: - The first save of a new CV

    @Test("A new CV gets an id of its own when its editing begins, and its first save stores it under that id")
    func newCVIsStoredUnderTheIdItGotAtTheStart() async {
        let template = CVModel(name: "Sample")
        let cvs = MockCVManagementUseCase()
        let first = CVEditorViewModel(cvId: nil, initialCV: template, cvManagementUseCase: cvs)
        let second = CVEditorViewModel(cvId: nil, initialCV: template, cvManagementUseCase: cvs)
        let startID = first.cv.id

        first.cv.personalInfo.name = "Marta Rinaldi"
        #expect(await first.saveCV())

        #expect(startID != template.id, "Two CVs started from one template must not share an id")
        #expect(second.cv.id != startID)
        #expect(await cvs.createdCVs.map(\.id) == [startID])
        #expect(first.cv.id == startID)
    }

    @Test("Before a first save stores the CV, the kept edits name its id and what the save stores")
    func firstSaveKeepsTheEditsBeforeItStores() async {
        let repository = InMemoryUnsavedEditsRepository()
        let gated = GatedCVManagementUseCase(gating: .create)
        let editing = UUID()
        let useCase = UnsavedEditsUseCase(repository: repository, now: { Date() })
        let viewModel = CVEditorViewModel(
            cvId: nil,
            cvManagementUseCase: gated,
            unsavedEdits: UnsavedEditsKeeper(editing: editing, useCase: useCase, wait: { _ in try await Task.sleep(for: .seconds(3600)) }),
            sleep: { _ in }
        )
        await viewModel.loadCV()
        viewModel.cv.personalInfo.name = "Marta Rinaldi"
        let submitted = viewModel.cv

        let saving = Task { await viewModel.saveCV() }
        await gated.waitUntilGatedCallStarts()
        let keptWhileStoring = await repository.kept[editing]
        viewModel.cv.personalInfo.title = "Staff nurse"
        await viewModel.keepUnsavedEdits()
        let keptAfterAnEditDuringTheSave = await repository.kept[editing]
        await gated.openGate()
        #expect(await saving.value)

        #expect(keptWhileStoring?.cv.id == (await gated.createdCVs.first?.id), "The edits name the CV being stored")
        #expect(keptWhileStoring?.base == submitted, "The edits say what the save stores")
        #expect(keptAfterAnEditDuringTheSave?.base == submitted, "An edit made during the save is made on what it stores")
        #expect(await repository.kept[editing]?.base == submitted, "Once stored, that is what the edits were made on")
    }

    @Test("A save that fails puts the kept edits back on what was stored before")
    func failedSavePutsTheEditsBack() async {
        let cvs = MockCVManagementUseCase()
        await cvs.setCreateCVResult(.failure(AppError.fileSystemError("disk full")))
        let editor = makeEditor(cvs: cvs)
        await editor.viewModel.loadCV()
        editor.viewModel.cv.personalInfo.name = "Marta Rinaldi"

        #expect(await editor.viewModel.saveCV() == false)

        #expect(await editor.kept?.base == nil, "Nothing was stored: the edits are on no stored CV")
        #expect(await editor.kept?.cv.personalInfo.name == "Marta Rinaldi")
    }

    // MARK: - A save whose kept edits cannot be brought up to date

    @Test("A failed save whose edits could be neither brought up to date nor kept again leaves the older edits, restored after a relaunch")
    func failedSaveLeavesTheOlderEditsForARelaunch() async throws {
        let cvs = MockCVManagementUseCase()
        await cvs.setCreateCVResult(.failure(AppError.fileSystemError("disk full")))
        let editor = makeEditor(cvs: cvs)
        await editor.viewModel.loadCV()
        editor.viewModel.cv.personalInfo.name = "Marta"
        await editor.viewModel.keepUnsavedEdits()
        editor.viewModel.cv.personalInfo.name = "Marta Rinaldi"
        await editor.repository.failKeeping(with: AppError.fileSystemError("disk full"))

        #expect(await editor.viewModel.saveCV() == false)

        // The app is ended, and launched again over the same store
        await editor.repository.failKeeping(with: nil)
        let relaunch = UnsavedEditsUseCase(repository: editor.repository, now: { Date() })
        let offered = try #require(await relaunch.editsToRestoreOrNil(), "The edits kept before the save must still be there")
        let restored = makeEditor(restoring: offered, repository: editor.repository, useCase: relaunch)
        await restored.viewModel.loadCV()
        #expect(restored.viewModel.cv.personalInfo.name == "Marta")
    }

    @Test("A save whose edits cannot be brought up to date, while older edits of the CV are kept, stores nothing and says why")
    func saveStoresNothingWhileOlderEditsAreKept() async {
        let editor = makeEditor()
        await editor.viewModel.loadCV()
        editor.viewModel.cv.personalInfo.name = "Marta"
        await editor.viewModel.keepUnsavedEdits()
        let keptBefore = await editor.kept
        editor.viewModel.cv.personalInfo.name = "Marta Rinaldi"
        await editor.repository.failKeeping(with: AppError.fileSystemError("disk full"))

        #expect(await editor.viewModel.saveCV() == false)

        #expect(await editor.cvs.createCVCallCount == 0, "Once the CV is stored, a restore would take the older edits for a second CV")
        #expect(await editor.kept == keptBefore, "The older edits stay: they may be all that outlives the app")
        #expect(editor.viewModel.saveError == "editor.save_error.not_kept".localized)
        #expect(editor.viewModel.cv.personalInfo.name == "Marta Rinaldi", "The form keeps the edits")
        #expect(editor.viewModel.isSaveButtonEnabled, "Save can be tried again")
    }

    @Test("Kept edits that already hold what a save stores do not stop it when they cannot be brought up to date, and are not restored")
    func keptEditsThatHoldWhatASaveStoresDoNotStopIt() async {
        let editor = makeEditor()
        await editor.viewModel.loadCV()
        editor.viewModel.cv.personalInfo.name = "Marta Rinaldi"
        await editor.viewModel.keepUnsavedEdits()
        await editor.repository.failKeeping(with: AppError.fileSystemError("disk full"))
        await editor.repository.failDiscarding(with: AppError.fileSystemError("disk full"))

        #expect(await editor.viewModel.saveCV())
        #expect(await editor.cvs.createdCVs.map(\.personalInfo.name) == ["Marta Rinaldi"])

        // The kept edits could not be removed after the save either; the app is launched again over the same store
        await editor.repository.failKeeping(with: nil)
        await editor.repository.failDiscarding(with: nil)
        let offer = UnsavedEditsOfferViewModel(
            useCase: UnsavedEditsUseCase(repository: editor.repository, now: { Date() }),
            cvs: editor.cvs
        )
        await offer.checkForEditsToRestore()
        #expect(offer.offer == nil, "The stored CV holds the edits: restoring them would store it again")
        #expect(await editor.repository.kept.isEmpty)
        #expect(await editor.cvs.createCVCallCount == 1)
    }

    @Test("Discarding the edits removes what was kept, and nothing more is kept afterwards")
    func discardingRemovesWhatWasKept() async {
        let editor = makeEditor()
        await editor.viewModel.loadCV()
        editor.viewModel.cv.personalInfo.name = "Marta Rinaldi"
        await editor.viewModel.keepUnsavedEdits()
        editor.viewModel.cv.personalInfo.title = "Nurse"
        await editor.sleeps.waitUntilStarted(1)

        #expect(editor.viewModel.requestLeaving() == false)
        editor.viewModel.confirmCancel()
        #expect(await finishes { await editor.repository.waitForWrites(2) })
        await editor.sleeps.endAll()

        #expect(await editor.kept == nil)
        #expect(await editor.repository.writeCount == 2, "A change waiting to be kept must not bring the edits back")
    }

    @Test("Leaving with nothing unsaved removes what was kept before the edits were undone")
    func leavingWithNothingUnsavedRemovesWhatWasKept() async {
        let stored = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi"))
        let cvs = MockCVManagementUseCase()
        await cvs.storeCV(stored)
        let editor = makeEditor(cvId: stored.id.uuidString, cvs: cvs)
        await editor.viewModel.loadCV()
        editor.viewModel.cv.personalInfo.title = "Nurse"
        await editor.viewModel.keepUnsavedEdits()
        #expect(await editor.kept != nil)

        editor.viewModel.cv.personalInfo.title = ""
        #expect(editor.viewModel.requestLeaving() == true)

        #expect(await finishes { await editor.repository.waitForWrites(2) })
        #expect(await editor.kept == nil)
    }

    // MARK: - Restoring

    @Test("Restored edits of a CV never saved open as a new CV, which a save creates once")
    func restoredNewCVIsCreatedOnce() async throws {
        let restored = edits(of: CVModel(personalInfo: PersonalInfo(name: "Marta Rinaldi")), over: nil)
        let repository = InMemoryUnsavedEditsRepository()
        try await repository.keep(restored)
        let editor = makeEditor(restoring: restored, repository: repository)
        await editor.viewModel.loadCV()

        #expect(editor.viewModel.cv == restored.cv)
        #expect(editor.viewModel.hasUnsavedChanges)
        #expect(await editor.viewModel.saveCV())
        #expect(await editor.viewModel.saveCV() == false, "Nothing is left to save")

        #expect(await editor.cvs.createCVCallCount == 1)
        #expect(await editor.cvs.createdCVs.map(\.id) == [restored.cv.id], "The CV is stored under the id its edits name")
        #expect(await editor.cvs.updateCVCallCount == 0)
        #expect(await repository.kept.isEmpty, "Once saved, the edits are no longer offered to restore")
    }

    @Test("Restored edits of a stored CV open over it, and a save updates that CV instead of adding one")
    func restoredEditsUpdateTheStoredCV() async throws {
        let stored = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi"))
        var changed = stored
        changed.personalInfo.title = "Senior nurse"
        let cvs = MockCVManagementUseCase()
        await cvs.storeCV(stored)
        let restored = edits(of: changed, over: stored)
        let editor = makeEditor(restoring: restored, cvs: cvs)
        try await editor.repository.keep(restored)

        await editor.viewModel.loadCV()

        #expect(editor.viewModel.cv == changed)
        #expect(editor.viewModel.hasUnsavedChanges, "The restored edits are not saved yet")
        #expect(await editor.viewModel.saveCV())
        #expect(await cvs.createCVCallCount == 0, "Restoring must not duplicate the CV")
        #expect(await cvs.updatedCVs.map(\.id) == [stored.id])
        #expect(await cvs.updatedCVs.first?.personalInfo.title == "Senior nurse")
    }

    @Test("Older edits restored over a CV saved since open as a separate copy, and saving it leaves the newer CV as it is")
    func olderEditsOverANewerCVOpenAsACopy() async throws {
        let original = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi"))
        var olderEdits = original
        olderEdits.personalInfo.location = "Bristol"
        var newer = original
        newer.personalInfo.title = "Ward sister"
        let cvs = MockCVManagementUseCase()
        await cvs.storeCV(newer)
        let restored = edits(of: olderEdits, over: original)
        let editor = makeEditor(restoring: restored, cvs: cvs)
        try await editor.repository.keep(restored)

        await editor.viewModel.loadCV()

        #expect(editor.viewModel.cv.id != original.id, "The copy is a CV of its own")
        #expect(editor.viewModel.cv.name == "Ward nurse \("unsaved_edits.recovered_suffix".localized)")
        #expect(editor.viewModel.cv.personalInfo.location == "Bristol")
        #expect(await editor.viewModel.saveCV())
        #expect(await cvs.updateCVCallCount == 0, "The newer CV must not be replaced")
        #expect(try await cvs.getCV(by: original.id) == newer)
        #expect(await cvs.createdCVs.map(\.id) == [editor.viewModel.cv.id])
    }

    @Test("Restored edits of a CV deleted since make a new CV, rather than being lost")
    func restoredEditsOfADeletedCVMakeANewCV() async throws {
        let deletedId = UUID()
        let restored = edits(
            of: CVModel(id: deletedId, personalInfo: PersonalInfo(name: "Marta Rinaldi")),
            over: CVModel(id: deletedId, personalInfo: PersonalInfo(name: "Marta"))
        )
        let editor = makeEditor(restoring: restored)
        try await editor.repository.keep(restored)

        await editor.viewModel.loadCV()

        #expect(editor.viewModel.viewState.data != nil, "The editor shows the edits")
        #expect(editor.viewModel.cv.personalInfo.name == "Marta Rinaldi")
        #expect(await editor.viewModel.saveCV())
        #expect(await editor.cvs.createdCVs.map(\.id) == [deletedId])
    }

    @Test("Restored edits are held by their editor, so no other window offers them; when it goes away they are offered again")
    func restoredEditsAreHeldByTheirEditor() async throws {
        let restored = edits(of: CVModel(personalInfo: PersonalInfo(name: "Marta Rinaldi")), over: nil)
        let repository = InMemoryUnsavedEditsRepository()
        try await repository.keep(restored)
        let app = UnsavedEditsUseCase(repository: repository, now: { Date() })
        var editor: Editor? = makeEditor(restoring: restored, repository: repository, useCase: app)
        #expect(await app.editsToRestoreOrNil() != nil, "Before an editor holds them, they are offered")

        await editor?.viewModel.loadCV()
        #expect(await app.editsToRestoreOrNil() == nil, "Another window must not offer edits an editor holds")
        #expect(await repository.kept[restored.id]?.cv == restored.cv)

        editor = nil
        #expect(await finishes { await waitUntilOffered(by: app) }, "Edits an editor left behind are offered again")
    }

    @Test("An editor that cannot load the CV leaves the restored edits as they are and lets go of them, also when it is left")
    func editorThatCouldNotLoadLetsGoOfTheEdits() async throws {
        let storedId = UUID()
        let restored = edits(
            of: CVModel(id: storedId, personalInfo: PersonalInfo(name: "Marta Rinaldi")),
            over: CVModel(id: storedId, personalInfo: PersonalInfo(name: "Marta"))
        )
        let repository = InMemoryUnsavedEditsRepository()
        try await repository.keep(restored)
        let app = UnsavedEditsUseCase(repository: repository, now: { Date() })
        let cvs = MockCVManagementUseCase()
        await cvs.setGetCVResult(.failure(AppError.fileSystemError("locked")))
        var editor: Editor? = makeEditor(restoring: restored, repository: repository, cvs: cvs, useCase: app)

        await editor?.viewModel.loadCV()
        #expect(editor?.viewModel.viewState.errorMessage != nil)
        #expect(await app.editsToRestoreOrNil() == restored, "Another window offers the edits this editor could not show")
        await editor?.viewModel.keepUnsavedEdits()
        #expect(editor?.viewModel.requestLeaving() == true)
        editor = nil
        await Task.yield()

        #expect(await repository.writeCount == 1, "Only the test wrote: the editor touched nothing")
        #expect(await repository.kept[restored.id] == restored)
        #expect(await app.editsToRestoreOrNil() == restored, "Once the window closes, they are still offered")
    }

    @Test("A retry after a failed load takes the edits back, unless another window took them meanwhile")
    func retryTakesTheEditsBackUnlessTakenMeanwhile() async throws {
        let stored = CVModel(name: "Ward nurse")
        var edited = stored
        edited.personalInfo.location = "Bristol"
        let restored = edits(of: edited, over: stored)
        let repository = InMemoryUnsavedEditsRepository()
        try await repository.keep(restored)
        let app = UnsavedEditsUseCase(repository: repository, now: { Date() })
        let cvs = MockCVManagementUseCase()
        await cvs.storeCV(stored)
        await cvs.setGetCVResult(.failure(AppError.fileSystemError("locked")))
        let editor = makeEditor(restoring: restored, repository: repository, cvs: cvs, useCase: app)
        await editor.viewModel.loadCV()

        let otherWindow = try #require(try await app.claim(restored))
        await cvs.setGetCVResult(.success(nil))
        await editor.viewModel.loadCV()
        #expect(editor.viewModel.viewState.errorMessage == "unsaved_edits.unavailable.message".localized)

        await app.release(otherWindow)
        await editor.viewModel.loadCV()
        #expect(editor.viewModel.cv == edited, "Released by the other window, the edits come back to this editor")
    }

    /// Returns once `app` offers edits again.
    private func waitUntilOffered(by app: UnsavedEditsUseCase) async {
        while await app.editsToRestoreOrNil() == nil, !Task.isCancelled {
            await Task.yield()
        }
    }
}

private extension UnsavedEditsUseCase {
    /// The edits offered to restore, with a failure read as none.
    func editsToRestoreOrNil() async -> UnsavedEdits? {
        do {
            return try await editsToRestore()
        } catch {
            return nil
        }
    }
}
