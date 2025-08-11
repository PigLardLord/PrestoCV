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
    }
    
    // MARK: - Public Methods
    @MainActor
    func loadCV() async {
        // If no CV ID, we're creating a new CV, so leave the default empty CV
        guard let cvId = cvId,
              let uuid = UUID(uuidString: cvId) else { return }
        
        viewState = .loading
        
        do {
            try await loadExistingCV(with: uuid)
            viewState = .loaded(cv)
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
    
    @MainActor
    func saveCV() async -> Bool {
        viewState = .loading
        
        do {
            if isNewCV {
                // Create new CV from current data
                let _ = try await cvManagementUseCase.createCV(from: cv)
            } else {
                // Update existing CV
                let _ = try await cvManagementUseCase.updateCV(cv)
            }
            viewState = .loaded(cv)
            return true
        } catch {
            viewState = .error(error.localizedDescription)
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
    private func loadExistingCV(with uuid: UUID) async throws {
        guard let loadedCV = try await cvManagementUseCase.getCV(by: uuid) else {
            throw CVLoadingError.cvNotFound
        }
        cv = loadedCV
    }
    
    private enum CVLoadingError: Error {
        case cvNotFound
    }
}
