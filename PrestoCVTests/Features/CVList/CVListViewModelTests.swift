import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
import struct PrestoCVDomain.DesignChoice

// MARK: - Test Doubles

private struct UnusedSampleCVRepository: SampleCVRepositoryProtocol {
    func getDefaultSample() async throws -> CVModel { CVModel() }
    func getAllSamples() async throws -> [CVModel] { [] }
    func getSample(by name: String) async throws -> CVModel? { nil }
}

enum ListChange: CaseIterable {
    case rename
    case duplicate
    case delete
}

// MARK: - CVListViewModel Tests

@MainActor
@Suite("CVListViewModel Tests - the actions on the CVs of the list")
struct CVListViewModelTests {
    
    private let copySuffix = "action.copy_suffix".localized
    
    private func makeViewModel(repository: InMemoryCVRepository) -> CVListViewModel {
        let useCase = CVManagementUseCase(cvRepository: repository, sampleRepository: UnusedSampleCVRepository())
        return CVListViewModel(cvManagementUseCase: useCase)
    }
    
    private func isLoaded(_ viewModel: CVListViewModel) -> Bool {
        viewModel.viewState.data != nil
    }
    
    // MARK: - Loading
    
    @Test("The list shows the stored CVs")
    func listShowsTheStoredCVs() async {
        let repository = InMemoryCVRepository(cvs: [CVModel(name: "B"), CVModel(name: "A")])
        let viewModel = makeViewModel(repository: repository)
        
        await viewModel.loadCVs()
        
        #expect(viewModel.cvs.map(\.name) == ["A", "B"])
    }
    
    @Test("The first load shows the loading state")
    func firstLoadShowsLoading() async {
        let repository = InMemoryCVRepository(cvs: [CVModel(name: "A")])
        await repository.holdNextListings()
        let viewModel = makeViewModel(repository: repository)
        
        let loading = Task { await viewModel.loadCVs() }
        await repository.waitUntilListingsAreHeld(1)
        let wasLoading = viewModel.isLoading
        await repository.releaseOldestListing()
        await loading.value
        
        #expect(wasLoading)
        #expect(viewModel.cvs.count == 1)
    }
    
    @Test("Reading the list again keeps it on screen instead of showing a spinner")
    func reloadKeepsTheListOnScreen() async {
        let repository = InMemoryCVRepository(cvs: [CVModel(name: "A")])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextListings()
        
        let reloading = Task { await viewModel.loadCVs() }
        await repository.waitUntilListingsAreHeld(1)
        let listWasKept = isLoaded(viewModel) && !viewModel.isLoading
        await repository.releaseOldestListing()
        await reloading.value
        
        #expect(listWasKept, "A spinner over a list that is already shown flashes on every return to the list")
        #expect(viewModel.cvs.map(\.name) == ["A"])
    }
    
    @Test("A listing that fails shows the error, and a later load recovers")
    func failedListingShowsTheErrorAndRecovers() async {
        let repository = InMemoryCVRepository(cvs: [CVModel(name: "A")])
        await repository.fail(.listing, with: AppError.unknown("disk"))
        let viewModel = makeViewModel(repository: repository)
        
        await viewModel.loadCVs()
        #expect(viewModel.errorMessage.contains("disk"))
        
        await repository.fail(.listing, with: nil)
        await viewModel.loadCVs()
        #expect(viewModel.cvs.map(\.name) == ["A"])
        #expect(viewModel.errorMessage.isEmpty)
    }
    
    // MARK: - A change that is stored while the list cannot be read again
    
