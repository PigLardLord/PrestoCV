import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// Unsaved edits outlive the app being ended: the editor, the offer and the real file store, over the launches of
/// one installation in a temporary folder.
@MainActor
@Suite("Unsaved edits over a relaunch - editor, offer and file store working together")
struct UnsavedEditsRelaunchTests {

    /// The folders of one installation of the app, which outlive its launches.
    private struct Installation {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("test_relaunch_\(UUID().uuidString)")

        var cvs: URL { root.appendingPathComponent("CVs", isDirectory: true) }
        var unsavedEdits: URL { root.appendingPathComponent("UnsavedEdits", isDirectory: true) }

        /// One launch of the app, as the app makes it: a container, and the unsaved edits of that launch.
        /// - Parameter wrap: Puts a fault into the store of the unsaved edits.
        func launch(
            keepingThrough wrap: (UnsavedEditsRepositoryProtocol) -> UnsavedEditsRepositoryProtocol = { $0 }
        ) throws -> Launch {
            let cvs = self.cvs
            let repository = UnsavedEditsRepository(storageService: try FileStorageService(baseDirectory: unsavedEdits))
            return Launch(
                container: DependencyContainer(storageDirectory: { cvs }),
                unsavedEdits: UnsavedEditsUseCase(repository: wrap(repository), now: { Date() })
            )
        }

        /// The files of the edits that are kept.
        func keptFiles() throws -> [String] {
            try FileManager.default.contentsOfDirectory(atPath: unsavedEdits.path).filter { $0.hasSuffix(".json") }
        }

        /// The edits that are kept, as the store reads them.
        func keptEdits() async throws -> [UnsavedEdits] {
            try await UnsavedEditsRepository(storageService: try FileStorageService(baseDirectory: unsavedEdits)).allKept()
        }

        func remove() {
            try? FileManager.default.removeItem(at: root)
        }
    }

    /// One launch of the app.
    private struct Launch {
        let container: DependencyContainer
        let unsavedEdits: UnsavedEditsUseCase

        func makeCVManagementUseCase() throws -> CVManagementUseCaseProtocol {
            try container.makeCVManagementUseCase()
        }
    }

    /// An editor as the app opens it: on a new or stored CV, or on edits a window took to restore, with its claim.
    private func makeEditor(in launch: Launch, cvId: String? = nil, restoring restored: RestoredUnsavedEdits? = nil) throws -> CVEditorViewModel {
        CVEditorViewModel(
            cvId: cvId,
            restoring: restored?.edits,
            cvManagementUseCase: try launch.makeCVManagementUseCase(),
            unsavedEdits: UnsavedEditsKeeper(
                editing: restored?.edits.id ?? UUID(),
                claim: restored?.takeClaim(),
                useCase: launch.unsavedEdits
            )
        )
    }

    /// What the app offers at launch, taken up as the person does when they tap Restore.
    private func restoreOffer(in launch: Launch) async throws -> RestoredUnsavedEdits? {
        let offer = UnsavedEditsOfferViewModel(useCase: launch.unsavedEdits, cvs: try launch.makeCVManagementUseCase())
        await offer.checkForEditsToRestore()
        return await offer.restore()
    }

    /// The CVs the list of a launch shows.
    private func listedCVs(in launch: Launch) async throws -> [CVModel] {
        let list = CVListViewModel(cvManagementUseCase: try launch.makeCVManagementUseCase())
        await list.loadCVs()
        return try #require(list.viewState.data)
    }

