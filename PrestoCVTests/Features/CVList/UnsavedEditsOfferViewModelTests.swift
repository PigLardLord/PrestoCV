import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// At launch the app offers to restore what an earlier run kept and nobody saved or discarded.
@MainActor
@Suite("UnsavedEditsOfferViewModel Tests - the offer to restore unsaved edits")
struct UnsavedEditsOfferViewModelTests {

    /// The offer of one window. Windows of one run share the unsaved edits of the app: pass the same `useCase`.
    private func makeOffer(
        repository: InMemoryUnsavedEditsRepository,
        cvs: MockCVManagementUseCase = MockCVManagementUseCase(),
        useCase: UnsavedEditsUseCase? = nil
    ) -> UnsavedEditsOfferViewModel {
        UnsavedEditsOfferViewModel(
            useCase: useCase ?? UnsavedEditsUseCase(repository: repository, now: { Date() }),
            cvs: cvs,
            locale: Locale(identifier: "en_US"),
            timeZone: TimeZone(identifier: "UTC") ?? .gmt
        )
    }

    private func keep(
        _ cv: CVModel,
        over base: CVModel? = nil,
        at keptAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        in repository: InMemoryUnsavedEditsRepository
    ) async throws -> UnsavedEdits {
        let edits = UnsavedEdits(id: UUID(), cv: cv, base: base, keptAt: keptAt)
        try await repository.keep(edits)
        return edits
    }

    @Test("Edits an earlier run kept are offered, naming the CV and when it was last changed")
    func editsOfAnEarlierRunAreOffered() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let kept = try await keep(CVModel(personalInfo: PersonalInfo(name: "Marta Rinaldi")), in: repository)
        let offer = makeOffer(repository: repository)

        await offer.checkForEditsToRestore()

