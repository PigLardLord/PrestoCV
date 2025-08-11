import SwiftUI
import PrestoCVCore

final class TemplateSelectionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var viewState: ViewState<[CVModel]> = .idle
    
    // MARK: - Private Properties
    private let templateRepository: TemplateRepositoryProtocol
    
    // MARK: - Computed Properties
    var templates: [CVModel] {
        viewState.data ?? []
    }
    
    var isLoading: Bool {
        viewState.isLoading
    }
    
    var errorMessage: String {
        viewState.errorMessage ?? ""
    }
    
    // MARK: - Initialization
    init(templateRepository: TemplateRepositoryProtocol) {
        self.templateRepository = templateRepository
    }
    
    // MARK: - Public Methods
    @MainActor
    func loadTemplates() async {
        viewState = .loading
        
        do {
            let loadedTemplates = try await templateRepository.getAllTemplates()
            viewState = .loaded(loadedTemplates)
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    @MainActor
    func selectTemplate(_ template: CVModel) async -> CVModel? {
        do {
            // Create a new CV from the selected template
            let newCV = try await templateRepository.getDefaultTemplate()
            return newCV
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