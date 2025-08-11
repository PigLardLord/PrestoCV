import SwiftUI
import PrestoCVCore

final class TemplateSelectionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var viewState: ViewState<[CVModel]> = .idle
    
    // MARK: - Private Properties
    private let sampleRepository: SampleCVRepositoryProtocol
    
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
    init(sampleRepository: SampleCVRepositoryProtocol) {
        self.sampleRepository = sampleRepository
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
    func selectTemplate(_ template: CVModel) async -> CVModel? {
        do {
            // Create a new CV from the selected template
            let newCV = try await sampleRepository.getDefaultSample()
            return newCV
        } catch {
            // Don't set viewState to error here as this is not a UI error
            // but a method that returns nil on failure
            return nil
        }
    }
    
    @MainActor
    func clearError() {
        viewState = viewState.clearingError()
    }
}