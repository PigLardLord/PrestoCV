import SwiftUI
import PrestoCVCore

@MainActor
final class CVListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var viewState: ViewState<[CVModel]> = .idle
    
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
    
    // MARK: - Initialization
    init(cvManagementUseCase: CVManagementUseCaseProtocol) {
        self.cvManagementUseCase = cvManagementUseCase
    }
    
    // MARK: - Public Methods
    func loadCVs() async {
        viewState = .loading
        
        do {
            let loadedCVs = try await cvManagementUseCase.getAllCVs()
            viewState = .loaded(loadedCVs)
        } catch {
            viewState = .error(error.localizedDescription)
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
            viewState = .error(error.localizedDescription)
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
            viewState = .error(error.localizedDescription)
        }
    }
    
    func clearError() {
        viewState = viewState.clearingError()
    }
}
