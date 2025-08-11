import Foundation
import PrestoCVCore

final class ViewModelFactory {
    private let dependencyContainer: DependencyContainer
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
    }
    
    @MainActor
    func makeTemplateSelectionViewModel() throws -> TemplateSelectionViewModel {
        return TemplateSelectionViewModel(
            templateRepository: try dependencyContainer.makeTemplateRepository()
        )
    }
    
    @MainActor
    func makeCVEditorViewModel(cvId: String?) throws -> CVEditorViewModel {
        return CVEditorViewModel(
            cvId: cvId,
            cvManagementUseCase: try dependencyContainer.makeCVManagementUseCase()
        )
    }
}