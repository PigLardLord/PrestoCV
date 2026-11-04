import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

private struct NoSamples: SampleCVRepositoryProtocol {
    func getDefaultSample() async throws -> CVModel { CVModel() }
    func getAllSamples() async throws -> [CVModel] { [] }
    func getSample(by name: String) async throws -> CVModel? { nil }
}

/// What the list does with the language and the look chosen in the export sheet of one of its CVs: it waits for the
/// choices to stop, and stores them in one write. What a sheet opened again starts from is in
/// `CVListViewModelCurrentCVTests`.
@MainActor
@Suite("CVListViewModel Tests - the choices made in an export sheet")
struct CVListViewModelChoicesTests {

    private let clock = ManualClock()
    private let cv = CVModel(name: "Luca – Sales", personalInfo: PersonalInfo(name: "Luca"), documentLanguage: "it")

    private func makeViewModel(_ repository: InMemoryCVRepository) -> CVListViewModel {
        let useCase = CVManagementUseCase(cvRepository: repository, sampleRepository: NoSamples())
        return CVListViewModel(cvManagementUseCase: useCase, clock: clock)
    }

    // MARK: - The pause

    @Test("Choices made one after the other within the pause are stored with one write, and the list is read once")
    func rapidChoicesMakeOneWriteAndOneRead() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()
        let readsBefore = await repository.listingCount

        // The sheet shows the look once the choice is made. Each choice comes before the pause of the one before has ended,
        // and every task that can run has run in between: a design, a palette, a font, and the design again. Each pause is
        // started again, so none of them ends, though the clock passes the first deadline
        let save = list.chooseLook(lookChange([.design], design: "modern"), ofCVWithId: cv.id)
        await settle(repository)
        clock.advance(by: .milliseconds(200))
        await settle(repository)
        list.chooseLook(lookChange([.palette], design: "modern", palette: "creative"), ofCVWithId: cv.id)
        await settle(repository)
        clock.advance(by: .milliseconds(200))
        await settle(repository)
        list.chooseLook(lookChange([.fonts], design: "modern", palette: "creative", fonts: "serif"), ofCVWithId: cv.id)
        await settle(repository)
        clock.advance(by: .milliseconds(200))
        await settle(repository)
        list.chooseLook(lookChange([.design], design: "minimal", palette: "creative", fonts: "serif"), ofCVWithId: cv.id)
        await settle(repository)
        #expect(await repository.saveCount == 0, "Nothing is stored while the choices keep coming")
        clock.advance(by: CVListViewModel.choicePause)
        await save?.value

        #expect(await repository.saveCount == 1, "One write for four choices")
        #expect(await repository.listingCount - readsBefore == 1, "And one read of the list")
        let stored = try #require(await repository.getCV(by: cv.id))
        #expect(stored.look == CVLook(design: "minimal", palette: "creative", fonts: "serif"), "The latest choice of each part")
    }

    @Test("The pause is the one the sheet waits before it makes its preview")
    func pauseIsTheSelectionInterval() {
        #expect(CVListViewModel.choicePause == CVExportSheetViewModel.selectionInterval)
    }

    @Test("A choice is not stored while the pause lasts")
    func nothingIsStoredDuringThePause() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()

        let save = list.chooseLook(lookChange([.design], design: "modern"), ofCVWithId: cv.id)
        await settle(repository)
        clock.advance(by: CVListViewModel.choicePause - .milliseconds(1))
        await settle(repository)
        #expect(await repository.saveCount == 0)

        clock.advance(by: .milliseconds(1))
        await save?.value
        #expect(await repository.saveCount == 1)
    }

    @Test("The latest language chosen is the one stored, with one write")
    func latestLanguageIsStored() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()

        let save = list.chooseDocumentLanguage(.german, ofCVWithId: cv.id)
        list.chooseDocumentLanguage(.french, ofCVWithId: cv.id)
        list.chooseDocumentLanguage(nil, ofCVWithId: cv.id)
        clock.advance(by: CVListViewModel.choicePause)
        await save?.value

        #expect(await repository.saveCount == 1)
        #expect(try #require(await repository.getCV(by: cv.id)).documentLanguage == nil, "Automatic was the last choice")
    }

    @Test("A language and a look chosen within one pause are both stored, and neither undoes the other")
    func languageAndLookAreBothStored() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()

        let save = list.chooseDocumentLanguage(.german, ofCVWithId: cv.id)
        list.chooseLook(lookChange([.palette], palette: "creative"), ofCVWithId: cv.id)
        clock.advance(by: CVListViewModel.choicePause)
        await save?.value

        let stored = try #require(await repository.getCV(by: cv.id))
        #expect(stored.documentLanguage == "de" && stored.look?.palette == "creative")
    }

    // MARK: - Without waiting for the pause

    @Test("Closing the sheet stores the choices at once")
    func dismissingStoresAtOnce() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()

        let save = list.chooseLook(lookChange([.design], design: "modern"), ofCVWithId: cv.id)
        list.storeChoicesNow()
        await save?.value

        #expect(try #require(await repository.getCV(by: cv.id)).look?.design == "modern", "The pause was not waited for")
    }

    @Test("The app leaving the foreground stores the choices at once")
    func leavingTheForegroundStoresAtOnce() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()

        let save = list.chooseDocumentLanguage(.german, ofCVWithId: cv.id)
        list.sceneDidChange(isActive: false)
        await save?.value

        #expect(try #require(await repository.getCV(by: cv.id)).documentLanguage == "de")
    }

    @Test("A choice made while the earlier ones are being written waits for its pause, and is stored after them")
    func choiceDuringAWriteIsStoredAfterIt() async throws {
        let repository = InMemoryCVRepository(cvs: [cv])
        let list = makeViewModel(repository)
        await list.loadCVs()
        await repository.holdNextSaves(1)

        let save = list.chooseLook(lookChange([.design], design: "modern"), ofCVWithId: cv.id)
        list.storeChoicesNow()
        await repository.waitUntilSavesAreHeld(1)
        list.chooseDocumentLanguage(.german, ofCVWithId: cv.id)
        list.storeChoicesNow()
        await repository.releaseOldestSave()
        await save?.value

        let stored = try #require(await repository.getCV(by: cv.id))
        #expect(stored.look?.design == "modern" && stored.documentLanguage == "de", "Both were stored, in turn")
        #expect(await repository.saveCount == 2)
    }
}