    @Test("A change that is stored shows in the list although the list cannot be read again, with a notice, and a retry clears the notice",
          arguments: [ListChange.rename, .duplicate, .delete])
    func committedChangeShowsWhenReloadFails(change: ListChange) async {
        let original = CVModel(name: "Original")
        let other = CVModel(name: "Other")
        let repository = InMemoryCVRepository(cvs: [original, other])
        await repository.setUnreadableCount(2)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.fail(.listing, with: AppError.unknown("disk"))
        
        switch change {
        case .rename: await viewModel.renameCV(id: original.id, to: "Renamed")
        case .duplicate: await viewModel.duplicateCV(withId: original.id)
        case .delete: await viewModel.deleteCV(withId: original.id)
        }
        
        let expectedNames: [String]
        switch change {
        case .rename: expectedNames = ["Other", "Renamed"]
        case .duplicate: expectedNames = ["Original", "Original \(copySuffix)", "Other"]
        case .delete: expectedNames = ["Other"]
        }
        #expect(await repository.storedNames == expectedNames, "The change itself went through, once")
        #expect(viewModel.cvs.map(\.name).sorted() == expectedNames, "The list shows the change, not the rows from before it")
        #expect(isLoaded(viewModel))
        #expect(viewModel.errorMessage.isEmpty, "No full-screen error over a list the user already has")
        #expect(viewModel.actionError == nil, "The change did not fail, so there is no failure to report")
        #expect(viewModel.staleNotice != nil, "The user is told that the list could not be refreshed")
        #expect(viewModel.unreadableNotice != nil, "The notice about the unreadable CVs stays")
        
        await repository.fail(.listing, with: nil)
        await viewModel.loadCVs()
        
        #expect(viewModel.staleNotice == nil, "A retry that works clears the notice")
        #expect(viewModel.cvs.map(\.name).sorted() == expectedNames)
        #expect(await repository.storedNames == expectedNames, "The retry only reads: no second copy, no second change")
    }
    
    @Test("A retry that fails again keeps the notice and shows no alert")
    func failingRetryKeepsTheNotice() async {
        let original = CVModel(name: "Original")
        let repository = InMemoryCVRepository(cvs: [original])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.fail(.listing, with: AppError.unknown("disk"))
        await viewModel.deleteCV(withId: original.id)
        #expect(viewModel.staleNotice != nil)
        
        await viewModel.loadCVs()
        
        #expect(viewModel.staleNotice != nil)
        #expect(viewModel.actionError == nil)
        #expect(viewModel.cvs.isEmpty)
    }
    
    @Test("A refresh that fails while the list is up to date keeps the list and reports an error, without the stale notice")
    func failedRefreshOfAnUpToDateListReportsAnError() async {
        let repository = InMemoryCVRepository(cvs: [CVModel(name: "A")])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.fail(.listing, with: AppError.unknown("disk"))
        
        await viewModel.loadCVs()
        
        #expect(viewModel.actionError?.contains("disk") == true)
        #expect(viewModel.staleNotice == nil, "Nothing was changed that the list does not show")
        #expect(viewModel.cvs.map(\.name) == ["A"])
        #expect(isLoaded(viewModel))
    }
    
    @Test("Dismissing the notice about unreadable CVs removes it even when the list cannot be read again")
    func dismissedUnreadableNoticeStaysGone() async {
        let repository = InMemoryCVRepository(cvs: [CVModel(name: "A")])
        await repository.setUnreadableCount(2)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        #expect(viewModel.unreadableNotice != nil)
        await repository.fail(.listing, with: AppError.unknown("disk"))
        
        await viewModel.dismissUnreadableNotice()
        
        #expect(viewModel.unreadableNotice == nil)
        #expect(viewModel.staleNotice != nil)
        
        await repository.fail(.listing, with: nil)
        await viewModel.loadCVs()
        #expect(viewModel.unreadableNotice == nil, "The store was told, so the next read does not bring it back")
        #expect(viewModel.staleNotice == nil)
    }
    
    // MARK: - Reads that overlap each other and the changes
    
    @Test("A read that began before a change and finishes after it does not bring back the rows from before it, and a failing reload still shows the change",
          arguments: [ListChange.duplicate, .delete])
    func oldReadDoesNotOverwriteACommittedChange(change: ListChange) async {
        let original = CVModel(name: "Original")
        let other = CVModel(name: "Other")
        let repository = InMemoryCVRepository(cvs: [original, other])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextListings(2)
        
        // 1. a read starts and sees the store as it is now
        let oldRead = Task { await viewModel.loadCVs() }
        await repository.waitUntilListingsAreHeld(1)
        // 2. the change goes through and is applied to the rows; its reload starts and waits
        let mutation = Task {
            switch change {
            case .duplicate: await viewModel.duplicateCV(withId: original.id)
            case .delete: await viewModel.deleteCV(withId: original.id)
            case .rename: await viewModel.renameCV(id: original.id, to: "Renamed")
            }
        }
        await repository.waitUntilListingsAreHeld(2)
        let expectedNames = change == .duplicate ? ["Original", "Original \(copySuffix)", "Other"] : ["Other"]
        #expect(viewModel.cvs.map(\.name).sorted() == expectedNames, "The change is applied to the rows before anything is read again")
        // 3. the old read finishes with the rows from before the change
        await repository.releaseOldestListing()
        await oldRead.value
        #expect(viewModel.cvs.map(\.name).sorted() == expectedNames, "A read that was overtaken by the change publishes nothing")
        // 4. the reload that follows the change fails
        await repository.releaseOldestListing(failingWith: AppError.unknown("disk"))
        await mutation.value
        
        #expect(viewModel.cvs.map(\.name).sorted() == expectedNames)
        #expect(viewModel.staleNotice != nil, "The user is told that the list could not be refreshed")
        #expect(viewModel.actionError == nil)
        #expect(await repository.storedNames == expectedNames)
        #expect(await repository.saveCount == (change == .duplicate ? 1 : 0))
        
        // Retry only reads
        await viewModel.loadCVs()
        #expect(viewModel.staleNotice == nil)
        #expect(viewModel.cvs.map(\.name).sorted() == expectedNames)
        #expect(await repository.storedNames == expectedNames, "Retrying must not change anything")
        #expect(await repository.saveCount == (change == .duplicate ? 1 : 0))
    }
    
