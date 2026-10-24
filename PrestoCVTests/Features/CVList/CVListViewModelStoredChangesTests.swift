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

    private let minimalChoice = DesignChoice(design: "minimal", palette: "minimal", fonts: "classic")!
    private var minimal: LookChange { LookChange(shown: minimalChoice, parts: [.design, .palette, .fonts]) }
    private let copySuffix = "action.copy_suffix".localized

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

    @Test("A copy made while a rename is being saved is named after the new name, not the one the row still shows")
    func duplicateIsNamedAfterARenameBeingSaved() async throws {
        let cv = CVModel(name: "Old")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        let renaming = Task { await viewModel.renameCV(id: cv.id, to: "New") }
        await repository.waitUntilSavesAreHeld(1)
        #expect(viewModel.cvs.map(\.name) == ["Old"], "The row is a save behind")
        let duplicating = Task { await viewModel.duplicateCV(withId: cv.id) }
        await repository.releaseOldestSave()
        await renaming.value
        await duplicating.value

        let copies = try await repository.getAllCVs().filter { $0.id != cv.id }
        #expect(copies.map(\.name) == ["New \(copySuffix)"])
        #expect(viewModel.actionError == nil)
    }

    @Test("A copy is named after the title the CV has once the editors that were left have stored what they showed")
    func duplicateIsNamedAfterALeftEditor() async throws {
        let cv = CVModel(name: "Old")
        let repository = InMemoryCVRepository(cvs: [cv])
        let gate = Gate()
        let leftEditors = LeftEditors()
        let viewModel = makeViewModel(repository: repository, awaitLeftEditors: { await leftEditors.ended(gate) })
        await viewModel.loadCVs()

        // An editor was just left, and is still storing the new name the person gave the CV in it
        leftEditors.areStoring = true
        let duplicating = Task { await viewModel.duplicateCV(withId: cv.id) }
        await gate.waitUntilSomeoneWaits()
        var renamed = cv
        renamed.name = "New"
        _ = try await repository.saveCV(renamed)
        gate.open()
        await duplicating.value

        let copies = try await repository.getAllCVs().filter { $0.id != cv.id }
        #expect(copies.map(\.name) == ["New \(copySuffix)"])
    }

    @Test("A copy of a CV deleted while a look is being saved reports that it is gone, and stores nothing")
    func duplicateOfACVDeletedMeanwhile() async throws {
        let cv = CVModel(name: "Luca – Sales", personalInfo: PersonalInfo(name: "Luca"))
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        let saving = Task { await viewModel.setLook(modern, ofCVWithId: cv.id) }
        await repository.waitUntilSavesAreHeld(1)
        let deleting = Task { await viewModel.deleteCV(withId: cv.id) }
        let duplicating = Task { await viewModel.duplicateCV(withId: cv.id) }
        await repository.releaseOldestSave()
        await saving.value
        await deleting.value
        await duplicating.value

        #expect(await repository.storedNames.isEmpty, "No copy of a CV that is gone")
        #expect(viewModel.actionError != nil)
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

    // MARK: - A look the CV has already is no change

    @Test("A look chosen twice while it is being saved is stored once: the second finds the CV with it")
    func sameLookChosenWhileItIsBeingSavedIsStoredOnce() async throws {
        let cv = CVModel(name: "Luca – Sales", personalInfo: PersonalInfo(name: "Luca"))
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        let first = Task { await viewModel.setLook(modern, ofCVWithId: cv.id) }
        await repository.waitUntilSavesAreHeld(1)
        await viewModel.setLook(modern, ofCVWithId: cv.id)
        await repository.releaseOldestSave()
        await first.value

        #expect(try #require(await repository.getCV(by: cv.id)).look == CVLook(modernChoice))
        #expect(await repository.saveCount == 1, "The look the CV has already is not stored again")
        #expect(viewModel.actionError == nil)
    }

    @Test("A look that an editor that was left has just stored is the look the CV has: choosing it stores nothing, though the row does not show it yet")
    func lookStoredByALeftEditorIsNoChange() async throws {
        let cv = CVModel(name: "Luca – Sales", look: CVLook(minimalChoice))
        let repository = InMemoryCVRepository(cvs: [cv])
        let gate = Gate()
        let leftEditors = LeftEditors()
        let viewModel = makeViewModel(repository: repository, awaitLeftEditors: { await leftEditors.ended(gate) })
        await viewModel.loadCVs()

        leftEditors.areStoring = true
        let choosing = viewModel.chooseLook(modern, ofCVWithId: cv.id)
        clock.advance(by: CVListViewModel.choicePause)
        await gate.waitUntilSomeoneWaits()
        var edited = cv
        edited.look = CVLook(modernChoice)
        _ = try await repository.saveCV(edited)
        gate.open()
        await choosing?.value

        #expect(try #require(await repository.getCV(by: cv.id)).look == CVLook(modernChoice))
        #expect(await repository.saveCount == 1, "The editor's save is the only one")
    }

    @Test("The look the row shows is stored when an editor that was left has stored another since: the CV does not have it")
    func lookOfTheRowIsStoredAfterALeftEditorChangedIt() async throws {
        let cv = CVModel(name: "Luca – Sales", look: CVLook(minimalChoice))
        let repository = InMemoryCVRepository(cvs: [cv])
        let gate = Gate()
        let leftEditors = LeftEditors()
        let viewModel = makeViewModel(repository: repository, awaitLeftEditors: { await leftEditors.ended(gate) })
        await viewModel.loadCVs()

        leftEditors.areStoring = true
        let choosing = viewModel.chooseLook(minimal, ofCVWithId: cv.id)
        clock.advance(by: CVListViewModel.choicePause)
        await gate.waitUntilSomeoneWaits()
        var edited = cv
        edited.look = CVLook(modernChoice)
        _ = try await repository.saveCV(edited)
        gate.open()
        await choosing?.value

        #expect(try #require(await repository.getCV(by: cv.id)).look == CVLook(minimalChoice), "The row showed it, the CV did not have it")
        #expect(await repository.saveCount == 2)
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
