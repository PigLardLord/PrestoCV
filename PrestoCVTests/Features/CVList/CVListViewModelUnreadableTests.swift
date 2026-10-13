import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Use Case Stub

private final class StubListingUseCase: CVManagementUseCaseProtocol, @unchecked Sendable {
    var listing: Result<CVListing, AppError>
    var acknowledgeResult: Result<Void, AppError> = .success(())
    private(set) var acknowledgeCount = 0
    
    init(listing: Result<CVListing, AppError>) {
        self.listing = listing
    }
    
    func acknowledgeUnreadableCVs() async throws {
        acknowledgeCount += 1
        try acknowledgeResult.get()
        if case .success(let current) = listing {
            listing = .success(CVListing(cvs: current.cvs))
        }
    }
    
    func getCVListing() async throws -> CVListing {
        try listing.get()
    }
    
    func getAllCVs() async throws -> [CVModel] {
        try listing.get().cvs
    }
    
    func createCV(from template: CVModel) async throws -> CVModel { template }
    func updateCV(_ cv: CVModel) async throws -> CVModel { cv }
    func deleteCV(id: UUID) async throws {}
    func duplicateCV(id: UUID) async throws -> CVModel { CVModel() }
    func getCV(by id: UUID) async throws -> CVModel? { nil }
}

// MARK: - CVListViewModel Unreadable CVs Tests

@MainActor
@Suite("CVListViewModel Unreadable CVs Tests")
struct CVListViewModelUnreadableTests {
    
    private func makeViewModel(_ listing: Result<CVListing, AppError>) -> CVListViewModel {
        CVListViewModel(cvManagementUseCase: StubListingUseCase(listing: listing))
    }
    
    @Test("No notice when every stored CV could be opened")
    func noNoticeWhenEveryCVOpened() async {
        let cv = CVModel(name: "Opened")
        let viewModel = makeViewModel(.success(CVListing(cvs: [cv])))
        
        await viewModel.loadCVs()
        
        #expect(viewModel.cvs == [cv])
        #expect(viewModel.unreadableNotice == nil)
    }
    
    @Test("A notice names how many stored CVs could not be opened")
    func noticeNamesTheUnreadableCount() async throws {
        let cv = CVModel(name: "Opened")
        let viewModel = makeViewModel(.success(CVListing(cvs: [cv], unreadableCount: 2)))
        
        await viewModel.loadCVs()
        
        #expect(viewModel.cvs == [cv])
        #expect(viewModel.unreadableCount == 2)
        let notice = try #require(viewModel.unreadableNotice)
        #expect(notice.contains("2"))
        #expect(!notice.contains("cv.list"), "The notice should be translated, not show its catalog key")
    }
    
    @Test("The notice is translated for a single CV as well")
    func noticeIsTranslatedForOneCV() async throws {
        let viewModel = makeViewModel(.success(CVListing(cvs: [], unreadableCount: 1)))
        
        await viewModel.loadCVs()
        
        let notice = try #require(viewModel.unreadableNotice)
        #expect(notice.contains("1"))
        #expect(!notice.contains("cv.list"), "The notice should be translated, not show its catalog key")
    }
    
    @Test("The notice goes away when a later load finds every CV readable")
    func noticeClearsOnNextLoad() async {
        let useCase = StubListingUseCase(listing: .success(CVListing(cvs: [], unreadableCount: 1)))
        let viewModel = CVListViewModel(cvManagementUseCase: useCase)
        await viewModel.loadCVs()
        #expect(viewModel.unreadableNotice != nil)
        
        useCase.listing = .success(CVListing(cvs: [CVModel(name: "Back")]))
        await viewModel.loadCVs()
        
        #expect(viewModel.unreadableNotice == nil)
    }
    
    @Test("Dismissing the notice acknowledges the unreadable CVs and removes the notice")
    func dismissingAcknowledgesAndRemovesTheNotice() async {
        let cv = CVModel(name: "Opened")
        let useCase = StubListingUseCase(listing: .success(CVListing(cvs: [cv], unreadableCount: 2)))
        let viewModel = CVListViewModel(cvManagementUseCase: useCase)
        await viewModel.loadCVs()
        #expect(viewModel.unreadableNotice != nil)
        
        await viewModel.dismissUnreadableNotice()
        
        #expect(useCase.acknowledgeCount == 1)
        #expect(viewModel.unreadableNotice == nil)
        #expect(viewModel.cvs == [cv])
    }
    
    @Test("A dismissal that fails reports the error and keeps the list and the notice")
    func failedDismissalReportsTheError() async {
        let cv = CVModel(name: "Opened")
        let useCase = StubListingUseCase(listing: .success(CVListing(cvs: [cv], unreadableCount: 1)))
        useCase.acknowledgeResult = .failure(.unknown("disk"))
        let viewModel = CVListViewModel(cvManagementUseCase: useCase)
        await viewModel.loadCVs()
        
        await viewModel.dismissUnreadableNotice()
        
        #expect(viewModel.actionError?.contains("disk") == true)
        #expect(viewModel.cvs == [cv], "The list stays on screen")
        #expect(viewModel.unreadableNotice != nil)
        #expect(viewModel.errorMessage.isEmpty)
    }
    
    @Test("A listing that fails shows the error and no notice")
    func failedListingShowsErrorWithoutNotice() async {
        let viewModel = makeViewModel(.failure(.fileSystemError("disk")))
        
        await viewModel.loadCVs()
        
        #expect(viewModel.errorMessage.contains("disk"))
        #expect(viewModel.unreadableNotice == nil)
    }
}