    /// Edits of a stored CV, kept, and restored as a copy after another window saved the CV again, at a launch that can
    /// neither keep nor remove them: the copy is stored and then saved again with more edits, while the edits it was
    /// made of stay behind.
    /// - Returns: The CV the edits were made on, and the copy, as they are stored.
    private func copySavedAgainOverItsEdits(in installation: Installation) async throws -> (original: CVModel, copy: CVModel) {
        let firstLaunch = try installation.launch()
        let cvs = try firstLaunch.makeCVManagementUseCase()
        let original = try await cvs.createCV(from: CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi")))
        let editor = try makeEditor(in: firstLaunch, cvId: original.id.uuidString)
        await editor.loadCV()
        editor.cv.personalInfo.location = "Bristol"
        await editor.keepUnsavedEdits()
        var newer = original
        newer.personalInfo.title = "Ward sister"
        _ = try await cvs.updateCV(newer)

        let secondLaunch = try installation.launch(keepingThrough: { WritesFail($0) })
        let restored = try #require(try await restoreOffer(in: secondLaunch))
        let copyEditor = try makeEditor(in: secondLaunch, restoring: restored)
        await copyEditor.loadCV()
        #expect(await copyEditor.saveCV())
        copyEditor.cv.personalInfo.title = "Charge nurse"
        #expect(await copyEditor.saveCV())
        let copy = try #require(try await secondLaunch.makeCVManagementUseCase().getCV(by: copyEditor.cv.id))
        #expect(copy.personalInfo.title == "Charge nurse")
        return (newer, copy)
    }

    @Test("A new CV typed and sent to the background is offered after iOS ends the app, and saving it stores it once")
    func newCVSurvivesTheAppBeingEnded() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let firstLaunch = try installation.launch()
        let editor = try makeEditor(in: firstLaunch)
        await editor.loadCV()
        editor.cv.personalInfo.name = "Marta Rinaldi"
        editor.cv.personalInfo.title = "Staff nurse"
        await editor.keepUnsavedEdits()

        let secondLaunch = try installation.launch()
        let restored = try #require(try await restoreOffer(in: secondLaunch))
        let restoredEditor = try makeEditor(in: secondLaunch, restoring: restored)
        await restoredEditor.loadCV()
        #expect(restoredEditor.cv.personalInfo.name == "Marta Rinaldi")
        #expect(restoredEditor.cv.personalInfo.title == "Staff nurse")
        #expect(await restoredEditor.saveCV())

        let thirdLaunch = try installation.launch()
        let stored = try await thirdLaunch.makeCVManagementUseCase().getAllCVs()
        #expect(stored.count == 1, "The restored CV must be stored once")
        #expect(stored.first?.personalInfo.title == "Staff nurse")
        #expect(try await restoreOffer(in: thirdLaunch) == nil, "Saved edits are not offered again")
    }

    @Test("Edits of a stored CV survive the app being ended, and saving them updates that CV")
    func editsOfAStoredCVSurviveTheAppBeingEnded() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let firstLaunch = try installation.launch()
        let original = try await firstLaunch.makeCVManagementUseCase()
            .createCV(from: CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi")))
        let editor = try makeEditor(in: firstLaunch, cvId: original.id.uuidString)
        await editor.loadCV()
        editor.cv.personalInfo.location = "Bristol"
        await editor.keepUnsavedEdits()

        let secondLaunch = try installation.launch()
        let restored = try #require(try await restoreOffer(in: secondLaunch))
        #expect(restored.edits.cv.id == original.id)
        #expect(restored.edits.base == original)
        let restoredEditor = try makeEditor(in: secondLaunch, restoring: restored)
        await restoredEditor.loadCV()
        #expect(await restoredEditor.saveCV())

        let stored = try await installation.launch().makeCVManagementUseCase().getAllCVs()
        #expect(stored.map(\.id) == [original.id], "Restoring must not add a copy of the CV")
        #expect(stored.first?.personalInfo.location == "Bristol")
    }

    @Test("Edits discarded at the next launch are gone, and no CV is made of them")
    func discardedEditsAreGone() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let editor = try makeEditor(in: installation.launch())
        await editor.loadCV()
        editor.cv.personalInfo.name = "Marta Rinaldi"
        await editor.keepUnsavedEdits()

        let secondLaunch = try installation.launch()
        let offer = UnsavedEditsOfferViewModel(useCase: secondLaunch.unsavedEdits, cvs: try secondLaunch.makeCVManagementUseCase())
        await offer.checkForEditsToRestore()
        #expect(offer.offer != nil)
        await offer.discard()