    @Test("A read that finishes after a newer read does not replace what the newer one found")
    func olderReadFinishingLastIsDiscarded() async {
        let repository = InMemoryCVRepository(cvs: [CVModel(name: "A")])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextListings(2)
        
        let olderRead = Task { await viewModel.loadCVs() }
        await repository.waitUntilListingsAreHeld(1)
        _ = try? await repository.saveCV(CVModel(name: "B"))
        let newerRead = Task { await viewModel.loadCVs() }
        await repository.waitUntilListingsAreHeld(2)
        
        // the newer read finishes first and the older one, which saw only "A", last
        await repository.releaseNewestListing()
        await newerRead.value
        #expect(viewModel.cvs.map(\.name) == ["A", "B"])
        await repository.releaseOldestListing()
        await olderRead.value
        #expect(viewModel.cvs.map(\.name) == ["A", "B"], "The older read was overtaken and publishes nothing")
    }
    
    @Test("A read that fails after a newer one has started reports nothing")
    func overtakenReadsFailureIsNotReported() async {
        let repository = InMemoryCVRepository(cvs: [CVModel(name: "A")])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextListings(2)
        
        let olderRead = Task { await viewModel.loadCVs() }
        await repository.waitUntilListingsAreHeld(1)
        let newerRead = Task { await viewModel.loadCVs() }
        await repository.waitUntilListingsAreHeld(2)
        
        await repository.releaseOldestListing(failingWith: AppError.unknown("disk"))
        await olderRead.value
        #expect(viewModel.actionError == nil)
        await repository.releaseOldestListing()
        await newerRead.value
        #expect(viewModel.actionError == nil)
        #expect(viewModel.cvs.map(\.name) == ["A"])
    }
    
    @Test("A read that the screen cancels is not an error")
    func cancelledReadIsNotAnError() async {
        let repository = InMemoryCVRepository(cvs: [CVModel(name: "A")])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.fail(.listing, with: CancellationError())
        
        await viewModel.loadCVs()
        
        #expect(viewModel.actionError == nil)
        #expect(viewModel.staleNotice == nil)
        #expect(viewModel.cvs.map(\.name) == ["A"])
    }
    
    // MARK: - Duplicate
    
    @Test("A duplicate is named after its original with the copy suffix and joins the list")
    func duplicateJoinsTheList() async {
        let original = CVModel(name: "Backend Engineer")
        let repository = InMemoryCVRepository(cvs: [original])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        
        await viewModel.duplicateCV(withId: original.id)
        
        #expect(viewModel.cvs.map(\.name) == ["Backend Engineer", "Backend Engineer \(copySuffix)"])
        #expect(Set(viewModel.cvs.map(\.id)).count == 2, "The duplicate is a CV of its own")
        #expect(viewModel.actionError == nil)
    }
    
    @Test("The duplicate of an unnamed CV is named after the title the list shows it with",
          arguments: [(PersonalInfo(name: "Lena Hartmann", title: "Pflegefachkraft"), "Lena Hartmann"),
                      (PersonalInfo(title: "Pflegefachkraft"), "Pflegefachkraft"), (PersonalInfo(email: "lena@example.com"), "cv.untitled".localized)])
    func duplicateOfUnnamedCVIsNamedAfterItsTitle(person: PersonalInfo, shownTitle: String) async {
        let original = CVModel(name: "", personalInfo: person)
        let repository = InMemoryCVRepository(cvs: [original])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        #expect(viewModel.title(of: original) == shownTitle)

        await viewModel.duplicateCV(withId: original.id)

        #expect(viewModel.cvs.map(\.name).sorted() == ["", "\(shownTitle) \(copySuffix)"])
    }

