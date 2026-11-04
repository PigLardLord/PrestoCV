import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
import struct PrestoCVApplication.LookChange

private struct NoSamples: SampleCVRepositoryProtocol {
    func getDefaultSample() async throws -> CVModel { CVModel() }
    func getAllSamples() async throws -> [CVModel] { [] }
    func getSample(by name: String) async throws -> CVModel? { nil }
}

private struct StoreFailed: Error {}

/// The CV the list hands to a screen that makes output from it, the export sheet: the CV as the store holds it now, with
/// the choices made in an export sheet that the store does not hold yet, and never the row, which is a read behind.
@MainActor
@Suite("CVListViewModel Tests - the CV a screen starts from")
struct CVListViewModelCurrentCVTests {

    private let clock = ManualClock()
    private let professional = CVLook(design: "professional", palette: "professional", fonts: "classic")
    private let modern = CVLook(design: "modern", palette: "creative", fonts: "serif")
    private var cv: CVModel {
        CVModel(id: id, name: "Luca – Sales", personalInfo: PersonalInfo(name: "Luca"), documentLanguage: "it", look: professional)
    }
    private let id = UUID()

    private func makeViewModel(
        _ repository: InMemoryCVRepository,
        awaitLeftEditors: @escaping @MainActor () async -> Void = {}
    ) -> CVListViewModel {
        let useCase = CVManagementUseCase(cvRepository: repository, sampleRepository: NoSamples())
        return CVListViewModel(cvManagementUseCase: useCase, clock: clock, awaitLeftEditors: awaitLeftEditors)
    }

    /// The CV as an editor leaves it in the store with another look and another title, which the list does not know yet
    private func editedInTheEditor() -> CVModel {
        var edited = cv
        edited.look = modern
        edited.personalInfo.title = "Account manager"
        return edited
    }

    // MARK: - The store, not the row

    @Test("A CV the editor saved is read as saved while the list is still reading the CVs again")
    func readsTheStoreWhileTheListReloadIsHeld() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()
        _ = try await repository.saveCV(editedInTheEditor())
        await repository.holdNextListings(1)
        let reloading = Task { await list.loadCVs() }
        await repository.waitUntilListingsAreHeld(1)
        #expect(list.cvs.first?.look == professional, "The row is a read behind")

        let current = await list.currentCV(withId: id)

