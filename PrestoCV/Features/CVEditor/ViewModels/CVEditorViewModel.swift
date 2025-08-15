import SwiftUI
import PrestoCVCore

final class CVEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var cv: CVModel = CVModel()
    @Published var viewState: ViewState<CVModel> = .idle
    @Published var showingSaveConfirmation = false
    @Published var showingCancelConfirmation = false
    
    // MARK: - Private Properties
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    private let cvId: String?
    private var isNewCV: Bool { cvId == nil }
    private var saveSuccessTimer: Timer?
    
    // MARK: - Computed Properties
    var isLoading: Bool {
        viewState.isLoading
    }
    
    var errorMessage: String {
        viewState.errorMessage ?? ""
    }
    
    /// Determines if the CV has meaningful content beyond just the name
    var hasMeaningfulContent: Bool {
        // Check if any essential fields have content
        !cv.personalInfo.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !cv.personalInfo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !cv.personalInfo.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !cv.personalInfo.profile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !cv.skills.isEmpty ||
        !cv.relevant_experience.isEmpty ||
        !cv.education.isEmpty ||
        !cv.languages.isEmpty ||
        !cv.certifications.isEmpty ||
        !cv.social.isEmpty ||
        !cv.interests.isEmpty
    }
    
    /// Calculates completion percentage based on filled sections
    var completionPercentage: Double {
        var filledSections = 0
        let totalSections = 8 // Total number of main sections
        
        // CV Name (weight: 1)
        if !cv.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filledSections += 1
        }
        
        // Personal Info (weight: 1) - any field counts
        if !cv.personalInfo.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           !cv.personalInfo.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           !cv.personalInfo.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
           !cv.personalInfo.profile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filledSections += 1
        }
        
        // Skills (weight: 1)
        if !cv.skills.isEmpty {
            filledSections += 1
        }
        
        // Experience (weight: 1)
        if !cv.relevant_experience.isEmpty {
            filledSections += 1
        }
        
        // Education (weight: 1)
        if !cv.education.isEmpty {
            filledSections += 1
        }
        
        // Languages (weight: 1)
        if !cv.languages.isEmpty {
            filledSections += 1
        }
        
        // Certifications (weight: 1)
        if !cv.certifications.isEmpty {
            filledSections += 1
        }
        
        // Social/Interests combined (weight: 1)
        if !cv.social.isEmpty || !cv.interests.isEmpty {
            filledSections += 1
        }
        
        return Double(filledSections) / Double(totalSections)
    }
    
    /// Indicates if there are unsaved changes (for future implementation)
    var hasUnsavedChanges: Bool {
        // For now, assume there are always unsaved changes if meaningful content exists
        // This could be enhanced with a proper dirty tracking system
        hasMeaningfulContent
    }
    
    /// Computed property for save button enabled state
    var isSaveButtonEnabled: Bool {
        hasMeaningfulContent && !isLoading
    }
    
    /// Computed property for save button color
    var saveButtonColor: Color {
        isSaveButtonEnabled ? DesignTokens.Colors.accent : DesignTokens.Colors.disabledButtonForeground
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
    
    deinit {
        cleanup()
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
        // Don't save if no meaningful content
        guard hasMeaningfulContent else {
            return false
        }
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
    func handleSaveButtonTap(onNavigate: @escaping () -> Void) async {
        if await saveCV() {
            showingSaveConfirmation = true
            
            // Auto-dismiss after 2 seconds
            saveSuccessTimer?.invalidate()
            saveSuccessTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.showingSaveConfirmation = false
                    onNavigate()
                }
            }
        }
    }
    
    @MainActor
    func handleCancelButtonTap() -> Bool {
        if hasUnsavedChanges {
            showingCancelConfirmation = true
            return false
        } else {
            cleanup()
            return true
        }
    }
    
    @MainActor
    func confirmCancel() {
        cleanup()
    }
    
    @MainActor
    func dismissSaveConfirmation() {
        saveSuccessTimer?.invalidate()
        showingSaveConfirmation = false
    }
    
    @MainActor
    func finishEditingAndNavigateBack() {
        saveSuccessTimer?.invalidate()
        cleanup()
    }
    
    private func cleanup() {
        saveSuccessTimer?.invalidate()
        saveSuccessTimer = nil
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