import SwiftUI
import PrestoCVCore

final class TemplateSelectionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var templates: [CVModel] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Private Properties
    private let templateRepository: TemplateRepositoryProtocol
    
    // MARK: - Initialization
    init(templateRepository: TemplateRepositoryProtocol) {
        self.templateRepository = templateRepository
    }
    
    // MARK: - Public Methods
    @MainActor
    func loadTemplates() async {
        isLoading = true
        errorMessage = ""
        
        do {
            templates = try await templateRepository.getAllTemplates()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func selectTemplate(_ template: CVModel) async -> CVModel? {
        do {
            // Create a new CV from the selected template
            let newCV = try await templateRepository.getDefaultTemplate()
            return newCV
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}