        #expect(current == editedInTheEditor())
        #expect(list.actionError == nil)
        await repository.releaseOldestListing()
        await reloading.value
    }

    @Test("A CV the editor saved is read as saved after the list failed to read the CVs again")
    func readsTheStoreAfterTheListReloadFailed() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()
        _ = try await repository.saveCV(editedInTheEditor())
        await repository.fail(.listing, with: StoreFailed())
        await list.loadCVs()
        list.actionError = nil   // the failed read told the person; the CV is asked for after
        #expect(list.cvs.first?.look == professional, "The row stays as it was")

        let current = await list.currentCV(withId: id)

        #expect(current == editedInTheEditor())
        #expect(list.actionError == nil)
    }

    @Test("A CV the list never read is read from the store")
    func readsACVTheListNeverRead() async {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)

        #expect(await list.currentCV(withId: id) == cv)
    }

    @Test("A CV is read once the editors that were left have stored what they showed")
    func waitsForTheLeftEditors() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let gate = Gate()
        let list = makeViewModel(repository, awaitLeftEditors: { await gate.wait() })

        // An editor was just left, and is still storing the look the person chose in it
        let reading = Task { await list.currentCV(withId: id) }
        await gate.waitUntilSomeoneWaits()
        _ = try await repository.saveCV(editedInTheEditor())
        gate.open()

        #expect(await reading.value == editedInTheEditor())
    }

    // MARK: - What cannot be read

    @Test("A CV that cannot be read gives nothing, and the person is told")
    func unreadableCV() async {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()
        await repository.fail(.get, with: StoreFailed())

        #expect(await list.currentCV(withId: id) == nil, "The row is not handed over in its place")
        #expect(list.actionError != nil)
    }

    @Test("A CV deleted meanwhile gives nothing, and the person is told that it is gone")
    func deletedCV() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()
        try await repository.deleteCV(id: id)
        #expect(list.cvs.map(\.id) == [id], "The row is still there")

        #expect(await list.currentCV(withId: id) == nil)
        #expect(list.actionError == AppError.notFound("error.subject.cv".localized).localizedDescription)
    }

    @Test("A read that was cancelled is not a failure to tell the person about")
    func cancelledRead() async {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await repository.fail(.get, with: CancellationError())

        #expect(await list.currentCV(withId: id) == nil)
        #expect(list.actionError == nil)
    }

    // MARK: - The choices that wait

    @Test("A CV with nothing chosen for it is as it is stored")
    func nothingChosen() async {
        let list = makeViewModel(InMemoryCVRepository(cvs: [cv]))

        #expect(await list.currentCV(withId: id) == cv)
    }

    @Test("A CV shows the choices that wait for their pause: the language, and the parts of the look chosen")
    func showsTheWaitingChoices() async {
        let list = makeViewModel(InMemoryCVRepository(cvs: [cv]))

        list.chooseDocumentLanguage(.german, ofCVWithId: id)
        list.chooseLook(lookChange([.design], design: "modern"), ofCVWithId: id)

        let shown = await list.currentCV(withId: id)
        #expect(shown?.documentLanguage == "de")
        #expect(shown?.look == CVLook(design: "modern", palette: "professional", fonts: "classic"))
        #expect(shown?.name == cv.name && shown?.personalInfo == cv.personalInfo, "Nothing else of the CV")
    }

    @Test("A CV shows the choices that are being written and the ones that wait behind them, without waiting for the write")
    func showsTheChoicesBeingWritten() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()
        await repository.holdNextSaves(1)

        let save = list.chooseLook(lookChange([.design], design: "modern"), ofCVWithId: id)
        list.storeChoicesNow()
        await repository.waitUntilSavesAreHeld(1)
        list.chooseLook(lookChange([.fonts], design: "modern", fonts: "serif"), ofCVWithId: id)

        // The write is held: a CV that waited for it would never be read
        let shown = await list.currentCV(withId: id)
        #expect(shown?.look == CVLook(design: "modern", palette: "professional", fonts: "serif"))
        #expect(try await repository.getCV(by: id)?.look == professional, "Nothing is stored yet")

        list.storeChoicesNow()
        await repository.releaseOldestSave()
        await save?.value
    }

    @Test("A CV shows the choices on top of what the editor saved, not on top of the row")
    func choicesWaitingOnTopOfASavedLook() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()
        _ = try await repository.saveCV(editedInTheEditor())

        list.chooseDocumentLanguage(.german, ofCVWithId: id)

        var expected = editedInTheEditor()
        expected.documentLanguage = "de"
        #expect(await list.currentCV(withId: id) == expected)
    }

    @Test("Once the choices are stored the CV shows them, and has nothing more to add")
    func showsTheStoredChoices() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()

        await list.setLook(lookChange([.design], design: "modern"), ofCVWithId: id)
        await list.setDocumentLanguage(.german, ofCVWithId: id)

        let shown = await list.currentCV(withId: id)
        let stored = try await repository.getCV(by: id)
        #expect(shown?.look?.design == "modern" && shown?.documentLanguage == "de")
        #expect(shown == stored)
    }

    @Test("A write that fails leaves the CV as it is stored: the sheet does not show a choice that was not stored")
    func failedChoicesAreNotShown() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()
        await repository.fail(.save, with: StoreFailed())

        await list.setLook(lookChange([.design], design: "modern"), ofCVWithId: id)
        await list.setDocumentLanguage(.german, ofCVWithId: id)
        #expect(list.actionError != nil, "The person is told")

        #expect(await list.currentCV(withId: id) == cv)
    }
}
