import SwiftUI
import PrestoCVCore

final class TemplateSelectionViewModel: ObservableObject {
    
    // MARK: - State Management
    enum TemplateSelectionState {
        case idle
        case loadingTemplates
        case loadingTemplate(CVModel)  // When creating CV from template
        case creatingEmptyCV           // When creating empty CV
        case loaded([CVModel])
        case error(String)
        
        var isLoading: Bool {
            switch self {
            case .loadingTemplates, .loadingTemplate, .creatingEmptyCV:
                return true
            default:
                return false
            }
        }
        
        var errorMessage: String? {
            if case .error(let message) = self {
                return message
            }
            return nil
        }
        
        var templates: [CVModel]? {
            if case .loaded(let templates) = self {
                return templates
            }
            return nil
        }
    }
    
    // MARK: - Published Properties
    @Published var viewState: TemplateSelectionState = .idle
    
    // MARK: - Private Properties
    private let sampleRepository: SampleCVRepositoryProtocol
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    
    // MARK: - Computed Properties
    var templates: [CVModel] {
        viewState.templates ?? []
    }
    
    var isLoading: Bool {
        viewState.isLoading
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
        viewState = .loadingTemplates
        
        do {
            let loadedTemplates = try await sampleRepository.getAllSamples()
            viewState = .loaded(loadedTemplates)
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    @MainActor
    func createNewEmptyCV() async -> String? {
        viewState = .creatingEmptyCV
        
        do {
            let emptyCV = try await sampleRepository.getDefaultSample()
            let createdCV = try await cvManagementUseCase.createCV(from: emptyCV)
            // Reload templates to ensure consistency
            await loadTemplates()
            return createdCV.id.uuidString
        } catch {
            viewState = .error(error.localizedDescription)
            return nil
        }
    }
    
    @MainActor
    func createCVFromTemplate(_ template: CVModel) async -> String? {
        viewState = .loadingTemplate(template)
        
        do {
            let createdCV = try await cvManagementUseCase.createCV(from: template)
            // Reload templates to ensure consistency
            await loadTemplates()
            return createdCV.id.uuidString
        } catch {
            viewState = .error(error.localizedDescription)
            return nil
        }
    }
    
    @MainActor
    func clearError() {
        // Reset to loaded state with current templates, or idle if no templates
        if case .loaded(let templates) = viewState {
            self.viewState = .loaded(templates)
        } else {
            viewState = .idle
        }
    }
}