    @Test("Two copies of one CV are numbered in the list, as any titles that read alike")
    func copiesOfOneCVAreNumbered() async throws {
        let original = CVModel(name: "", personalInfo: PersonalInfo(name: "Lena Hartmann"))
        let repository = InMemoryCVRepository(cvs: [original])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()

        await viewModel.duplicateCV(withId: original.id)
        await viewModel.duplicateCV(withId: original.id)

        let titles = viewModel.cvs.map(viewModel.title(of:)).sorted()
        let copy = "Lena Hartmann \(copySuffix)"
        #expect(titles == ["Lena Hartmann", copy, "cv.title.numbered".localizedWithArgs(copy, 2)].sorted())
    }
    
    // MARK: - Rename
    
    @Test("Renaming trims the name, saves it and refreshes the list")
    func renameTrimsSavesAndRefreshes() async {
        let cv = CVModel(name: "Old", personalInfo: PersonalInfo(name: "Ada", title: "Engineer"))
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        
        await viewModel.renameCV(id: cv.id, to: "  New name \n")
        
        #expect(viewModel.cvs.map(\.name) == ["New name"])
        #expect(viewModel.cvs.first?.personalInfo == cv.personalInfo, "Only the name changes")
        #expect(await repository.storedNames == ["New name"])
        #expect(viewModel.actionError == nil)
    }
    
    @Test("Renaming to an empty name is refused and saves nothing", arguments: ["", "   ", " \n\t "])
    func renameToEmptyNameIsRefused(name: String) async {
        let cv = CVModel(name: "Keep me")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        
        await viewModel.renameCV(id: cv.id, to: name)
        
        #expect(await repository.saveCount == 0)
        #expect(viewModel.cvs.map(\.name) == ["Keep me"])
    }
    
    @Test("Renaming a CV that no longer exists reports an error and leaves the list alone")
    func renameOfMissingCVReportsAnError() async {
        let cv = CVModel(name: "Here")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        
        await viewModel.renameCV(id: UUID(), to: "Gone")
        
        #expect(viewModel.actionError != nil)
        #expect(viewModel.cvs.map(\.name) == ["Here"])
    }
    
    @Test("A rename that cannot be saved reports an error, keeps the old name and keeps the list")
    func failedRenameReportsAnError() async {
        let cv = CVModel(name: "Old")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.fail(.save, with: AppError.unknown("disk"))
        
        await viewModel.renameCV(id: cv.id, to: "New")
        
        #expect(viewModel.actionError?.contains("disk") == true)
        #expect(viewModel.staleNotice == nil, "A change that failed leaves the list as it is: nothing to refresh")
        #expect(viewModel.cvs.map(\.name) == ["Old"])
        #expect(isLoaded(viewModel), "The list is still shown")
        #expect(viewModel.errorMessage.isEmpty)
    }
    
    // MARK: - Document language

    @Test("The language chosen in the export sheet of a CV of the list is saved, and nothing else changes",
          arguments: [DocumentLanguage?.some(.english), nil])
    func documentLanguageIsSaved(language: DocumentLanguage?) async throws {
        let cv = CVModel(name: "Luca – Sales", personalInfo: PersonalInfo(name: "Luca"), documentLanguage: "it")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()

        await viewModel.setDocumentLanguage(language, ofCVWithId: cv.id)

        let stored = try #require(await repository.getCV(by: cv.id))
        #expect(stored.documentLanguage == language?.rawValue)
        #expect(stored.name == cv.name && stored.personalInfo == cv.personalInfo, "Only the language changes")
        #expect(viewModel.cvs.first?.documentLanguage == language?.rawValue)
        #expect(viewModel.actionError == nil)
    }

    @Test("A language chosen while the one before is still being saved is stored last, whatever order the saves end in")
    func latestLanguageIsStoredLast() async throws {
        let cv = CVModel(name: "Luca – Sales", documentLanguage: "it")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        // English is being written, slowly, when German is chosen
        let english = Task { await viewModel.setDocumentLanguage(.english, ofCVWithId: cv.id) }
        await repository.waitUntilSavesAreHeld(1)
        let german = Task { await viewModel.setDocumentLanguage(.german, ofCVWithId: cv.id) }
        await german.value
        await repository.releaseOldestSave()
        await english.value

        #expect(try #require(await repository.getCV(by: cv.id)).documentLanguage == "de")
        #expect(viewModel.cvs.first?.documentLanguage == "de", "The list shows the language the sheet shows")
    }

