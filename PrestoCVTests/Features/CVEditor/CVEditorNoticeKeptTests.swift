import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

@MainActor
@Suite("CVEditorViewModel - the import's notice stays with the CV until the person dismisses it (#452)", .timeLimit(.minutes(1)))
struct CVEditorNoticeKeptTests {

    private let review = ImportReview(
        items: [ImportReview.Item(field: .title, reason: .byPosition, text: "Mobile Developer")],
        passages: [
            ImportReview.Passage(place: .top, text: "EU citizen\navailable from March 2026", isWholeSection: false),
            ImportReview.Passage(place: .section("OWN VENTURES"), text: "Tidepool Notes | 2021 – today", isWholeSection: true),
        ]
    )

    private func imported() -> CVModel {
        CVModel(personalInfo: PersonalInfo(name: "Tobias Renn", title: "Mobile Developer"))
    }

    @Test("An imported CV keeps its notice once it is stored, under the id it is stored with")
    func importedNoticeIsKeptWithTheCV() async throws {
        let useCase = MockCVManagementUseCase()
        let store = InMemoryEditorNoticeStore()
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .imported(review), cvManagementUseCase: useCase, noticeStore: store
        )

        await viewModel.saveNow()

        let stored = try #require(await useCase.createdCVs.first)
        #expect(await store.notice(ofCVWithId: stored.id) == .imported(review))
    }

    @Test("A stored CV opens again with the notice kept for it")
    func storedCVOpensWithItsNotice() async {
        let useCase = MockCVManagementUseCase()
        let cv = CVModel(id: UUID(), name: "", personalInfo: PersonalInfo(name: "Tobias Renn"))
        await useCase.storeCV(cv)
        let store = InMemoryEditorNoticeStore(notices: [cv.id: .importedDescription(review)])
        let viewModel = CVEditorViewModel(cvId: cv.id.uuidString, cvManagementUseCase: useCase, noticeStore: store)

        await viewModel.loadCV()

        #expect(viewModel.notice == .importedDescription(review))
        #expect(viewModel.notice?.review?.sectionsNotImported == ["OWN VENTURES"])
    }

    @Test("A stored CV with no notice kept opens without one")
    func storedCVWithoutNotice() async {
        let useCase = MockCVManagementUseCase()
        let cv = CVModel(id: UUID(), name: "Kept", personalInfo: PersonalInfo(name: "Mara Ellison"))
        await useCase.storeCV(cv)
        let viewModel = CVEditorViewModel(cvId: cv.id.uuidString, cvManagementUseCase: useCase, noticeStore: InMemoryEditorNoticeStore())

        await viewModel.loadCV()

        #expect(viewModel.notice == nil)
    }

    @Test("Dismissing the notice of a stored CV forgets it, so the CV opens again without it")
    func dismissedNoticeIsForgotten() async {
        let useCase = MockCVManagementUseCase()
        let cv = CVModel(id: UUID(), name: "", personalInfo: PersonalInfo(name: "Tobias Renn"))
        await useCase.storeCV(cv)
        let store = InMemoryEditorNoticeStore(notices: [cv.id: .imported(review)])
        let viewModel = CVEditorViewModel(cvId: cv.id.uuidString, cvManagementUseCase: useCase, noticeStore: store)
        await viewModel.loadCV()

        await viewModel.dismissNotice()

        #expect(viewModel.notice == nil)
        #expect(await store.notice(ofCVWithId: cv.id) == nil)
        let reopened = CVEditorViewModel(cvId: cv.id.uuidString, cvManagementUseCase: useCase, noticeStore: store)
        await reopened.loadCV()
        #expect(reopened.notice == nil)
    }

    @Test("A notice dismissed before the imported CV is stored is never kept")
    func noticeDismissedBeforeTheStore() async throws {
        let useCase = MockCVManagementUseCase()
        let store = InMemoryEditorNoticeStore()
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .imported(review), cvManagementUseCase: useCase, noticeStore: store
        )

        await viewModel.dismissNotice()
        await viewModel.saveNow()

        let stored = try #require(await useCase.createdCVs.first, "The imported CV is stored as it is")
        #expect(await store.notice(ofCVWithId: stored.id) == nil)
    }

    @Test("Dismissing the notice after the imported CV is stored forgets it")
    func noticeDismissedAfterTheStore() async throws {
        let useCase = MockCVManagementUseCase()
        let store = InMemoryEditorNoticeStore()
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .imported(review), cvManagementUseCase: useCase, noticeStore: store
        )
        await viewModel.saveNow()
        let stored = try #require(await useCase.createdCVs.first)

        await viewModel.dismissNotice()

        #expect(await store.notice(ofCVWithId: stored.id) == nil)
    }

    @Test("The AI draft's notice is not kept: it says nothing to come back to")
    func aiDraftNoticeIsNotKept() async throws {
        let useCase = MockCVManagementUseCase()
        let store = InMemoryEditorNoticeStore()
        let viewModel = CVEditorViewModel(
            cvId: nil, initialCV: imported(), notice: .aiDraft, cvManagementUseCase: useCase, noticeStore: store
        )

        await viewModel.saveNow()

        let stored = try #require(await useCase.createdCVs.first)
        #expect(viewModel.notice == .aiDraft, "The editor still shows it")
        #expect(await store.notice(ofCVWithId: stored.id) == nil)
    }

    @Test("The import's notice offers a way to dismiss it; the AI draft's reminder and no notice do not")
    func onlyAKeptNoticeIsDismissible() {
        let useCase = MockCVManagementUseCase()
        let notices: [(EditorNotice?, Bool)] = [
            (.imported(review), true),
            (.importedDescription(review), true),
            (.imported(ImportReview(items: [], notImported: "")), true),
            (.aiDraft, false),
            (.aiDraftUnchecked, false),
            (nil, false),
        ]

        for (notice, dismissible) in notices {
            let viewModel = CVEditorViewModel(
                cvId: nil, initialCV: imported(), notice: notice, cvManagementUseCase: useCase, noticeStore: InMemoryEditorNoticeStore()
            )
            #expect(viewModel.noticeIsDismissible == dismissible, "\(String(describing: notice))")
        }
    }
}
