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
    
    @MainActor
    func addEducation() {
        cv.education.append(Education())
    }
    
    @MainActor
    func removeEducation(at index: Int) {
        cv.education.remove(at: index)
    }
    
    @MainActor
    func addLanguage() {
        cv.languages.append(Language())
    }
    
    @MainActor
    func removeLanguage(at index: Int) {
        cv.languages.remove(at: index)
    }
    
    @MainActor
    func addCertification() {
        cv.certifications.append(Certification())
    }
    
    @MainActor
    func removeCertification(at index: Int) {
        cv.certifications.remove(at: index)
    }
    
    @MainActor
    func addSocial() {
        cv.social.append(Social())
    }
    
    @MainActor
    func removeSocial(at index: Int) {
        cv.social.remove(at: index)
    }
    
    @MainActor
    func addInterest() {
        cv.interests.append("")
    }
    
    @MainActor
    func removeInterest(at index: Int) {
        cv.interests.remove(at: index)
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