    @Test("Languages chosen while one is being saved are not all saved: only the latest follows it")
    func supersededLanguagesAreNotSaved() async throws {
        let cv = CVModel(name: "Luca – Sales")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        let english = Task { await viewModel.setDocumentLanguage(.english, ofCVWithId: cv.id) }
        await repository.waitUntilSavesAreHeld(1)
        await viewModel.setDocumentLanguage(.german, ofCVWithId: cv.id)
        await viewModel.setDocumentLanguage(nil, ofCVWithId: cv.id)
        await repository.releaseOldestSave()
        await english.value

        #expect(try #require(await repository.getCV(by: cv.id)).documentLanguage == nil, "Automatic was chosen last")
        #expect(await repository.saveCount == 2, "English, then automatic: German was replaced before it was saved")
    }

    @Test("A language that cannot be saved reports an error and keeps the CV as it was")
    func failedDocumentLanguageReportsAnError() async throws {
        let cv = CVModel(name: "Luca – Sales", documentLanguage: "it")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.fail(.save, with: AppError.unknown("disk"))

        await viewModel.setDocumentLanguage(.english, ofCVWithId: cv.id)

        #expect(viewModel.actionError?.contains("disk") == true)
        #expect(try #require(await repository.getCV(by: cv.id)).documentLanguage == "it")
    }

    // MARK: - Look

    private let modern = DesignChoice(design: "modern", palette: "creative", fonts: "serif")!
    private let minimal = DesignChoice(design: "minimal", palette: "minimal", fonts: "classic")!

    @Test("The look chosen in the export sheet of a CV of the list is saved, and nothing else changes")
    func lookIsSaved() async throws {
        let cv = CVModel(name: "Luca – Sales", personalInfo: PersonalInfo(name: "Luca"), documentLanguage: "it")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()

        await viewModel.setLook(modern, ofCVWithId: cv.id)

        var expected = cv
        expected.look = CVLook(modern)
        #expect(try await repository.getCV(by: cv.id) == expected, "Only the look changes")
        #expect(viewModel.cvs == [expected], "The row shows the CV as stored")
        #expect(viewModel.actionError == nil)
    }

    @Test("A look chosen while the one before is still being saved is stored last, whatever order the saves end in")
    func latestLookIsStoredLast() async throws {
        let cv = CVModel(name: "Luca – Sales", look: CVLook(minimal))
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        // Modern is being written, slowly, when minimal is chosen again
        let first = Task { await viewModel.setLook(modern, ofCVWithId: cv.id) }
        await repository.waitUntilSavesAreHeld(1)
        let second = Task { await viewModel.setLook(minimal, ofCVWithId: cv.id) }
        await second.value
        await repository.releaseOldestSave()
        await first.value

        #expect(try #require(await repository.getCV(by: cv.id)).look == CVLook(minimal))
        #expect(viewModel.cvs.first?.look == CVLook(minimal), "The list shows the look the sheet shows")
    }

    @Test("Looks chosen while one is being saved are not all saved: only the latest follows it")
    func supersededLooksAreNotSaved() async throws {
        let cv = CVModel(name: "Luca – Sales")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)
        let other = DesignChoice(design: "professional", palette: "modern", fonts: "modern")!

        let first = Task { await viewModel.setLook(modern, ofCVWithId: cv.id) }
        await repository.waitUntilSavesAreHeld(1)
        await viewModel.setLook(minimal, ofCVWithId: cv.id)
        await viewModel.setLook(other, ofCVWithId: cv.id)
        await repository.releaseOldestSave()
        await first.value

