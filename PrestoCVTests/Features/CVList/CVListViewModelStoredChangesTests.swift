import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
import struct PrestoCVApplication.LookChange
import struct PrestoCVDomain.DesignChoice

private struct NoSamples: SampleCVRepositoryProtocol {
    func getDefaultSample() async throws -> CVModel { CVModel() }
    func getAllSamples() async throws -> [CVModel] { [] }
    func getSample(by name: String) async throws -> CVModel? { nil }
}

/// What the list does with the changes to its CVs that it makes outside their editors: it makes them one at a time for
/// each CV, and registers each at once, so that the editor of the CV waits for it.
@MainActor
@Suite("CVListViewModel Tests - the changes to a stored CV")
struct CVListViewModelStoredChangesTests {

    private let modernChoice = DesignChoice(design: "modern", palette: "creative", fonts: "serif")!
    private var modern: LookChange { LookChange(shown: modernChoice, parts: [.design, .palette, .fonts]) }

    private let clock = ManualClock()

    private func makeViewModel(
        repository: InMemoryCVRepository,
        queue: StoredCVChangeQueue = StoredCVChangeQueue(),
        awaitLeftEditors: @escaping @MainActor () async -> Void = {}
    ) -> CVListViewModel {
        let useCase = CVManagementUseCase(cvRepository: repository, sampleRepository: NoSamples())
        return CVListViewModel(cvManagementUseCase: useCase, clock: clock, changeQueue: queue, awaitLeftEditors: awaitLeftEditors)
    }

    // MARK: - One change at a time for each CV

    @Test("A rename chosen while a look is being saved waits for it, and both are stored")
    func renameWaitsForALookBeingSaved() async throws {
        let cv = CVModel(name: "Luca – Sales", personalInfo: PersonalInfo(name: "Luca"))
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        let saving = Task { await viewModel.setLook(modern, ofCVWithId: cv.id) }
        await repository.waitUntilSavesAreHeld(1)
        let renaming = Task { await viewModel.renameCV(id: cv.id, to: "Luca – Account manager") }
        await repository.releaseOldestSave()
        await saving.value
        await renaming.value

        let stored = try #require(await repository.getCV(by: cv.id))
        #expect(stored.name == "Luca – Account manager" && stored.look == CVLook(modernChoice), "Neither change undid the other")
        #expect(await repository.saveCount == 2)
    }

    @Test("A look chosen while a rename is being saved waits for it, and both are stored")
    func lookWaitsForARenameBeingSaved() async throws {
        let cv = CVModel(name: "Luca – Sales", personalInfo: PersonalInfo(name: "Luca"))
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        let renaming = Task { await viewModel.renameCV(id: cv.id, to: "Luca – Account manager") }
        await repository.waitUntilSavesAreHeld(1)
        let saving = Task { await viewModel.setLook(modern, ofCVWithId: cv.id) }
        await repository.releaseOldestSave()
        await renaming.value
        await saving.value

        let stored = try #require(await repository.getCV(by: cv.id))
        #expect(stored.name == "Luca – Account manager" && stored.look == CVLook(modernChoice), "Neither change undid the other")
    }

    @Test("A copy made while a look is being saved has that look")
    func duplicateCopiesTheLookBeingSaved() async throws {
        let cv = CVModel(name: "Luca – Sales", personalInfo: PersonalInfo(name: "Luca"))
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        let saving = Task { await viewModel.setLook(modern, ofCVWithId: cv.id) }
        await repository.waitUntilSavesAreHeld(1)
        let duplicating = Task { await viewModel.duplicateCV(withId: cv.id) }
        await repository.releaseOldestSave()
        await saving.value
        await duplicating.value

        let copies = try await repository.getAllCVs().filter { $0.id != cv.id }
        #expect(copies.map(\.look) == [CVLook(modernChoice)], "The copy is of the CV as the person left it")
    }