        let thirdLaunch = try installation.launch()
        #expect(try await restoreOffer(in: thirdLaunch) == nil)
        #expect(try await thirdLaunch.makeCVManagementUseCase().getAllCVs().isEmpty)
    }

    @Test("A CV saved before the app was ended is not offered again")
    func savedCVIsNotOfferedAgain() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let firstLaunch = try installation.launch()
        let editor = try makeEditor(in: firstLaunch)
        await editor.loadCV()
        editor.cv.personalInfo.name = "Marta Rinaldi"
        await editor.keepUnsavedEdits()
        #expect(await editor.saveCV())
        await editor.keepUnsavedEdits()

        let secondLaunch = try installation.launch()
        #expect(try await restoreOffer(in: secondLaunch) == nil)
        #expect(try await secondLaunch.makeCVManagementUseCase().getAllCVs().count == 1)
    }

    @Test("Older edits restored after the CV was saved again elsewhere become a copy, and the newer CV stays as it is")
    func olderEditsOfACVSavedSinceBecomeACopy() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let firstLaunch = try installation.launch()
        let cvs = try firstLaunch.makeCVManagementUseCase()
        let original = try await cvs.createCV(from: CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi")))
        let editor = try makeEditor(in: firstLaunch, cvId: original.id.uuidString)
        await editor.loadCV()
        editor.cv.personalInfo.location = "Bristol"
        await editor.keepUnsavedEdits()
        // Another window saves the CV again before iOS ends the app
        var newer = original
        newer.personalInfo.title = "Ward sister"
        _ = try await cvs.updateCV(newer)

        let secondLaunch = try installation.launch()
        let restored = try #require(try await restoreOffer(in: secondLaunch))
        let restoredEditor = try makeEditor(in: secondLaunch, restoring: restored)
        await restoredEditor.loadCV()
        #expect(await restoredEditor.saveCV())

        let stored = try await installation.launch().makeCVManagementUseCase().getAllCVs()
        #expect(stored.count == 2, "The edits are a CV of their own")
        #expect(stored.first { $0.id == original.id } == newer, "The newer CV must not be replaced")
        let copy = try #require(stored.first { $0.id != original.id })
        #expect(copy.personalInfo.location == "Bristol")
        #expect(copy.name.hasPrefix("Ward nurse "))
    }

    @Test("A copy restored, stored, and then restored again after its edits could be neither kept nor removed is stored once")
    func aCopyRestoredTwiceIsStoredOnce() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let firstLaunch = try installation.launch()
        let cvs = try firstLaunch.makeCVManagementUseCase()
        let original = try await cvs.createCV(from: CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi")))
        let editor = try makeEditor(in: firstLaunch, cvId: original.id.uuidString)
        await editor.loadCV()
        editor.cv.personalInfo.location = "Bristol"
        await editor.keepUnsavedEdits()
        var newer = original
        newer.personalInfo.title = "Ward sister"
        _ = try await cvs.updateCV(newer)

        // The next launch restores the edits as a copy and stores it, but cannot write or remove its kept edits
        let secondLaunch = try installation.launch(keepingThrough: { WritesFail($0) })
        let restored = try #require(try await restoreOffer(in: secondLaunch))
        let copyEditor = try makeEditor(in: secondLaunch, restoring: restored)
        await copyEditor.loadCV()
        #expect(await copyEditor.saveCV())

        // The launch after that is offered the same edits again, as a copy
        let thirdLaunch = try installation.launch()
        let offeredAgain = try #require(try await restoreOffer(in: thirdLaunch))
        let copyEditorAgain = try makeEditor(in: thirdLaunch, restoring: offeredAgain)
        await copyEditorAgain.loadCV()
        _ = await copyEditorAgain.saveCV()

        let stored = try await installation.launch().makeCVManagementUseCase().getAllCVs()
        #expect(stored.count == 2, "The CV and one recovered copy: restoring as a copy again must not make another")
        #expect(stored.first { $0.id == original.id } == newer)
        #expect(copyEditorAgain.cv.id == copyEditor.cv.id)
    }

    @Test("Edits restored as a copy that was stored and saved again since open that copy as it is stored, and go")
    func editsOfACopySavedSinceOpenTheCopyAsItIsStored() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let (original, copy) = try await copySavedAgainOverItsEdits(in: installation)

        let thirdLaunch = try installation.launch()
        let offer = UnsavedEditsOfferViewModel(useCase: thirdLaunch.unsavedEdits, cvs: try thirdLaunch.makeCVManagementUseCase())
        await offer.checkForEditsToRestore()
        #expect(offer.restoresAsCopy, "The edits open as their copy")
        let restored = try #require(await offer.restore())
        let editor = try makeEditor(in: thirdLaunch, restoring: restored)
        await editor.loadCV()
        #expect(editor.cv == copy, "The copy opens as it is stored: the older edits are not laid over it")
        #expect(editor.hasUnsavedChanges == false)
        #expect(await editor.saveCV() == false, "There is nothing to save over the copy")
        #expect(try installation.keptFiles().isEmpty, "The edits are gone")

        let fourthLaunch = try installation.launch()
        #expect(try await restoreOffer(in: fourthLaunch) == nil, "Nothing is offered again")
        let listed = try await listedCVs(in: fourthLaunch)
        #expect(listed.count == 2, "The CV and its one recovered copy")
        #expect(listed.first { $0.id == original.id } == original)
        #expect(listed.first { $0.id == copy.id } == copy, "The copy keeps what was saved to it last")
    }

    @Test("Edits of a copy saved since that cannot be removed still open the copy as it is stored, and are offered again")
    func editsOfACopySavedSinceThatCannotBeRemovedLeaveTheCopyAsItIs() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let (original, copy) = try await copySavedAgainOverItsEdits(in: installation)

        let thirdLaunch = try installation.launch(keepingThrough: { RemovalFails($0) })
        let restored = try #require(try await restoreOffer(in: thirdLaunch))
        let editor = try makeEditor(in: thirdLaunch, restoring: restored)
        await editor.loadCV()
        #expect(editor.cv == copy, "The copy opens as it is stored")
        #expect(editor.hasUnsavedChanges == false)
        #expect(await editor.saveCV() == false)
        #expect(try await installation.keptEdits() == [restored.edits], "The edits could not be removed, and stay as they were")

        // The next launch offers them again, and they open the copy as it is stored again
        let fourthLaunch = try installation.launch()
        let offeredAgain = try #require(try await restoreOffer(in: fourthLaunch))
        let editorAgain = try makeEditor(in: fourthLaunch, restoring: offeredAgain)
        await editorAgain.loadCV()
        #expect(editorAgain.cv == copy)
        #expect(try installation.keptFiles().isEmpty)

        let listed = try await listedCVs(in: installation.launch())
        #expect(listed.count == 2, "The CV and its one recovered copy")
        #expect(listed.first { $0.id == original.id } == original)
        #expect(listed.first { $0.id == copy.id } == copy, "The copy keeps what was saved to it last")
    }

    @Test("Once edits are restored as a copy, every write of them names the copy, over the copy as it is stored")
    func editsRestoredAsACopyAreKeptForTheCopy() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let firstLaunch = try installation.launch()
        let cvs = try firstLaunch.makeCVManagementUseCase()
        let original = try await cvs.createCV(from: CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi")))
        let editor = try makeEditor(in: firstLaunch, cvId: original.id.uuidString)
        await editor.loadCV()
        editor.cv.personalInfo.location = "Bristol"
        await editor.keepUnsavedEdits()
        var newer = original
        newer.personalInfo.title = "Ward sister"
        _ = try await cvs.updateCV(newer)

        let secondLaunch = try installation.launch()
        let restored = try #require(try await restoreOffer(in: secondLaunch))
        let editing = restored.edits.id
        let copyID = restored.edits.copyID
        let secondCVs = try secondLaunch.makeCVManagementUseCase()
        let ended = EndedAfterStoringNewCV(secondCVs)
        let copyEditor = CVEditorViewModel(
            cvId: nil,
            restoring: restored.edits,
            cvManagementUseCase: ended,
            unsavedEdits: UnsavedEditsKeeper(editing: editing, claim: restored.takeClaim(), useCase: secondLaunch.unsavedEdits)
        )

        // Restored: the copy is stored nowhere yet
        await copyEditor.loadCV()
        let afterRestore = try await installation.keptEdits()
        #expect(afterRestore.map(\.id) == [editing], "The edits the copy was made of are replaced, not kept beside it")
        #expect(afterRestore.first?.cv.id == copyID)
        #expect(afterRestore.first?.base == nil)

        // Edited while its first save stores it
        let saving = Task { await copyEditor.saveCV() }
        await ended.waitUntilStored()
        let storing = try #require(try await secondCVs.getCV(by: copyID))
        copyEditor.cv.personalInfo.title = "Charge nurse"
        await copyEditor.keepUnsavedEdits()
        let duringSave = try await installation.keptEdits()
        #expect(duringSave.map(\.id) == [editing])
        #expect(duringSave.first?.cv.id == copyID)
        #expect(duringSave.first?.base == storing, "Over what the save stores")
        await ended.letTheAppGoOn()
        #expect(await saving.value)

        // Edited after it
        await copyEditor.keepUnsavedEdits()
        let afterSave = try await installation.keptEdits()
        #expect(afterSave.map(\.id) == [editing])
        #expect(afterSave.first?.cv.id == copyID)
        #expect(afterSave.first?.base == storing, "Over the copy as it is stored")
        #expect(try await secondCVs.getCV(by: original.id) == newer)
    }

    // MARK: - The app ended in the middle of a first save

    @Test("A first save ended after the CV was stored and before its edits were removed is not stored a second time")
    func firstSaveEndedAfterStoringIsNotStoredAgain() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let firstLaunch = try installation.launch()
        let ended = EndedAfterStoringNewCV(try firstLaunch.makeCVManagementUseCase())
        let editor = CVEditorViewModel(
            cvId: nil,
            cvManagementUseCase: ended,
            unsavedEdits: UnsavedEditsKeeper(editing: UUID(), useCase: firstLaunch.unsavedEdits)
        )
        await editor.loadCV()
        editor.cv.personalInfo.name = "Marta Rinaldi"
        let saving = Task { await editor.saveCV() }
        await ended.waitUntilStored()

        // iOS ends the app here: the CV is stored, and its kept edits were not removed
        let secondLaunch = try installation.launch()
        let offered = try await restoreOffer(in: secondLaunch)
        let stored = try await secondLaunch.makeCVManagementUseCase().getAllCVs()
        let kept = try installation.keptFiles()
        await ended.letTheAppGoOn()
        _ = await saving.value

        #expect(offered == nil, "The stored CV already holds the edits: there is nothing to restore")
        #expect(stored.count == 1)
        #expect(kept.isEmpty, "The next launch removes edits that were saved")
    }

    @Test("Edits made while a first save was ended are restored onto the CV it stored, never as a second CV")
    func editsOfAFirstSaveEndedAfterStoringUpdateThatCV() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let firstLaunch = try installation.launch()
        let ended = EndedAfterStoringNewCV(try firstLaunch.makeCVManagementUseCase())
        let editor = CVEditorViewModel(
            cvId: nil,
            cvManagementUseCase: ended,
            unsavedEdits: UnsavedEditsKeeper(editing: UUID(), useCase: firstLaunch.unsavedEdits)
        )
        await editor.loadCV()
        editor.cv.personalInfo.name = "Marta Rinaldi"
        let saving = Task { await editor.saveCV() }
        await ended.waitUntilStored()
        editor.cv.personalInfo.title = "Staff nurse"
        await editor.keepUnsavedEdits()

        // iOS ends the app here, with the CV stored and an edit made during its save kept
        let secondLaunch = try installation.launch()
        let restored = try #require(try await restoreOffer(in: secondLaunch))
        let restoredEditor = try makeEditor(in: secondLaunch, restoring: restored)
        await restoredEditor.loadCV()
        let savedAgain = await restoredEditor.saveCV()
        let stored = try await secondLaunch.makeCVManagementUseCase().getAllCVs()
        await ended.letTheAppGoOn()
        _ = await saving.value

        #expect(savedAgain)
        #expect(stored.count == 1, "Restoring must update the CV the ended save stored, not add another")
        #expect(stored.first?.personalInfo.title == "Staff nurse")
    }

    // MARK: - A save whose kept edits cannot be brought up to date

    @Test("Restored edits that a launch could neither keep again nor save are offered at the next launch, and saving them updates the CV once")
    func restoredEditsThatCouldNotBeSavedAreOfferedAgain() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let firstLaunch = try installation.launch()
        let original = try await firstLaunch.makeCVManagementUseCase()
            .createCV(from: CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi")))
        let editor = try makeEditor(in: firstLaunch, cvId: original.id.uuidString)
        await editor.loadCV()
        editor.cv.personalInfo.location = "Bristol"
        await editor.keepUnsavedEdits()

        // The next launch can remove kept edits but not write them, and cannot store the CV
        let secondLaunch = try installation.launch(keepingThrough: { KeepingFails($0) })
        let restored = try #require(try await restoreOffer(in: secondLaunch))
        let restoredEditor = CVEditorViewModel(
            cvId: nil,
            restoring: restored.edits,
            cvManagementUseCase: StoringFails(try secondLaunch.makeCVManagementUseCase()),
            unsavedEdits: UnsavedEditsKeeper(editing: restored.edits.id, claim: restored.takeClaim(), useCase: secondLaunch.unsavedEdits)
        )
        await restoredEditor.loadCV()
        restoredEditor.cv.personalInfo.title = "Charge nurse"
        #expect(await restoredEditor.saveCV() == false)
        #expect(try await installation.keptEdits() == [restored.edits], "The restored edits stay as they were")

        let thirdLaunch = try installation.launch()
        let offeredAgain = try #require(try await restoreOffer(in: thirdLaunch))
        let editorAgain = try makeEditor(in: thirdLaunch, restoring: offeredAgain)
        await editorAgain.loadCV()
        #expect(editorAgain.cv.personalInfo.location == "Bristol")
        #expect(await editorAgain.saveCV())

        let stored = try await installation.launch().makeCVManagementUseCase().getAllCVs()
        #expect(stored.map(\.id) == [original.id], "Restoring must update the CV, not store it again as a copy")
        #expect(stored.first?.personalInfo.location == "Bristol")
    }

    @Test("Edits whose removal failed after a save are removed by the next launch, and not offered")
    func editsWhoseRemovalFailedAreRemovedByTheNextLaunch() async throws {
        let installation = Installation()
        defer { installation.remove() }
        let firstLaunch = try installation.launch(keepingThrough: { RemovalFails($0) })
        let editor = try makeEditor(in: firstLaunch)
        await editor.loadCV()
        editor.cv.personalInfo.name = "Marta Rinaldi"
        #expect(await editor.saveCV(), "A save does not fail because its kept edits could not be removed")
        #expect(try installation.keptFiles().count == 1)

        let secondLaunch = try installation.launch()
        let offered = try await restoreOffer(in: secondLaunch)

        #expect(offered == nil)
        #expect(try installation.keptFiles().isEmpty)
        #expect(try await secondLaunch.makeCVManagementUseCase().getAllCVs().count == 1)
    }
}