        #expect(try #require(await repository.getCV(by: cv.id)).look == CVLook(other), "The last one chosen")
        #expect(await repository.saveCount == 2, "Modern, then the last: minimal was replaced before it was saved")
    }

    @Test("A language and a look chosen while one of them is being saved are both stored, whichever came first",
          arguments: [true, false])
    func languageAndLookKeepEachOther(languageFirst: Bool) async throws {
        let cv = CVModel(name: "Luca – Sales", personalInfo: PersonalInfo(name: "Luca"), documentLanguage: "it")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        let first = Task {
            if languageFirst {
                await viewModel.setDocumentLanguage(.german, ofCVWithId: cv.id)
            } else {
                await viewModel.setLook(modern, ofCVWithId: cv.id)
            }
        }
        await repository.waitUntilSavesAreHeld(1)
        if languageFirst {
            await viewModel.setLook(modern, ofCVWithId: cv.id)
        } else {
            await viewModel.setDocumentLanguage(.german, ofCVWithId: cv.id)
        }
        await repository.releaseOldestSave()
        await first.value

        let stored = try #require(await repository.getCV(by: cv.id))
        #expect(stored.documentLanguage == "de" && stored.look == CVLook(modern), "Neither choice undid the other")
        #expect(stored.name == cv.name && stored.personalInfo == cv.personalInfo)
        #expect(viewModel.cvs.first == stored)
        #expect(await repository.saveCount == 2)
    }

    @Test("A look chosen for one CV does not wait for the save of another")
    func looksOfTwoCVsAreSavedApart() async throws {
        let first = CVModel(name: "First")
        let second = CVModel(name: "Second")
        let repository = InMemoryCVRepository(cvs: [first, second])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.holdNextSaves(1)

        let slow = Task { await viewModel.setLook(modern, ofCVWithId: first.id) }
        await repository.waitUntilSavesAreHeld(1)
        await viewModel.setLook(minimal, ofCVWithId: second.id)

        #expect(try #require(await repository.getCV(by: second.id)).look == CVLook(minimal))
        #expect(try #require(await repository.getCV(by: first.id)).look == nil, "The first is still being written")
        await repository.releaseOldestSave()
        await slow.value
        #expect(try #require(await repository.getCV(by: first.id)).look == CVLook(modern))
    }

    @Test("A look that cannot be saved reports an error and keeps the CV as it was")
    func failedLookReportsAnError() async throws {
        let cv = CVModel(name: "Luca – Sales", look: CVLook(minimal))
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.fail(.save, with: AppError.unknown("disk"))

        await viewModel.setLook(modern, ofCVWithId: cv.id)

        #expect(viewModel.actionError?.contains("disk") == true)
        #expect(try #require(await repository.getCV(by: cv.id)).look == CVLook(minimal))
    }

    @Test("A look chosen for a CV that was deleted meanwhile reports an error and stores nothing")
    func lookOfADeletedCV() async {
        let cv = CVModel(name: "Luca – Sales")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        try? await repository.deleteCV(id: cv.id)

        await viewModel.setLook(modern, ofCVWithId: cv.id)

        #expect(viewModel.actionError != nil)
        #expect(await repository.saveCount == 0)
        #expect(await repository.storedNames.isEmpty)
    }

    // MARK: - Delete
    
    @Test("Deleting removes the CV from the list and from storage")
    func deleteRemovesTheCV() async {
        let kept = CVModel(name: "Kept")
        let deleted = CVModel(name: "Deleted")
        let repository = InMemoryCVRepository(cvs: [kept, deleted])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        
        await viewModel.deleteCV(withId: deleted.id)
        
        #expect(viewModel.cvs.map(\.name) == ["Kept"])
        #expect(await repository.storedNames == ["Kept"])
    }
    
    @Test("Deleting the first of two CVs deletes that one and not its neighbour")
    func deleteFirstOfTwoDeletesTheRightOne() async {
        let first = CVModel(name: "A")
        let second = CVModel(name: "B")
        let repository = InMemoryCVRepository(cvs: [first, second])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        
        await viewModel.deleteCV(withId: viewModel.cvs[0].id)
        
        #expect(viewModel.cvs.map(\.name) == ["B"])
    }
    
    @Test("A delete that fails reports an error and keeps the list")
    func failedDeleteReportsAnError() async {
        let cv = CVModel(name: "Stays")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.fail(.delete, with: AppError.unknown("disk"))
        
        await viewModel.deleteCV(withId: cv.id)
        
        #expect(viewModel.actionError?.contains("disk") == true)
        #expect(viewModel.cvs.map(\.name) == ["Stays"])
        #expect(isLoaded(viewModel), "A failed action must not replace the list with an error screen")
    }
    
    @Test("A failed duplicate reports an error and keeps the list")
    func failedDuplicateReportsAnError() async {
        let cv = CVModel(name: "Original")
        let repository = InMemoryCVRepository(cvs: [cv])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadCVs()
        await repository.fail(.save, with: AppError.unknown("disk"))
        
        await viewModel.duplicateCV(withId: cv.id)
        
        #expect(viewModel.actionError?.contains("disk") == true)
        #expect(viewModel.cvs.map(\.name) == ["Original"])
        #expect(isLoaded(viewModel))
    }
}
