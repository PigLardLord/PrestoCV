import SwiftUI
import PrestoCVCore
import CVPDFExporter

/// New TemplateSelectionViewModel using Template system from CVPDFExporter
/// Replaces the old SampleCVRepository-based implementation
@MainActor
final class NewTemplateSelectionViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var viewState: ViewState<[TemplateDisplayModel]> = .idle
    @Published var isCreatingCV: Bool = false  // For showing progress during CV creation

    // MARK: - Private Properties
    private let getTemplatesUseCase: GetAvailableTemplatesUseCase
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    private let templateConverter = TemplateToCVModelConverter()

    // MARK: - Computed Properties
    var templates: [TemplateDisplayModel] {
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
        getTemplatesUseCase: GetAvailableTemplatesUseCase,
        cvManagementUseCase: CVManagementUseCaseProtocol
    ) {
        self.getTemplatesUseCase = getTemplatesUseCase
        self.cvManagementUseCase = cvManagementUseCase
    }

    // MARK: - Public Methods

    /// Loads all available templates from the template repositories
    func loadTemplates() async {
        viewState = .loading

        do {
            let loadedTemplates = try await getTemplatesUseCase.execute()
            let displayModels = loadedTemplates.map { TemplateDisplayModel(from: $0) }
            viewState = .loaded(displayModels)
        } catch {
            viewState = .error(error.localizedAppErrorDescription)
        }
    }

    /// Converts a template to a CVModel ready for editing
    /// - Parameter templateDisplay: The template display model to convert
    /// - Returns: A CVModel with the template's name and empty content
    func createCVFromTemplate(_ templateDisplay: TemplateDisplayModel) -> CVModel {
        return templateConverter.convert(template: templateDisplay.template)
    }

    /// Clears any error state
    func clearError() async {
        viewState = viewState.clearingError()
    }
}