// MARK: - Test Doubles

/// Stores CVs as the app does, except that the app is ended right after a new CV is stored: that call returns only
/// when the test lets the app go on, so whatever the app does next happens after the test has looked.
private actor EndedAfterStoringNewCV: CVManagementUseCaseProtocol {
    private let cvs: CVManagementUseCaseProtocol
    private var didStore = false
    private var storedWaiter: CheckedContinuation<Void, Never>?
    private var goOn: CheckedContinuation<Void, Never>?

    init(_ cvs: CVManagementUseCaseProtocol) {
        self.cvs = cvs
    }

    func waitUntilStored() async {
        guard !didStore else { return }
        await withCheckedContinuation { storedWaiter = $0 }
    }

    func letTheAppGoOn() {
        goOn?.resume()
        goOn = nil
    }

    func storeNewCV(_ cv: CVModel) async throws -> CVModel {
        let stored = try await cvs.storeNewCV(cv)
        didStore = true
        storedWaiter?.resume()
        storedWaiter = nil
        await withCheckedContinuation { goOn = $0 }
        return stored
    }

    func getAllCVs() async throws -> [CVModel] { try await cvs.getAllCVs() }
    func createCV(from template: CVModel) async throws -> CVModel { try await cvs.createCV(from: template) }
    func updateCV(_ cv: CVModel) async throws -> CVModel { try await cvs.updateCV(cv) }
    func deleteCV(id: UUID) async throws { try await cvs.deleteCV(id: id) }
    func duplicateCV(id: UUID, named name: String) async throws -> CVModel { try await cvs.duplicateCV(id: id, named: name) }
    func getCV(by id: UUID) async throws -> CVModel? { try await cvs.getCV(by: id) }
}

