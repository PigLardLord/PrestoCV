import Foundation
import PrestoCVCore
import Combine
import enum PrestoCVDomain.CVTitle

/// The editor of one CV. It runs on the main actor, as its form does: every change of the form is kept on the device
/// a few seconds later, so the change and the keeping happen in order.
@MainActor
final class CVEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var cv: CVModel = CVModel() {
        didSet { formChanged() }
    }
    @Published var viewState: ViewState<CVModel> = .idle
    @Published private(set) var isSaving = false
    @Published var saveError: String?
    /// The short, inline confirmation that the CV was saved. It goes after a few seconds, or at the next edit.
    @Published private(set) var showsSavedConfirmation = false
    @Published var showingCancelConfirmation = false
    @Published private(set) var pendingDeletion: PendingDeletion?
    /// What each contact field said when the person last left it: its check, which typing does not change.
    @Published private(set) var leftContactText: [ContactField: String] = [:]
    /// The message shown above a new CV, set by the screen that opened it.
    let notice: EditorNotice?
    
    /// How long the confirmation of a save stays.
    static let savedConfirmationDuration = Duration.seconds(3)
    
    // MARK: - Private Properties
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    let documentLanguageDetector: DocumentLanguageDetector
    private let cvId: String?
    /// The CV as last read from or written to storage; nil until the first load or save.
    private var savedSnapshot: CVModel?
    /// What the save that is running stores; nil when no save is running.
    private var savingCV: CVModel?
    private var cancellables = Set<AnyCancellable>()
    /// Edits that an earlier run of the app kept and the person chose to restore.
    private let restoredEdits: UnsavedEdits?
    private let unsavedEdits: UnsavedEditsKeeper?
    private let wait: (Duration) async throws -> Void
    private var savedConfirmationTimer: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    var errorMessage: String {
        saveError ?? ""
    }
    
    /// The title of the screen, by the title rule of PrestoCVDomain: the name of the CV, otherwise the name of its
    /// person, otherwise the role it is for. Without any of them, a CV that was never stored is "New CV", and a stored
    /// one "Untitled CV", as the list calls it.
    var screenTitle: String {
        cv.editorTitle(isStored: savedSnapshot != nil)
    }
    
    /// Whether the CV has enough content to be saved, by the save rule of PrestoCVDomain
    var hasMeaningfulContent: Bool {
        cv.allowsSaving
    }
    
    /// Indicates if there are unsaved changes: a CV that was never stored has them once it holds
    /// meaningful content, a stored one when it differs from what was last stored.
    var hasUnsavedChanges: Bool {
        guard let savedSnapshot else {
            return hasMeaningfulContent
        }
        return cv != savedSnapshot
    }
    
    /// What the button that leaves the editor offers: to cancel the edits, or, once the CV is stored and nothing
    /// is unsaved, to be done with it.
    var exit: EditorExit {
        savedSnapshot != nil && !hasUnsavedChanges ? .done : .cancel
    }
    
    /// Whether the CV can be exported: one with nothing in it has nothing to put in a PDF. Unsaved edits are exported
    /// as they are.
    var canExport: Bool {
        hasMeaningfulContent
    }
    
    /// Computed property for save button enabled state
    var isSaveButtonEnabled: Bool {
        hasMeaningfulContent && hasUnsavedChanges && !isSaving
    }
    
    /// Computed property for error alert binding
    var isShowingError: Bool {
        saveError != nil
    }
    
    // MARK: - Initialization
    /// - Parameters:
    ///   - initialCV: What a new CV starts from. The CV gets an id of its own, which its saves store it under.
    ///   - notice: The message shown above a new CV, such as the one that asks to check an AI draft.
    ///   - restoring: Edits an earlier run of the app kept. They are shown over the CV stored under their id once it
    ///     is loaded, or as a new CV when there is none.
    ///   - documentLanguageDetector: Reads which language the CV is written in, for the Automatic document language.
    ///   - unsavedEdits: Keeps what the editor has not saved, so that it outlives the app.
    ///   - sleep: How the editor waits before the confirmation of a save goes.
    init(
        cvId: String?,
        initialCV: CVModel? = nil,
        notice: EditorNotice? = nil,
        restoring restoredEdits: UnsavedEdits? = nil,
        cvManagementUseCase: CVManagementUseCaseProtocol,
        documentLanguageDetector: DocumentLanguageDetector = .onDevice,
        unsavedEdits: UnsavedEditsKeeper? = nil,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.cvId = cvId
        self.notice = notice
        self.cvManagementUseCase = cvManagementUseCase
        self.documentLanguageDetector = documentLanguageDetector
        self.restoredEdits = restoredEdits
        self.unsavedEdits = unsavedEdits
        self.wait = sleep

        // A new CV starts from the template, or empty, with the id its saves store it under from the start
        if cvId == nil, restoredEdits == nil {
            self.cv = (initialCV ?? CVModel()).copy()
            viewState = .loaded(self.cv)
        }
    }
    
    
    // MARK: - Public Methods
    @MainActor
    func loadCV() async {
        if let restoredEdits {
            await loadRestoring(restoredEdits)
            return
        }

        // If no CV ID, we're creating a new CV, so leave the default empty CV
        guard let cvId = cvId,
              let uuid = UUID(uuidString: cvId) else { 
            // For new CVs, set state to loaded with empty CV
            viewState = .loaded(cv)
            return 
        }

        // A CV that is already loaded stays as it is: reading it again would drop the edits made since.
        guard savedSnapshot == nil, viewState.data == nil else { return }
        
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

        // The kept edits say what this save stores before it does: if the app is ended before they are removed,
        // restoring them finds that CV and updates it, instead of storing it a second time
        savingCV = submittedCV
        if await keepUnsavedEdits() == false, keepsOtherEdits(of: submittedCV) {
            // What is kept could not be brought up to date, and holds other edits of this CV: once it is stored, a
            // restore would take them for edits on an older version of it. Removing them could leave nothing of the
            // edits that outlives the app, so nothing is stored, and they stay as they are.
            savingCV = nil
            saveError = "editor.save_error.not_kept".localized
            return false
        }

        do {
            let savedCV: CVModel
            if savedSnapshot == nil {
                // Never stored: store it under the id it got when its editing began
                savedCV = try await cvManagementUseCase.storeNewCV(submittedCV)
            } else {
                // Already stored: update it
                savedCV = try await cvManagementUseCase.updateCV(submittedCV)
            }
            adoptStored(savedCV, submitted: submittedCV)
            savingCV = nil
            await keepUnsavedEdits()
            return true
        } catch {
            saveError = error.localizedAppErrorDescription
            // Nothing was stored: the kept edits go back to the CV they were made on
            savingCV = nil
            await keepUnsavedEdits()
            return false
        }
    }
    
    @MainActor
    func handleSaveButtonTap() async {
        guard await saveCV() else {
            return
        }
        // Edits made while the store worked are not saved yet: saying that the CV is saved would not be true.
        if !hasUnsavedChanges {
            showSavedConfirmation()
        }
    }
    
    /// Keeps what the editor has not saved, at once: the app is leaving the foreground, and iOS may end it.
    /// - Returns: Whether what is kept is what the editor has not saved, or nil when nothing is kept at all.
    @MainActor
    @discardableResult
    func keepUnsavedEdits() async -> Bool? {
        guard viewState.data != nil, let unsavedEdits else { return nil }
        return await unsavedEdits.keepNow(currentUnsavedEdits)
    }
    
    /// The app came to the foreground or left it. On its way to the background the app can be ended by iOS at any
    /// moment: what is not saved is kept now.
    @MainActor
    func sceneDidChange(isActive: Bool) async {
        guard !isActive else { return }
        await keepUnsavedEdits()
    }
    
    /// The question every way out of the editor asks first: Cancel, or Done once everything is saved.
    /// True when leaving would lose nothing. Otherwise the user is asked what to do, or, while a save is
    /// running, has to wait for it, since it would finish after the editor is gone.
    @MainActor
    func requestLeaving() -> Bool {
        guard !isSaving else {
            return false
        }
        guard hasUnsavedChanges else {
            stopKeepingUnsavedEdits()
            return true
        }
        showingCancelConfirmation = true
        return false
    }
    
    /// The edits are discarded: the copy kept on the device goes with them.
    @MainActor
    func confirmCancel() {
        stopKeepingUnsavedEdits()
    }
    
    @MainActor
    func clearError() {
        saveError = nil
    }

    /// The person left a contact field: what it says now is checked, until they leave it again.
    @MainActor
    func fieldWasLeft(_ field: ContactField) {
        let info = cv.personalInfo
        switch field {
        case .email: leftContactText[field] = info.email
        case .phone: leftContactText[field] = info.phone
        case .portfolio: leftContactText[field] = info.portfolio
        }
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

    /// What the editor has not saved, as it is kept on the device, over what is stored, or over what the save that is
    /// running stores; nil when everything is saved.
    private var currentUnsavedEdits: UnsavedEditsKeeper.Edits? {
        hasUnsavedChanges ? UnsavedEditsKeeper.Edits(cv: cv, base: savingCV ?? savedSnapshot) : nil
    }

    /// Whether the edits kept on the device are edits of `cv` other than `cv` itself. Until the keeper has written, what
    /// is kept is what an earlier run kept: the edits the editor restored, or nothing for a new editing.
    private func keepsOtherEdits(of cv: CVModel) -> Bool {
        guard let unsavedEdits else { return false }
        let keptCV: CVModel?
        switch unsavedEdits.written {
        case .some(let written):
            keptCV = written?.cv
        case .none:
            keptCV = restoredEdits?.cv
        }
        guard let keptCV else { return false }
        return keptCV.id == cv.id && keptCV != cv
    }

    /// The form changed: a confirmation of the last save no longer holds, and the edits are kept soon. A form that is
    /// not shown, because the CV is still loading or could not be, has nothing of the person's to keep.
    private func formChanged() {
        if showsSavedConfirmation {
            showsSavedConfirmation = false
        }
        guard viewState.data != nil else { return }
        unsavedEdits?.keepSoon { self.currentUnsavedEdits }
    }


    /// The editor is left: whatever it kept goes, and it keeps nothing more. A form that was never shown leaves
    /// alone what an earlier run kept.
    @MainActor
    private func stopKeepingUnsavedEdits() {
        guard viewState.data != nil, let unsavedEdits else { return }
        Task { await unsavedEdits.close() }
    }

    @MainActor
    private func showSavedConfirmation() {
        showsSavedConfirmation = true
        savedConfirmationTimer?.cancel()
        savedConfirmationTimer = Task {
            do {
                try await wait(Self.savedConfirmationDuration)
            } catch {
                return
            }
            showsSavedConfirmation = false
        }
    }

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

    /// Shows restored edits, as their plan says, once the CVs stored under their id and under the id of their copy are
    /// read, and keeps them at once. A CV that cannot be read leaves them as they are and lets go of them, so that they
    /// are offered again; a retry takes them back, unless another window holds them by then.
    @MainActor
    private func loadRestoring(_ edits: UnsavedEdits) async {
        guard viewState.data == nil else { return }
        if let unsavedEdits, await unsavedEdits.reclaim(edits) == false {
            viewState = .error("unsaved_edits.unavailable.message".localized)
            return
        }
        viewState = .loading
        do {
            let stored = try await cvManagementUseCase.getCV(by: edits.cv.id)
            let storedCopy = try await cvManagementUseCase.getCV(by: edits.copyID)
            switch edits.restorePlan(over: stored, copy: storedCopy) {
            case .restoredAsCopy(let copy):
                // Restored as this copy before: it opens as it is stored, with nothing unsaved, so the edits go
                savedSnapshot = copy
                cv = copy
            case .alreadySaved, .update:
                savedSnapshot = stored
                cv = edits.cv
            case .create:
                // Nothing is stored under the edits' id, never or no longer: a save stores them under it
                cv = edits.cv
            case .copy:
                // The stored CV was saved again after these edits: they become a CV of their own, so nothing newer is
                // replaced. Its id comes from the edits, so restoring them again finds it
                cv = edits.cv.copy(newId: edits.copyID, nameModifier: { _ in Self.recoveredName(of: edits.cv) })
            }
        } catch {
            await unsavedEdits?.release()
            let appError = error as? AppError ?? AppError.unknown(error.localizedDescription)
            viewState = .error(appError.localizedDescription)
            return
        }
        viewState = .loaded(cv)
        await keepUnsavedEdits()
    }

    /// What a copy made of restored edits is called: the title of the CV they were made on, marked as recovered.
    private static func recoveredName(of cv: CVModel) -> String {
        let recovered = "unsaved_edits.recovered_suffix".localized
        return "\(cv.cvTitle.text) \(recovered)"
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

extension CVEditorViewModel: LeavableEditor {}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
