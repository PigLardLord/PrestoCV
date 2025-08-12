import SwiftUI
import PrestoCVCore

final class TemplateSelectionViewModel: ObservableObject {
    
    // MARK: - State Management
    enum TemplateSelectionState: Equatable {
        case idle
        case loadingTemplates
        case loadingTemplate(CVModel)  // When creating CV from template
        case creatingEmptyCV           // When creating empty CV
        case loaded([CVModel])
        case error(AppError)
        
        var isLoading: Bool {
            switch self {
            case .loadingTemplates, .loadingTemplate, .creatingEmptyCV:
                return true
            default:
                return false
            }
        }
        
        var appError: AppError? {
            if case .error(let error) = self {
                return error
            }
            return nil
        }
        
        var templates: [CVModel]? {
            if case .loaded(let templates) = self {
                return templates
            }
            return nil
        }
        
        static func == (lhs: TemplateSelectionState, rhs: TemplateSelectionState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.loadingTemplates, .loadingTemplates),
                 (.creatingEmptyCV, .creatingEmptyCV):
                return true
            case (.loadingTemplate(let lhsTemplate), .loadingTemplate(let rhsTemplate)):
                return lhsTemplate.id == rhsTemplate.id
            case (.loaded(let lhsTemplates), .loaded(let rhsTemplates)):
                return lhsTemplates.count == rhsTemplates.count
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
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
        viewState.appError?.localizedDescription ?? ""
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
            let appError = error as? AppError ?? AppError.unknown(error.localizedDescription)
            viewState = .error(appError)
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
            let appError = error as? AppError ?? AppError.unknown(error.localizedDescription)
            viewState = .error(appError)
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
            let appError = error as? AppError ?? AppError.unknown(error.localizedDescription)
            viewState = .error(appError)
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