/// Reads the real store, but can neither write nor remove anything in it.
private struct WritesFail: UnsavedEditsRepositoryProtocol {
    let repository: UnsavedEditsRepositoryProtocol

    init(_ repository: UnsavedEditsRepositoryProtocol) {
        self.repository = repository
    }

    func keep(_ edits: UnsavedEdits) async throws { throw AppError.fileSystemError("disk full") }
    func allKept() async throws -> [UnsavedEdits] { try await repository.allKept() }
    func kept(editing id: UUID) async throws -> UnsavedEdits? { try await repository.kept(editing: id) }
    func discard(editing id: UUID) async throws { throw AppError.fileSystemError("disk full") }
}

/// Keeps edits in the real store, but cannot remove them.
private struct RemovalFails: UnsavedEditsRepositoryProtocol {
    let repository: UnsavedEditsRepositoryProtocol

    init(_ repository: UnsavedEditsRepositoryProtocol) {
        self.repository = repository
    }

    func keep(_ edits: UnsavedEdits) async throws { try await repository.keep(edits) }
    func allKept() async throws -> [UnsavedEdits] { try await repository.allKept() }
    func kept(editing id: UUID) async throws -> UnsavedEdits? { try await repository.kept(editing: id) }
    func discard(editing id: UUID) async throws { throw AppError.fileSystemError("locked") }
}