    @Test("A CV deleted while a look is being saved stays deleted: the save does not bring it back")
    func deleteWaitsForALookBeingSaved() async throws {
        let cv = CVModel(name: "Luca – Sales", personalInfo: PersonalInfo(name: "Luca"))
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        let saving = Task { await viewModel.setLook(modern, ofCVWithId: cv.id) }
        await repository.waitUntilSavesAreHeld(1)
        let deleting = Task { await viewModel.deleteCV(withId: cv.id) }
        await repository.releaseOldestSave()
        await saving.value
        await deleting.value

        #expect(await repository.storedNames.isEmpty)
        #expect(viewModel.cvs.isEmpty)
    }

    // MARK: - Registered when chosen

    @Test("A look is on its way from the moment it is chosen, through the pause and the write: the CV is not settled until it is stored")
    func lookIsRegisteredWhenChosen() async throws {
        let cv = CVModel(name: "Luca – Sales")
        let repository = InMemoryCVRepository(cvs: [cv])
        let queue = StoredCVChangeQueue()
        let viewModel = makeViewModel(repository: repository, queue: queue)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        viewModel.chooseLook(modern, ofCVWithId: cv.id)
        let waiting = Task { await queue.settled(cv.id) }
        await settle(repository)
        #expect(await repository.saveCount == 0, "Nothing is stored while the pause lasts")

        clock.advance(by: CVListViewModel.choicePause)
        await repository.waitUntilSavesAreHeld(1)
        await repository.releaseOldestSave()
        await waiting.value

        #expect(try #require(await repository.getCV(by: cv.id)).look == CVLook(modernChoice), "The wait ended after the write")
    }

    @Test("A language is on its way from the moment it is chosen too")
    func languageIsRegisteredWhenChosen() async throws {
        let cv = CVModel(name: "Luca – Sales", documentLanguage: "it")
        let repository = InMemoryCVRepository(cvs: [cv])
        let queue = StoredCVChangeQueue()
        let viewModel = makeViewModel(repository: repository, queue: queue)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        viewModel.chooseDocumentLanguage(.german, ofCVWithId: cv.id)
        let waiting = Task { await queue.settled(cv.id) }
        await settle(repository)
        #expect(await repository.saveCount == 0, "Nothing is stored while the pause lasts")

        clock.advance(by: CVListViewModel.choicePause)
        await repository.waitUntilSavesAreHeld(1)
        await repository.releaseOldestSave()
        await waiting.value

        #expect(try #require(await repository.getCV(by: cv.id)).documentLanguage == "de", "The wait ended after the write")
    }

    @Test("A change to a CV waits for the editors that were left, so that it is made on what they stored")
    func changeWaitsForTheLeftEditors() async throws {
        let cv = CVModel(name: "Luca – Sales", personalInfo: PersonalInfo(name: "Luca"))
        let repository = InMemoryCVRepository(cvs: [cv])
        let gate = Gate()
        let leftEditors = LeftEditors()
        let viewModel = makeViewModel(repository: repository, awaitLeftEditors: { await leftEditors.ended(gate) })
        await viewModel.loadCVs()

        // An editor was just left, and is still storing its last edit
        leftEditors.areStoring = true
        let choosing = viewModel.chooseLook(modern, ofCVWithId: cv.id)
        clock.advance(by: CVListViewModel.choicePause)
        await gate.waitUntilSomeoneWaits()
        var edited = cv
        edited.personalInfo.title = "Account manager"
        _ = try await repository.saveCV(edited)
        gate.open()
        await choosing?.value

        let stored = try #require(await repository.getCV(by: cv.id))
        #expect(stored.personalInfo.title == "Account manager" && stored.look == CVLook(modernChoice), "The edit was not undone")
    }

    /// Whether an editor that was left is still storing: the list waits at the gate only then
    @MainActor
    final class LeftEditors {
        var areStoring = false

        func ended(_ gate: Gate) async {
            if areStoring {
                await gate.wait()
            }
        }
    }
}
