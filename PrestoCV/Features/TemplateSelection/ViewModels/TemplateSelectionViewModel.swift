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
            viewState = .error(error.localizedAppErrorDescription)
        }
    }
    
    @MainActor
    func getEmptyTemplate() async -> CVModel? {
        do {
            return try await sampleRepository.getDefaultSample()
        } catch {
            viewState = .error(error.localizedAppErrorDescription)
            return nil
        }
    }
    
    @MainActor
    func clearError() {
        viewState = viewState.clearingError()
    }
}