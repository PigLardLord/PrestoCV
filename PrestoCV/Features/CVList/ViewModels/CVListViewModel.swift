import SwiftUI
import PrestoCVCore

@MainActor
final class CVListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var viewState: ViewState<[CVModel]> = .idle
    @Published private(set) var unreadableCount = 0
    
    // MARK: - Private Properties
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    
    // MARK: - Computed Properties
    var cvs: [CVModel] {
        viewState.data ?? []
    }
    
    var isLoading: Bool {
        viewState.isLoading
    }
    
    var errorMessage: String {
        viewState.errorMessage ?? ""
    }
    
    /// Tells the user that some stored CVs could not be opened; nil when every stored CV was.
    var unreadableNotice: String? {
        guard unreadableCount > 0 else { return nil }
        return String(localized: "cv.list.unreadable_notice \(unreadableCount)")
    }
    
    // MARK: - Initialization
    init(cvManagementUseCase: CVManagementUseCaseProtocol) {
        self.cvManagementUseCase = cvManagementUseCase
    }
    
    // MARK: - Public Methods
    func loadCVs() async {
        viewState = .loading
        
        do {
            show(try await cvManagementUseCase.getCVListing())
        } catch {
            unreadableCount = 0
            viewState = .error(error.localizedAppErrorDescription)
        }
    }
    
    /// The user has seen the notice about the CVs that could not be opened: record it, so that it goes away.
    func dismissUnreadableNotice() async {
        do {
            try await cvManagementUseCase.acknowledgeUnreadableCVs()
            show(try await cvManagementUseCase.getCVListing())
        } catch {
            viewState = .error(error.localizedAppErrorDescription)
        }
    }
    
    func deleteCV(withId id: UUID) async {
        do {
            try await cvManagementUseCase.deleteCV(id: id)
            // Update local state to reflect deletion
            if var currentCVs = viewState.data {
                currentCVs.removeAll { $0.id == id }
                viewState = .loaded(currentCVs)
            }
        } catch {
            viewState = .error(error.localizedAppErrorDescription)
        }
    }
    
    func duplicateCV(withId id: UUID) async {
        do {
            let duplicatedCV = try await cvManagementUseCase.duplicateCV(id: id)
            // Update local state to include duplicated CV
            if var currentCVs = viewState.data {
                currentCVs.append(duplicatedCV)
                viewState = .loaded(currentCVs)
            }
        } catch {
            viewState = .error(error.localizedAppErrorDescription)
        }
    }
    
    func clearError() {
        viewState = viewState.clearingError()
    }
    
    private func show(_ listing: CVListing) {
        unreadableCount = listing.unreadableCount
        viewState = .loaded(listing.cvs)
    }
    
    // MARK: - View Action Methods (Synchronous wrappers)
    
    func performDeleteCVs(at indexSet: IndexSet) {
        Task {
            for index in indexSet {
                await deleteCV(withId: cvs[index].id)
            }
        }
    }
}
