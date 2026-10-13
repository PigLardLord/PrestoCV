import SwiftUI
import PrestoCVCore
import Combine

final class CVEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var cv: CVModel = CVModel()
    @Published var viewState: ViewState<CVModel> = .idle
    @Published private(set) var isSaving = false
    @Published var saveError: String?
    @Published var showingSaveConfirmation = false
    @Published var showingCancelConfirmation = false
    @Published private(set) var pendingDeletion: PendingDeletion?
    
    // MARK: - Private Properties
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    private let cvId: String?
    /// The CV as last read from or written to storage; nil until the first load or save.
    private var savedSnapshot: CVModel?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var errorMessage: String {
        saveError ?? ""
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
    
    /// Indicates if there are unsaved changes: a CV that was never stored has them once it holds
    /// meaningful content, a stored one when it differs from what was last stored.
    var hasUnsavedChanges: Bool {
        guard let savedSnapshot else {
            return hasMeaningfulContent
        }
        return cv != savedSnapshot
    }
    
    /// Computed property for save button enabled state
    var isSaveButtonEnabled: Bool {
        hasMeaningfulContent && hasUnsavedChanges && !isSaving
    }
    
    /// Computed property for save button color
    var saveButtonColor: Color {
        isSaveButtonEnabled ? DesignTokens.Colors.accent : DesignTokens.Colors.disabledButtonForeground
    }
    
    /// Computed property for error alert binding
    var isShowingError: Bool {
        saveError != nil
    }
    
    // MARK: - Initialization
    init(
        cvId: String?,
        initialCV: CVModel? = nil,
        cvManagementUseCase: CVManagementUseCaseProtocol
    ) {
        self.cvId = cvId
        self.cvManagementUseCase = cvManagementUseCase

        // For new CVs, initialize with provided template or empty CV
        if cvId == nil {
            self.cv = initialCV ?? CVModel()
            viewState = .loaded(self.cv)
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

        // A CV that is already loaded stays as it is: reading it again would drop the edits made since.
        guard savedSnapshot == nil else { return }
        
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

        // Don't save if there are no changes
        guard hasUnsavedChanges else {
            return false
        }

        // A second save while one is running would store the same new CV twice
        guard !isSaving else {
            return false
        }

        isSaving = true
        saveError = nil
        defer { isSaving = false }

        // The form stays editable while the store works, so what is submitted is not what is on screen when it returns
        let submittedCV = cv

        do {
            let savedCV: CVModel
            if savedSnapshot == nil {
                // Never stored: create it from the submitted data
                savedCV = try await cvManagementUseCase.createCV(from: submittedCV)
            } else {
                // Already stored: update it
                savedCV = try await cvManagementUseCase.updateCV(submittedCV)
            }
            adoptStored(savedCV, submitted: submittedCV)
            return true
        } catch {
            saveError = error.localizedAppErrorDescription
            return false
        }
    }
    
    @MainActor
    func handleSaveButtonTap() async {
        guard await saveCV() else {
            return
        }
        // Edits made while the store worked are not saved yet. Offering Done now would let the user leave without them.
        if !hasUnsavedChanges {
            showingSaveConfirmation = true
        }
    }
    
    /// The question every way out of the editor asks first: Cancel, and Done in the save confirmation.
    /// True when leaving would lose nothing. Otherwise the user is asked what to do, or, while a save is
    /// running, has to wait for it, since it would finish after the editor is gone.
    @MainActor
    func requestLeaving() -> Bool {
        guard !isSaving else {
            return false
        }
        guard hasUnsavedChanges else {
            return true
        }
        showingCancelConfirmation = true
        return false
    }
    
    @MainActor
    func confirmCancel() {
        // No cleanup needed anymore
    }
    
    @MainActor
    func dismissSaveConfirmation() {
        showingSaveConfirmation = false
    }
    
    @MainActor
    func clearError() {
        saveError = nil
    }
    
    @MainActor
    func addSkill() {
        cv.skills.append(Skill(name: ""))
    }
    
    @MainActor
    func removeSkill(at index: Int) {
        removeRow(at: index, from: \.skills)
    }
    
    @MainActor
    func addExperience() {
        cv.relevant_experience.append(Experience())
    }
    
    @MainActor
    func removeExperience(at index: Int) {
        removeRow(at: index, from: \.relevant_experience)
    }
    
    @MainActor
    func addEducation() {
        cv.education.append(Education())
    }
    
    @MainActor
    func removeEducation(at index: Int) {
        removeRow(at: index, from: \.education)
    }
    
    @MainActor
    func addLanguage() {
        cv.languages.append(Language())
    }
    
    @MainActor
    func removeLanguage(at index: Int) {
        removeRow(at: index, from: \.languages)
    }
    
    @MainActor
    func addCertification() {
        cv.certifications.append(Certification())
    }
    
    @MainActor
    func removeCertification(at index: Int) {
        removeRow(at: index, from: \.certifications)
    }
    
    @MainActor
    func addSocial() {
        cv.social.append(Social())
    }
    
    @MainActor
    func removeSocial(at index: Int) {
        removeRow(at: index, from: \.social)
    }
    
    @MainActor
    func addInterest() {
        cv.interests.append("")
    }
    
    @MainActor
    func removeInterest(at index: Int) {
        removeRow(at: index, from: \.interests)
    }

    // MARK: - Deleting Rows

    /// Asks to remove a row. A row the user has put nothing in goes at once; any other waits for
    /// `confirmDeletion`, because nothing can be undone.
    @MainActor
    func requestRemoval(of section: EditorSection, at index: Int) {
        guard let row = row(of: section, at: index) else {
            return
        }
        guard row.isBlank else {
            pendingDeletion = PendingDeletion(section: section, index: index, rowName: row.displayName)
            return
        }
        removeRow(of: section, at: index)
    }

    @MainActor
    func confirmDeletion(_ deletion: PendingDeletion) {
        pendingDeletion = nil
        removeRow(of: deletion.section, at: deletion.index)
    }

    @MainActor
    func cancelDeletion() {
        pendingDeletion = nil
    }

    // MARK: - Private Methods

    /// Records `storedCV` as what is in storage. A form that was not edited during the save takes the stored
    /// values as they are. One that was edited keeps its edits and only adopts the identity of the stored CV,
    /// so those edits still count as unsaved and the next save updates the same CV.
    @MainActor
    private func adoptStored(_ storedCV: CVModel, submitted submittedCV: CVModel) {
        savedSnapshot = storedCV
        if cv == submittedCV {
            cv = storedCV
        } else {
            cv.id = storedCV.id
        }
    }

    @MainActor
    private func loadExistingCV(with uuid: UUID) async throws {
        guard let loadedCV = try await cvManagementUseCase.getCV(by: uuid) else {
            throw AppError.notFound("error.subject.cv".localized)
        }
        cv = loadedCV
        savedSnapshot = loadedCV
    }

    private func row(of section: EditorSection, at index: Int) -> (any EditorRow)? {
        switch section {
        case .skills: return cv.skills[safe: index]
        case .experience: return cv.relevant_experience[safe: index]
        case .education: return cv.education[safe: index]
        case .languages: return cv.languages[safe: index]
        case .certifications: return cv.certifications[safe: index]
        case .social: return cv.social[safe: index]
        case .interests: return cv.interests[safe: index].map(InterestEntry.init)
        }
    }

    @MainActor
    private func removeRow(of section: EditorSection, at index: Int) {
        switch section {
        case .skills: removeSkill(at: index)
        case .experience: removeExperience(at: index)
        case .education: removeEducation(at: index)
        case .languages: removeLanguage(at: index)
        case .certifications: removeCertification(at: index)
        case .social: removeSocial(at: index)
        case .interests: removeInterest(at: index)
        }
    }

    /// Removes the row at `index` if there is one: a list can ask for a row that is already gone.
    @MainActor
    private func removeRow<Row>(at index: Int, from rows: WritableKeyPath<CVModel, [Row]>) {
        guard cv[keyPath: rows].indices.contains(index) else {
            return
        }
        cv[keyPath: rows].remove(at: index)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
