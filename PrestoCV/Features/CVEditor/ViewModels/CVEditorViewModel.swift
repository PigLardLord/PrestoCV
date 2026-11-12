import Foundation
import PrestoCVCore
import Combine
import class PrestoCVApplication.Autosave

/// The editor of one CV. It runs on the main actor, as its form does. What the form shows is stored by itself, a
/// second after the last change and at once when the editor is left or the app leaves the foreground (`Autosave`).
@MainActor
final class CVEditorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var cv: CVModel = CVModel() {
        didSet { formChanged() }
    }
    @Published var viewState: ViewState<CVModel> = .idle
    /// Where the CV stands with the store.
    @Published private(set) var saveStatus: Autosave<CVModel>.Status = .upToDate
    /// What VoiceOver is told about saving, each time there is something to tell.
    @Published private(set) var saveAnnouncement: SaveAnnouncement?
    @Published private(set) var pendingDeletion: PendingDeletion?
    /// The question of the confirmation to delete a row. It stays once the request is gone: the dialog is still on the
    /// screen while it closes, and its title must not go blank.
    private(set) var deletionTitle = ""
    /// What each contact field said when the person last left it: its check, which typing does not change.
    @Published private(set) var leftContactText: [ContactField: String] = [:]
    /// The message shown above the CV: set by the screen that opened a new CV, or the import's, kept with the CV until the
    /// person dismisses it (ADR 0027).
    @Published private(set) var notice: EditorNotice?
    
    // MARK: - Private Properties
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    let documentLanguageDetector: DocumentLanguageDetector
    private let request: EditorRequest
    private let clock: any Clock<Duration>
    /// Returns once the editors that were left have stored what they showed, so that a CV is read as they left it.
    private let awaitLeftEditors: @MainActor () async -> Void
    /// Returns once the changes to a stored CV that are on their way have been stored, so that a CV is read as they left it.
    private let awaitStoredChanges: @MainActor (UUID) async -> Void
    /// Told why a write failed, which the banner does not say.
    private let reportSaveFailure: @MainActor @Sendable (any Error) -> Void
    /// Keeps the import's notice with the CV once the store holds it, until the person dismisses it.
    private let noticeKeeper: EditorNoticeKeeper
    /// Writes the form to the store; nil until the form shows a CV.
    private var autosave: Autosave<CVModel>?
    /// A failure has been announced, and the CV has not been saved since.
    private var failureIsAnnounced = false
    private var announcements = 0
    
    // MARK: - Computed Properties
    
    /// The title of the screen, by the title rule of PrestoCVDomain: the name of the CV, otherwise the name of its
    /// person, otherwise the role it is for. Without any of them, a CV that was never stored is "New CV", and a stored
    /// one "Untitled CV", as the list calls it.
    var screenTitle: String {
        cv.editorTitle(isStored: isStored)
    }

    /// Whether the store holds the CV: it did when the editor opened, or a write has stored it.
    private var isStored: Bool {
        autosave?.isStored ?? false
    }
    
    /// Whether the CV has enough content to be saved, by the save rule of PrestoCVDomain
    var hasMeaningfulContent: Bool {
        cv.allowsSaving
    }
    
    /// Whether the CV can be exported: one with nothing in it has nothing to put in a PDF. Edits are exported as they
    /// are shown.
    var canExport: Bool {
        hasMeaningfulContent
    }
    
    /// Whether the line under the title says that the CV is saved on this device: the store holds it, and no failure
    /// waits for a write to succeed, not even while a retry runs.
    var showsSavedOnDevice: Bool {
        isStored && !saveStatus.hasUnresolvedFailure
    }
    
    /// The line under the title: "Saved on this device" while the store holds the CV and no failure is unresolved;
    /// nothing for a CV not stored yet, or while a failed change waits for a write to succeed.
    var subtitle: String {
        showsSavedOnDevice ? "editor.saved".localized : ""
    }

    /// Whether the store holds what the form shows, so that leaving the editor has nothing to store first. False while a
    /// change waits for its pause, while a write runs, whose end can leave something else in the store, and after a
    /// write failed.
    var storeHoldsWhatTheFormShows: Bool {
        autosave?.storeHoldsTheContent ?? true
    }

    /// Whether the last change could not be saved: it is only in memory until a write succeeds. A retry that runs does
    /// not hide it.
    var showsSaveFailure: Bool {
        saveStatus.hasUnresolvedFailure
    }


    // MARK: - Initialization
    /// - Parameters:
    ///   - request: What the editor opens on. A new CV gets an id of its own, which its writes store it under.
    ///   - documentLanguageDetector: Reads which language the CV is written in, for the Automatic document language.
    ///   - clock: The clock the pause before a write is measured on.
    ///   - awaitLeftEditors: Returns once the editors that were left have stored what they showed. A stored CV is read
    ///     only after it, so that it is read as the editor before left it.
    ///   - awaitStoredChanges: Returns once the changes made to a stored CV outside its editor, a language or a look chosen
    ///     in the list, a rename, have been stored. The CV is read only after them, so that the editor's first save does not
    ///     undo them.
    ///   - noticeStore: Where the import's notice is kept with the CV until the person dismisses it.
    ///   - reportSaveFailure: Told the cause of each write that fails.
    init(
        request: EditorRequest,
        cvManagementUseCase: CVManagementUseCaseProtocol,
        noticeStore: any EditorNoticeStore,
        documentLanguageDetector: DocumentLanguageDetector,
        clock: any Clock<Duration>,
        awaitLeftEditors: @escaping @MainActor () async -> Void,
        awaitStoredChanges: @escaping @MainActor (UUID) async -> Void,
        reportSaveFailure: @escaping @MainActor @Sendable (any Error) -> Void
    ) {
        self.request = request
        self.cvManagementUseCase = cvManagementUseCase
        self.documentLanguageDetector = documentLanguageDetector
        self.clock = clock
        self.awaitLeftEditors = awaitLeftEditors
        self.awaitStoredChanges = awaitStoredChanges
        self.reportSaveFailure = reportSaveFailure

        switch request {
        case .stored:
            self.noticeKeeper = EditorNoticeKeeper(store: noticeStore, notice: nil)
        case .new(let template, let notice):
            self.noticeKeeper = EditorNoticeKeeper(store: noticeStore, notice: notice)
            self.notice = notice
            // A new CV gets an id of its own, and the standard look: never the look of the CV it started from. An AI
            // draft or an imported CV is stored as it is, without waiting for a change; a blank CV or an example once it
            // is changed, so one left untouched leaves nothing behind
            let cv = template.startingAsNewCV()
            begin(showing: cv, unchangedFrom: request.storesAsItIs ? nil : cv, isStored: false)
        }
    }
    
    // MARK: - Public Methods
    @MainActor
    func loadCV() async {
        // A new CV is shown from the start; a CV that is already loaded stays as it is: reading it again would drop
        // the edits made since
        guard case .stored(let cvId) = request, viewState.data == nil else { return }
        guard let uuid = UUID(uuidString: cvId) else {
            viewState = .error(AppError.notFound("error.subject.cv".localized).localizedDescription)
            return
        }

        viewState = .loading
        // An editor that was just left may still be storing this CV, and so may a change made in the list: read it once
        // they have
        await awaitLeftEditors()
        await awaitStoredChanges(uuid)
        do {
            guard let loadedCV = try await cvManagementUseCase.getCV(by: uuid) else {
                throw AppError.notFound("error.subject.cv".localized)
            }
            notice = await noticeKeeper.read(cvWithId: uuid)
            begin(showing: loadedCV, unchangedFrom: loadedCV, isStored: true)
        } catch {
            let appError = error as? AppError ?? AppError.unknown(error.localizedDescription)
            viewState = .error(appError.localizedDescription)
        }
    }
    
    /// Whether the message above the CV offers to dismiss it: the import's does, as it stays with the CV until the person
    /// dismisses it (#452); the AI's reminder goes with the session.
    var noticeIsDismissible: Bool { notice?.isKept == true }

    /// The person dismissed the message above the CV: it goes, and the import's is no longer kept with the CV.
    @MainActor
    func dismissNotice() async {
        notice = nil
        await noticeKeeper.dismiss()
    }

    /// Stores what the form shows at once, if it changed: the app is leaving the foreground, and iOS may end it, or the
    /// editor is being left. Changes made while it writes are stored too.
    /// - Returns: Whether the store holds what the form shows, or there is nothing to store; false when the write
    ///   failed or was cancelled, and the edits are only in the form.
    @MainActor
    @discardableResult
    func saveNow() async -> Bool {
        guard let autosave else { return true }
        do {
            try await autosave.flush()
        } catch {
            // The write was cancelled: it is no failure, and the edits are still only in the form
            return false
        }
        return autosave.storeHoldsTheContent
    }
    
    /// The app came to the foreground or left it. On its way to the background the app can be ended by iOS at any
    /// moment: what the form shows is stored now.
    @MainActor
    func sceneDidChange(isActive: Bool) async {
        guard !isActive else { return }
        await saveNow()
    }
    
    /// Tries again to store the change that could not be saved.
    @MainActor
    func retrySaving() async {
        await saveNow()
    }

    /// Stores what the form shows at once, before the editor is left or another screen takes its place.
    /// - Returns: Whether the store holds what the form shows, or there is nothing to store; false when the write
    ///   failed, and the edits are only in the form.
    @MainActor
    func saveBeforeLeaving() async -> Bool {
        await saveNow()
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
            let deletion = PendingDeletion(section: section, index: index, rowName: row.displayName, rowIdentity: row.identity)
            deletionTitle = deletion.title
            pendingDeletion = deletion
            return
        }
        removeRow(of: section, at: index)
    }

    /// Removes the row that `deletion` asked about, once the person has said yes. An answer to a question that is no
    /// longer the one asked (it was cancelled, answered already, or another took its place) removes nothing, and nor
    /// does one for a place that another row has taken: the rows below a removed row move up into its index.
    @MainActor
    func confirmDeletion(_ deletion: PendingDeletion) {
        guard pendingDeletion == deletion else {
            return
        }
        pendingDeletion = nil
        guard row(of: deletion.section, at: deletion.index)?.identity == deletion.rowIdentity else {
            return
        }
        removeRow(of: deletion.section, at: deletion.index)
    }

    @MainActor
    func cancelDeletion() {
        pendingDeletion = nil
    }

    // MARK: - Private Methods

    /// Shows `cv` in the form, and from then on stores what the form shows as it changes.
    /// - Parameters:
    ///   - baseline: What counts as unchanged: the stored CV, or the template a new one starts from. Nil makes `cv`
    ///     itself the change, as for a draft.
    ///   - isStored: Whether the store holds the CV already.
    private func begin(showing cv: CVModel, unchangedFrom baseline: CVModel?, isStored: Bool) {
        let cvs = cvManagementUseCase
        let keeper = noticeKeeper
        let autosave = Autosave(
            content: cv,
            unchangedFrom: baseline,
            isStored: isStored,
            isWorthStoring: { $0.allowsSaving },
            clock: clock,
            onWriteFailure: reportSaveFailure,
            // The write needs nothing of this editor, so that one that ends after the editor is gone still stores the CV
            write: { cv, isStored in
                if isStored {
                    _ = try await cvs.updateCV(cv)
                } else {
                    _ = try await cvs.storeNewCV(cv)
                    await keeper.cvIsStored(withId: cv.id)
                }
            }
        )
        autosave.onStatusChange = { [weak self] status in self?.saveStatusChanged(to: status) }
        self.autosave = autosave
        self.cv = cv
        viewState = .loaded(cv)
    }

    /// Keeps the status the screen shows, and tells VoiceOver what it should hear: that a change could not be saved, each
    /// time a write fails, and that the CV is saved once a write has succeeded after a failure. Nothing is said when a
    /// retry starts, or when a CV that never failed is saved.
    private func saveStatusChanged(to status: Autosave<CVModel>.Status) {
        saveStatus = status
        switch status {
        case .failed:
            failureIsAnnounced = true
            announce(.failed)
        case .upToDate where failureIsAnnounced:
            failureIsAnnounced = false
            announce(.saved)
        case .upToDate, .pending, .writing, .retrying:
            break
        }
    }

    private func announce(_ kind: SaveAnnouncement.Kind) {
        announcements += 1
        saveAnnouncement = SaveAnnouncement(kind: kind, sequence: announcements)
    }

    /// The form changed: it is stored once the pause after the last change has passed. A form that is not shown,
    /// because the CV is still loading or could not be, has nothing of the person's to store.
    private func formChanged() {
        autosave?.changed(to: cv)
    }

    private func row(of section: EditorSection, at index: Int) -> (any EditorRow)? {
        switch section {
        case .skills: return cv.skills[safe: index]
        case .experience: return cv.relevant_experience[safe: index]
        case .education: return cv.education[safe: index]
        case .languages: return cv.languages[safe: index]
        case .certifications: return cv.certifications[safe: index]
        case .social: return cv.social[safe: index]
        case .interests: return interestEntry(at: index)
        }
    }

    /// The interest at `index`, with the number of interests that say the same: a list can hold one text twice.
    private func interestEntry(at index: Int) -> InterestEntry? {
        guard let text = cv.interests[safe: index] else { return nil }
        return InterestEntry(text: text, copies: cv.interests.filter { $0 == text }.count)
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