/// Reads and removes edits in the real store, but cannot write them.
private struct KeepingFails: UnsavedEditsRepositoryProtocol {
    let repository: UnsavedEditsRepositoryProtocol

    init(_ repository: UnsavedEditsRepositoryProtocol) {
        self.repository = repository
    }

    func keep(_ edits: UnsavedEdits) async throws { throw AppError.fileSystemError("disk full") }
    func allKept() async throws -> [UnsavedEdits] { try await repository.allKept() }
    func kept(editing id: UUID) async throws -> UnsavedEdits? { try await repository.kept(editing: id) }
    func discard(editing id: UUID) async throws { try await repository.discard(editing: id) }
}

/// Reads CVs as the app does, but cannot store any.
private struct StoringFails: CVManagementUseCaseProtocol {
    private let cvs: CVManagementUseCaseProtocol

    init(_ cvs: CVManagementUseCaseProtocol) {
        self.cvs = cvs
    }

    func storeNewCV(_ cv: CVModel) async throws -> CVModel { throw AppError.fileSystemError("disk full") }
    func updateCV(_ cv: CVModel) async throws -> CVModel { throw AppError.fileSystemError("disk full") }
    func createCV(from template: CVModel) async throws -> CVModel { throw AppError.fileSystemError("disk full") }
    func duplicateCV(id: UUID, named name: String) async throws -> CVModel { throw AppError.fileSystemError("disk full") }
    func getAllCVs() async throws -> [CVModel] { try await cvs.getAllCVs() }
    func deleteCV(id: UUID) async throws { try await cvs.deleteCV(id: id) }
    func getCV(by id: UUID) async throws -> CVModel? { try await cvs.getCV(by: id) }
}
