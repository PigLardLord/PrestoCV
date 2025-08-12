import SwiftUI
import PrestoCVCore

final class CVEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var cv: CVModel = CVModel()
    @Published var viewState: ViewState<CVModel> = .idle
    
    // MARK: - Private Properties
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    private let cvId: String?
    private var isNewCV: Bool { cvId == nil }
    
    // MARK: - Computed Properties
    var isLoading: Bool {
        viewState.isLoading
    }
    
    var errorMessage: String {
        viewState.errorMessage ?? ""
    }
    
    // MARK: - Initialization
    init(
        cvId: String?,
        cvManagementUseCase: CVManagementUseCaseProtocol
    ) {
        self.cvId = cvId
        self.cvManagementUseCase = cvManagementUseCase
        
        // For new CVs, initialize with loaded state
        if cvId == nil {
            viewState = .loaded(cv)
        }
    }
    
    // MARK: - Public Methods
    @MainActor
    func loadCV() async {
        // If no CV ID, we're creating a new CV, so leave the default empty CV
        guard let cvId = cvId,
              let uuid = UUID(uuidString: cvId) else { 
            // For new CVs, set state to loaded with empty CV
            viewState = .loaded(cv)
            return 
        }
        
        viewState = .loading
        
        do {
            try await loadExistingCV(with: uuid)
            viewState = .loaded(cv)
        } catch {
            let appError = error as? AppError ?? AppError.unknown(error.localizedDescription)
            viewState = .error(appError.localizedDescription)
        }
    }
    
    @MainActor
    func saveCV() async -> Bool {
        viewState = .loading
        
        do {
            let savedCV: CVModel
            if isNewCV {
                // Create new CV from current data
                savedCV = try await cvManagementUseCase.createCV(from: cv)
            } else {
                // Update existing CV
                savedCV = try await cvManagementUseCase.updateCV(cv)
            }
            // Update the local CV with the saved one (might have updated ID or timestamps)
            cv = savedCV
            viewState = .loaded(cv)
            return true
        } catch {
            let appError = error as? AppError ?? AppError.unknown(error.localizedDescription)
            viewState = .error(appError.localizedDescription)
            return false
        }
    }
    
    @MainActor
    func clearError() {
        viewState = viewState.clearingError()
    }
    
    @MainActor
    func addSkill() {
        cv.skills.append(Skill(name: ""))
    }
    
    @MainActor
    func removeSkill(at index: Int) {
        cv.skills.remove(at: index)
    }
    
    @MainActor
    func addExperience() {
        cv.relevant_experience.append(Experience())
    }
    
    @MainActor
    func removeExperience(at index: Int) {
        cv.relevant_experience.remove(at: index)
    }
    
    // MARK: - Private Methods
    @MainActor
    private func loadExistingCV(with uuid: UUID) async throws {
        guard let loadedCV = try await cvManagementUseCase.getCV(by: uuid) else {
            throw AppError.notFound("CV with id \(uuid)")
        }
        cv = loadedCV
    }
}