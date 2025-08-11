import SwiftUI
import PrestoCVCore

final class CVEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var cv: CVModel = CVModel()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Private Properties
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    private let cvId: String?
    private var isNewCV: Bool { cvId == nil }
    
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
        guard let cvId = cvId,
              let uuid = UUID(uuidString: cvId) else {
            // If no CV ID, we're creating a new CV, so leave the default empty CV
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            // For editing existing CVs, we would load it here
            // For now, we'll just create a placeholder implementation
            // In a real app, you would fetch the CV by ID from the repository
            cv = CVModel()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func saveCV() async -> Bool {
        isLoading = true
        errorMessage = ""
        
        do {
            if isNewCV {
                // Create new CV from current data
                let _ = try await cvManagementUseCase.createCV(from: cv)
            } else {
                // Update existing CV
                let _ = try await cvManagementUseCase.updateCV(cv)
            }
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
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
}