        #expect(offer.offer == kept)
        #expect(offer.isShowingOffer)
        let message = try #require(offer.message)
        #expect(message.contains("Marta Rinaldi"))
        #expect(message.contains("2023"), "The day of the change is told: \(message)")
        #expect(!message.contains("unsaved_edits"), "The message must be translated, not show its key")
    }

    @Test("Nothing is offered when nothing was kept, or only edits an editor holds")
    func nothingIsOfferedWithoutEditsNobodyHolds() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let app = UnsavedEditsUseCase(repository: repository, now: { Date() })
        let offer = makeOffer(repository: repository, useCase: app)
        await offer.checkForEditsToRestore()
        #expect(offer.offer == nil)

        let editorInAnotherWindow = try #require(await app.claimEditing(UUID()))
        try await app.keep(CVModel(name: "Open in another window"), over: nil, as: editorInAnotherWindow)
        await offer.checkForEditsToRestore()
        #expect(offer.offer == nil)
        #expect(offer.isShowingOffer == false)
    }

    @Test("Restoring hands the edits over and keeps them until the editor saves or discards them")
    func restoringHandsTheEditsOver() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let kept = try await keep(CVModel(name: "Ward nurse"), in: repository)
        let offer = makeOffer(repository: repository)
        await offer.checkForEditsToRestore()

        let restored = await offer.restore()

        #expect(restored?.edits == kept)
        #expect(restored?.takeClaim() != nil, "The editor gets the window's claim on them")
        #expect(offer.offer == nil)
        #expect(offer.isShowingOffer == false)
        #expect(await repository.kept[kept.id] == kept)
    }

    @Test("Discarding removes the edits and offers the next ones left behind")
    func discardingOffersTheNextEdits() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let older = try await keep(CVModel(name: "Older"), at: Date(timeIntervalSince1970: 1_600_000_000), in: repository)
        let newer = try await keep(CVModel(name: "Newer"), at: Date(timeIntervalSince1970: 1_700_000_000), in: repository)
        let offer = makeOffer(repository: repository)
        await offer.checkForEditsToRestore()
        #expect(offer.offer == newer, "The latest edits come first")

        await offer.discard()

        #expect(await repository.kept[newer.id] == nil)
        #expect(offer.offer == older)
        #expect(offer.isShowingOffer)
    }

    @Test("Edits that cannot be listed are not offered, and stay for the next launch")
    func unlistableEditsAreNotOffered() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let kept = try await keep(CVModel(name: "Ward nurse"), in: repository)
        await repository.fail(with: AppError.fileSystemError("locked"))
        let offer = makeOffer(repository: repository)

        await offer.checkForEditsToRestore()
        await repository.fail(with: nil)

        #expect(offer.offer == nil)
        #expect(await repository.kept[kept.id] == kept)
    }

    @Test("Two windows choosing Restore on the same edits: one gets them, the other is told they are no longer available")
    func twoWindowsRestoringTheSameEdits() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let kept = try await keep(CVModel(name: "Ward nurse"), in: repository)
        let app = UnsavedEditsUseCase(repository: repository, now: { Date() })
        let firstWindow = makeOffer(repository: repository, useCase: app)
        let secondWindow = makeOffer(repository: repository, useCase: app)
        await firstWindow.checkForEditsToRestore()
        await secondWindow.checkForEditsToRestore()
        #expect(firstWindow.offer == kept && secondWindow.offer == kept, "Both windows offered the edits before either was answered")

        async let first = firstWindow.restore()
        async let second = secondWindow.restore()
        let restored = await [first, second]

        #expect(restored.compactMap { $0?.edits } == [kept], "Only one window gets the edits")
        #expect([firstWindow, secondWindow].filter(\.isShowingNoLongerAvailable).count == 1, "The other is told")
        #expect(await repository.kept[kept.id] == kept, "The window that got them keeps them for its editor")
    }

    @Test("Discarding edits another window has restored leaves them to it, and says so")
    func discardingEditsAnotherWindowRestoredLeavesThem() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let kept = try await keep(CVModel(name: "Ward nurse"), in: repository)
        let app = UnsavedEditsUseCase(repository: repository, now: { Date() })
        let restoringWindow = makeOffer(repository: repository, useCase: app)
        let discardingWindow = makeOffer(repository: repository, useCase: app)
        await restoringWindow.checkForEditsToRestore()
        await discardingWindow.checkForEditsToRestore()

        let restored = await restoringWindow.restore()
        #expect(restored?.edits == kept)
        await discardingWindow.discard()

        #expect(await repository.kept[kept.id] == kept, "Only the window that has the edits changes them")
        #expect(discardingWindow.isShowingNoLongerAvailable)
        withExtendedLifetime(restored) {}
    }

    @Test("Restored edits whose editor never opened, as when the window closed first, are offered again")
    func restoredEditsNobodyTookAreOfferedAgain() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let kept = try await keep(CVModel(name: "Ward nurse"), in: repository)
        let app = UnsavedEditsUseCase(repository: repository, now: { Date() })
        let closingWindow = makeOffer(repository: repository, useCase: app)
        let otherWindow = makeOffer(repository: repository, useCase: app)
        await closingWindow.checkForEditsToRestore()
        var restored = await closingWindow.restore()
        #expect(restored?.edits == kept)

        restored = nil

        #expect(await finishes { await waitUntilOffered(kept, to: otherWindow) }, "The claim nobody took is let go")
    }

    @Test("Edits that could not be discarded are let go, and offered again")
    func editsThatCouldNotBeDiscardedAreOfferedAgain() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let kept = try await keep(CVModel(name: "Ward nurse"), in: repository)
        let offer = makeOffer(repository: repository)
        await offer.checkForEditsToRestore()
        await repository.failDiscarding(with: AppError.fileSystemError("locked"))

        await offer.discard()

        #expect(await repository.kept[kept.id] == kept)
        #expect(offer.offer == kept, "The edits are offered again")
        #expect(offer.isShowingNoLongerAvailable == false)
    }

    @Test("An offer that no longer matches what is kept is refused and holds nothing: the current edits are offered")
    func aMismatchedOfferIsReleased() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let kept = try await keep(CVModel(name: "First"), in: repository)
        let app = UnsavedEditsUseCase(repository: repository, now: { Date() })
        let staleWindow = makeOffer(repository: repository, useCase: app)
        let otherWindow = makeOffer(repository: repository, useCase: app)
        await staleWindow.checkForEditsToRestore()
        let changed = UnsavedEdits(id: kept.id, cv: CVModel(name: "Second"), base: nil, keptAt: kept.keptAt.addingTimeInterval(60))
        try await repository.keep(changed)

        #expect(await staleWindow.restore() == nil)
        #expect(staleWindow.isShowingNoLongerAvailable)
        await otherWindow.checkForEditsToRestore()
        #expect(otherWindow.offer == changed, "The refused claim must not hide the edits")
        #expect(await otherWindow.restore()?.edits == changed)
    }

    /// Returns once `window` offers `edits`.
    private func waitUntilOffered(_ edits: UnsavedEdits, to window: UnsavedEditsOfferViewModel) async {
        repeat {
            await window.checkForEditsToRestore()
            await Task.yield()
        } while window.offer != edits && !Task.isCancelled
    }

    @Test("An offer whose edits are gone meanwhile is refused, and the person is told")
    func anOfferWhoseEditsAreGoneIsRefused() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let kept = try await keep(CVModel(name: "Ward nurse"), in: repository)
        let offer = makeOffer(repository: repository)
        await offer.checkForEditsToRestore()

        try await repository.discard(editing: kept.id)

        #expect(await offer.restore() == nil)
        #expect(offer.isShowingNoLongerAvailable)
    }

    @Test("Edits the stored CV already holds are removed instead of offered, and the next ones are offered")
    func savedEditsAreRemovedInsteadOfOffered() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let cvs = MockCVManagementUseCase()
        let saved = CVModel(name: "Saved before the app was ended")
        await cvs.storeCV(saved)
        let older = try await keep(CVModel(name: "Older"), at: Date(timeIntervalSince1970: 1_600_000_000), in: repository)
        let alreadySaved = try await keep(saved, over: saved, at: Date(timeIntervalSince1970: 1_700_000_000), in: repository)
        let offer = makeOffer(repository: repository, cvs: cvs)

        await offer.checkForEditsToRestore()

        #expect(await repository.kept[alreadySaved.id] == nil, "Edits that were saved are no longer kept")
        #expect(offer.offer == older)
    }

    @Test("Edits made on a CV that was saved again since are offered as a separate copy")
    func editsOnANewerCVAreOfferedAsACopy() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let cvs = MockCVManagementUseCase()
        let original = CVModel(name: "Ward nurse")
        var newer = original
        newer.personalInfo.title = "Ward sister"
        await cvs.storeCV(newer)
        var edited = original
        edited.personalInfo.location = "Bristol"
        _ = try await keep(edited, over: original, in: repository)
        let offer = makeOffer(repository: repository, cvs: cvs)

        await offer.checkForEditsToRestore()

        #expect(offer.restoresAsCopy)
        let saysItOpensAsACopy = "unsaved_edits.restore.message_copy".localized.components(separatedBy: "%2$@").last ?? ""
        #expect(offer.message?.hasSuffix(saysItOpensAsACopy) == true, "\(offer.message ?? "no message")")
    }

    @Test("Edits whose copy is stored are offered as opening that copy, also once the CV they were made on is gone")
    func editsWhoseCopyIsStoredAreOfferedAsTheCopy() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let cvs = MockCVManagementUseCase()
        let original = CVModel(name: "Ward nurse")
        var edited = original
        edited.personalInfo.location = "Bristol"
        let kept = try await keep(edited, over: original, in: repository)
        var copy = edited
        copy.id = kept.copyID
        await cvs.storeCV(copy)
        let offer = makeOffer(repository: repository, cvs: cvs)

        await offer.checkForEditsToRestore()

        #expect(offer.offer == kept)
        #expect(offer.restoresAsCopy)
    }

    @Test("Edits made on the stored CV as it is are offered to restore over it")
    func editsOnTheStoredCVAreOfferedOverIt() async throws {
        let repository = InMemoryUnsavedEditsRepository()
        let cvs = MockCVManagementUseCase()
        let stored = CVModel(name: "Ward nurse")
        await cvs.storeCV(stored)
        var edited = stored
        edited.personalInfo.location = "Bristol"
        _ = try await keep(edited, over: stored, in: repository)
        let offer = makeOffer(repository: repository, cvs: cvs)

        await offer.checkForEditsToRestore()

        #expect(offer.offer?.cv == edited)
        #expect(offer.restoresAsCopy == false)
    }

    @Test("A CV is called as its editor calls it: its name, its person's, its role, or New CV or Untitled CV without any")
    func cvIsCalledAsTheEditorCallsIt() async throws {
        let cases: [(cv: CVModel, base: CVModel?, title: String)] = [
            (CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi")), nil, "Ward nurse"),
            (CVModel(personalInfo: PersonalInfo(name: "Marta Rinaldi", title: "Nurse")), nil, "Marta Rinaldi"),
            (CVModel(personalInfo: PersonalInfo(title: "Nurse")), nil, "Nurse"),
            (CVModel(personalInfo: PersonalInfo(email: "marta@example.com")), nil, "editor.new_cv".localized),
            (CVModel(personalInfo: PersonalInfo(email: "marta@example.com")), CVModel(), "cv.untitled".localized),
        ]
        for (cv, base, title) in cases {
            let repository = InMemoryUnsavedEditsRepository()
            _ = try await keep(cv, over: base, in: repository)
            let offer = makeOffer(repository: repository)

            await offer.checkForEditsToRestore()

            #expect(offer.message?.contains("“\(title)”") == true, "\(offer.message ?? "no message")")
        }
    }
}
