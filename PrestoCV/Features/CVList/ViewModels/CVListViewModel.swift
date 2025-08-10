import SwiftUI
import PrestoCVCore

@MainActor
final class CVListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var cvs: [CVModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Private Properties
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    
    // MARK: - Initialization
    init(cvManagementUseCase: CVManagementUseCaseProtocol) {
        self.cvManagementUseCase = cvManagementUseCase
    }
    
    // MARK: - Public Methods
    func loadCVs() async {
        isLoading = true
        errorMessage = ""
        
        do {
            cvs = try await cvManagementUseCase.getAllCVs()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func deleteCV(withId id: UUID) async {
        do {
            try await cvManagementUseCase.deleteCV(id: id)
            // Remove from local array to update UI immediately
            cvs.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func duplicateCV(withId id: UUID) async {
        do {
            let duplicatedCV = try await cvManagementUseCase.duplicateCV(id: id)
            // Add to local array to update UI immediately
            cvs.append(duplicatedCV)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}