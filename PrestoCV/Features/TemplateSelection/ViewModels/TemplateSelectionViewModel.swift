import SwiftUI
import PrestoCVCore

final class TemplateSelectionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var viewState: ViewState<[CVModel]> = .idle
    @Published var isCreatingCV: Bool = false  // For showing progress during CV creation
    
    // MARK: - Private Properties
    private let sampleRepository: SampleCVRepositoryProtocol
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    
    // MARK: - Computed Properties
    var templates: [CVModel] {
        viewState.data ?? []
    }
    
    var isLoading: Bool {
        viewState.isLoading || isCreatingCV
    }
    
    var errorMessage: String {
        viewState.errorMessage ?? ""
    }
    
    // MARK: - Initialization
    init(
        sampleRepository: SampleCVRepositoryProtocol,
        cvManagementUseCase: CVManagementUseCaseProtocol
    ) {
        self.sampleRepository = sampleRepository
        self.cvManagementUseCase = cvManagementUseCase
    }
    
    // MARK: - Public Methods
    @MainActor
    func loadTemplates() async {
        viewState = .loading
        
        do {
            let loadedTemplates = try await sampleRepository.getAllSamples()
            viewState = .loaded(loadedTemplates)
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    @MainActor
    func createNewEmptyCV() async -> String? {
        isCreatingCV = true
        defer { isCreatingCV = false }
        
        do {
            let emptyCV = try await sampleRepository.getDefaultSample()
            let createdCV = try await cvManagementUseCase.createCV(from: emptyCV)
            return createdCV.id.uuidString
        } catch {
            viewState = .error(error.localizedDescription)
            return nil
        }
    }
    
    @MainActor
    func createCVFromTemplate(_ template: CVModel) async -> String? {
        isCreatingCV = true
        defer { isCreatingCV = false }
        
        do {
            let createdCV = try await cvManagementUseCase.createCV(from: template)
            return createdCV.id.uuidString
        } catch {
            viewState = .error(error.localizedDescription)
            return nil
        }
    }
    
    @MainActor
    func clearError() {
        viewState = viewState.clearingError()
    }
}