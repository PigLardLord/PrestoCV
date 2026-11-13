import Combine
import Foundation
import PrestoCVCore
import struct PrestoCVApplication.ChangeStoredCV
import enum PrestoCVDomain.CVTitle
import struct PrestoCVApplication.LookChange
import enum PrestoCVApplication.StoredCVChangeError
import os

private let listLogger = Logger(subsystem: "com.PigLardLord.prestocv", category: "list")

@MainActor
final class CVListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var viewState: ViewState<[CVModel]> = .idle {
        didSet { rowLabels = Self.rowLabels(of: cvs) }
    }
    @Published private(set) var unreadableCount = 0
    /// When each CV of the list was last saved, for the CVs that are known to have a time.
    @Published private(set) var lastSavedAt: [UUID: Date] = [:]
    /// The moment the times of the rows are told relative to. It is the clock of the list: it moves when the list
    /// is read, once a minute while the list is shown, and when the app comes back to the foreground.
    @Published private(set) var presentationDate: Date
    /// Why the last action on a CV failed. It is shown on top of the list, which stays as it was.
    @Published var actionError: String?
    /// True when a change went through but the list could not be read again afterwards, so that the rows shown
    /// are what the app knows of the change, not what was read from storage.
    @Published private(set) var isListStale = false
    
    /// How often the times of the rows are told again while the list is shown: they are given in minutes at best.
    static let tickInterval = Duration.seconds(60)
    /// How long nothing must be chosen in an export sheet before what was chosen is stored: a design, a palette and a font
    /// tried in turn make one save, and one change of the CV's time, as they make one preview in the sheet.
    static let choicePause = CVExportSheetViewModel.selectionInterval
    
    // MARK: - Private Properties
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    private let storedCVChanges: ChangeStoredCV<CVModel>
    /// The changes to the stored CVs, one CV at a time, which the editors wait for.
    private let changeQueue: StoredCVChangeQueue
    /// The notices of the imported CVs: a deleted CV's goes with it.
    private let noticeStore: any EditorNoticeStore
    private let locale: Locale
    private let now: () -> Date
    private let waitBetweenTicks: (Duration) async throws -> Void
    private let calendar: () -> Calendar
    /// Returns once the editors that were left have stored what they showed.
    private let awaitLeftEditors: @MainActor () async -> Void
    /// Counts the reads that were started and the changes that went through. A read publishes what it found only if
    /// nothing was counted since it started: a newer read, and the rows that a change was applied to, win over a
    /// read that began earlier and was overtaken, whenever that one finishes.
    private var readSequence = 0
    /// A change went through and no read of the list has confirmed it yet.
    private var hasUnconfirmedChange = false
    /// The CVs with a save of the choices made in their export sheet, queued or under way. One save runs for each of them,
    /// and it stores every choice made until it has nothing left to store.
    private var savingChoices: Set<UUID> = []
    /// What was chosen for a CV in its export sheet and no save has taken yet: the language and the look, the latest choice
    /// of each. It is there from the moment of the choice, before anything is stored.
    private var waitingChoices: [UUID: ExportChoices] = [:]
    /// What the save under way for a CV is storing. The row of the CV shows it once the save has gone through.
    private var storingChoices: [UUID: ExportChoices] = [:]
    /// For each CV that a choice was made for lately, the wait until `choicePause` has passed with no other choice: the
    /// choices are stored when it ends. A new choice replaces it with a later one, and `storeChoicesNow()` ends it.
    private var quietPeriods: [UUID: Task<Void, Never>] = [:]
    private let clock: any Clock<Duration>
    /// The label of each row, by identity, made once each time the list changes rather than each time a row is drawn.
    /// The words in it change only with the app's language, and iOS starts the app again for that.
    private var rowLabels: [String: String] = [:]
    
    // MARK: - Computed Properties
    var cvs: [CVModel] {
        viewState.data ?? []
    }
    
    var isLoading: Bool {
        viewState.isLoading
    }
    
    var errorMessage: String {
        viewState.errorMessage ?? ""
    }
    
    /// Tells the user that some stored CVs could not be opened; nil when every stored CV was.
    var unreadableNotice: String? {
        guard unreadableCount > 0 else { return nil }
        return String(localized: "cv.list.unreadable_notice \(unreadableCount)")
    }
    
    /// Tells the user that a change was saved but the list could not be refreshed; nil when the list is up to date.
    var staleNotice: String? {
        isListStale ? "cv.list.stale_notice".localized : nil
    }
    
    // MARK: - Initialization
    /// - Parameters:
    ///   - storedCVChanges: Renames a stored CV, or sets the language or the look of its PDF.
    ///   - changeQueue: Where the changes to a stored CV wait for the ones before them for the same CV; the editor of the CV
    ///     waits there too.
    ///   - noticeStore: Where the notice of an imported CV is kept until the person dismisses it; a deleted CV's goes with
    ///     it.
    ///   - locale: The language of the words that say when a CV was saved: the language of the app.
    ///   - now: The clock of the app.
    ///   - calendar: What counts as a day when a save is told in days. It is asked for each time a text is made, so
    ///     that a change of the time zone of the device moves the days with it.
    ///   - sleep: How the clock of the list waits between two ticks.
    ///   - clock: The clock the pause before the choices made in an export sheet are stored is measured on.
    ///   - awaitLeftEditors: Returns once the editors that were left have stored what they showed. The store is read only
    ///     after it, so that a CV just edited is listed as the editor left it.
    init(
        cvManagementUseCase: CVManagementUseCaseProtocol,
        storedCVChanges: ChangeStoredCV<CVModel>,
        changeQueue: StoredCVChangeQueue,
        noticeStore: any EditorNoticeStore,
        locale: Locale,
        now: @escaping () -> Date,
        calendar: @escaping () -> Calendar,
        sleep: @escaping (Duration) async throws -> Void,
        clock: any Clock<Duration>,
        awaitLeftEditors: @escaping @MainActor () async -> Void
    ) {
        self.awaitLeftEditors = awaitLeftEditors
        self.cvManagementUseCase = cvManagementUseCase
        self.storedCVChanges = storedCVChanges
        self.changeQueue = changeQueue
        self.noticeStore = noticeStore
        self.locale = locale
        self.now = now
        self.waitBetweenTicks = sleep
        self.clock = clock
        self.presentationDate = now()
        self.calendar = calendar
    }
    
    // MARK: - Row Text
    
    /// What the list calls a CV, by the title rule of PrestoCVDomain: its name, otherwise the name of its person,
    /// otherwise the role it is for, and "Untitled CV" only without any of them. A CV whose title reads like another's
    /// in the list is numbered, with a number that gives a label no other row shows.
    func title(of cv: CVModel) -> String {
        rowLabels[cv.id.uuidString] ?? cv.cvTitle.text
    }

    private static func rowLabels(of cvs: [CVModel]) -> [String: String] {
        CVTitle.labels(
            for: cvs.map { (id: $0.id.uuidString, title: $0.cvTitle) },
            untitled: "cv.untitled".localized,
            numbered: { "cv.title.numbered".localizedWithArgs($0, $1) }
        )
    }
    
    /// The line under the title of a CV's row, by the rule of PrestoCVDomain: who the CV is about, without what its
    /// title already says. Nil when nothing is left to say.
    func subtitle(of cv: CVModel) -> String? {
        cv.rowSubtitle
    }
    
    /// When a CV was last saved, in words, for its row. Nil while that is not known.
    func lastSavedLine(of cv: CVModel) -> String? {
        lastSavedAt[cv.id].map { LastSavedDescription(locale: locale, calendar: calendar()).text(for: $0, relativeTo: presentationDate) }
    }
    
    /// Moves the clock of the list to now, so that the times of the rows are told again. The list calls it when the
    /// app comes back to the foreground, which can be days after the rows were last drawn.
    func refreshPresentationDate() {
        presentationDate = now()
    }
    
    /// The app came to the foreground or left it. Back in the foreground, which can be days after the rows were last
    /// drawn, the times of the rows are told again. On its way out, what was chosen in an export sheet is stored without
    /// waiting for the pause.
    func sceneDidChange(isActive: Bool) {
        if isActive {
            refreshPresentationDate()
        } else {
            storeChoicesNow()
        }
    }
    
    /// Keeps the clock of the list current, one tick a minute, until the task that runs it is cancelled.
    func keepPresentationDateCurrent() async {
        while !Task.isCancelled {
            do {
                try await waitBetweenTicks(Self.tickInterval)
            } catch {
                return
            }
            refreshPresentationDate()
        }
    }
    
    // MARK: - Public Methods
    
    /// Reads the stored CVs. The task of the screen, a pull to refresh and the retry of the notice can overlap with
    /// each other and with a change, so only the newest read publishes its result. A list that is already on
    /// screen is not replaced by a spinner while it is read again, and it is not replaced by an error when reading
    /// fails: the full-screen error is for a list that was never shown. A failure is then reported as an action
    /// error, or, once a change has gone through that no read has confirmed yet, by the notice that the list is
    /// stale. A successful read makes the list up to date.
    func loadCVs() async {
        // The editor just left may still be storing its CV: a list read before that would miss it, or show it as it was
        await awaitLeftEditors()
        readSequence += 1
        let thisRead = readSequence
        if viewState.data == nil {
            viewState = .loading
        }
        
        do {
            let listing = try await cvManagementUseCase.getCVListing()
            guard thisRead == readSequence else { return }
            show(listing)
            await forgetNoticesOfDeletedCVs()
        } catch {
            // A read that was overtaken has nothing to report, and neither has one that the screen cancelled
            guard thisRead == readSequence, !(error is CancellationError) else { return }
            report(error)
        }
    }
    
    /// Forgets the notices kept for CVs that are gone: a CV deleted while its notice could not be forgotten, or before a crash
    /// let it be, leaves no text of the person's behind. A CV that cannot be read is still stored, and keeps its notice.
    private func forgetNoticesOfDeletedCVs() async {
        for id in await noticeStore.keptCVIds() {
            do {
                guard try await cvManagementUseCase.getCV(by: id) == nil else { continue }
            } catch {
                listLogger.error("A CV with a kept import notice could not be read; its notice stays: \(error.localizedDescription, privacy: .private)")
                continue
            }
            await noticeStore.forget(cvWithId: id)
        }
    }

    /// The user has seen the notice about the CVs that could not be opened: record it, so that it goes away.
    func dismissUnreadableNotice() async {
        await perform {
            try await self.cvManagementUseCase.acknowledgeUnreadableCVs()
            return .unreadableCVsAcknowledged
        }
    }
    
    /// Deletes a CV, and the notice of its import with it.
    func deleteCV(withId id: UUID) async {
        await changeQueue.enqueue(id) { [self] in
            await perform {
                try await self.cvManagementUseCase.deleteCV(id: id)
                await self.noticeStore.forget(cvWithId: id)
                return .removed(id)
            }
        }.value
    }
    
    /// Stores a copy of a CV, named after the title it has when the copy is made, as "Lena Hartmann (Copy)". The title is
    /// read from the stored CV, once the changes ahead of this one for the CV have ended and the editors that were left have
    /// stored theirs: a row of the list can be a rename behind.
    func duplicateCV(withId id: UUID) async {
        await changeQueue.enqueue(id) { [self] in
            await perform {
                guard let stored = try await self.cvManagementUseCase.getCV(by: id) else { throw StoredCVChangeError.notFound }
                return .added(try await self.cvManagementUseCase.duplicateCV(id: id, named: stored.copyName))
            }
        }.value
    }
    
    /// Gives a CV a new name, as `ChangeStoredCV` does: trimmed, never blank, and nothing but the name changes.
    func renameCV(id: UUID, to newName: String) async {
        await changeQueue.enqueue(id) { [self] in
            await perform {
                try await self.storedCVChanges.rename(id, to: newName).map(CommittedChange.replaced)
            }
        }.value
    }

    // MARK: - Choices Made in an Export Sheet

    /// Sets the language of a CV's PDF, as chosen in its export sheet; nil is automatic.
    ///
    /// The choice is registered at once, and stored once the pause has passed with nothing else chosen
    /// (`storeChoicesNow()` ends the wait): in line with every other change to the CV (`StoredCVChangeQueue`), one after
    /// the other, each reading the CV as the one before left it. A choice made while another is being stored waits, and
    /// replaces any choice of its kind still waiting, so that the latest choice is always the one stored last: the
    /// language the sheet shows.
    /// - Returns: The save that stores it, for a caller that wants to wait for it; nil when a save under way will store it.
    @discardableResult
    func chooseDocumentLanguage(_ language: DocumentLanguage?, ofCVWithId id: UUID) -> Task<Void, Never>? {
        choose(ExportChoices(documentLanguage: .init(value: language)), ofCVWithId: id)
    }

    /// Changes the design, palette or font a CV's PDF is made with, as chosen in its export sheet: only the parts the
    /// person chose. Registered and stored like the language, in the same line and in the same save: a design, a palette and
    /// a font chosen one after the other are stored together, the latest choice of each, with one write and one read of
    /// the list. The look the sheet showed is what a sheet opened again starts from (`currentCV(withId:)`).
    /// - Returns: The save that stores it, for a caller that wants to wait for it; nil when a save under way will store it.
    @discardableResult
    func chooseLook(_ change: LookChange, ofCVWithId id: UUID) -> Task<Void, Never>? {
        choose(ExportChoices(look: change), ofCVWithId: id)
    }

    /// Stores what was chosen in the export sheets now, without waiting for the pause to end: a sheet was closed, or the
    /// app is leaving the foreground.
    func storeChoicesNow() {
        let ending = quietPeriods
        quietPeriods = [:]
        ending.values.forEach { $0.cancel() }
    }

    /// The CV a screen that makes output from it starts from, the export sheet: the CV as the store holds it now, with the
    /// choices made in an export sheet that the store does not hold yet.
    ///
    /// It is read from the store, once the editors that were left have stored what they showed, and never taken from the
    /// row: a row is a read behind for as long as the list is reading again, and for good when that read failed, and a sheet
    /// made from it would show, and make the PDF from, a look or a language that an editor has changed since. The choices
    /// that wait for their pause or are being written are not in the store yet: they are added on top, as they were when the
    /// CV was asked for, so that a sheet opened again shows them and what the person chooses next is added to them. The
    /// change queue is not waited for, since a write that is held would hold the sheet back with it.
    /// - Returns: Nil when the CV cannot be read, which is reported as an action error: the person is told, and no sheet
    ///   is made from a row that may be out of date. Nil without an error when the read was cancelled.
    func currentCV(withId id: UUID) async -> CVModel? {
        let notStored = pendingChoices(ofCVWithId: id)
        await awaitLeftEditors()
        do {
            guard let stored = try await cvManagementUseCase.getCV(by: id) else {
                actionError = Self.message(for: StoredCVChangeError.notFound)
                return nil
            }
            return notStored.applied(to: stored)
        } catch is CancellationError {
            return nil
        } catch {
            actionError = Self.message(for: error)
            return nil
        }
    }

    // MARK: - Private Methods

    /// What was chosen for a CV in an export sheet and the store does not hold yet: what the save under way is writing and,
    /// after it, what waits for the pause to end.
    private func pendingChoices(ofCVWithId id: UUID) -> ExportChoices {
        (storingChoices[id] ?? ExportChoices()).followed(by: waitingChoices[id] ?? ExportChoices())
    }

    /// Registers a choice, restarts the pause before the choices are stored, and queues the save unless one is queued or
    /// running: that one stores every choice made until it ends, so a caller that finds it returns at once.
    private func choose(_ choice: ExportChoices, ofCVWithId id: UUID) -> Task<Void, Never>? {
        waitingChoices[id] = (waitingChoices[id] ?? ExportChoices()).followed(by: choice)
        startQuietPeriod(ofCVWithId: id)
        guard savingChoices.insert(id).inserted else { return nil }
        return changeQueue.enqueue(id) { [self] in
            await saveChoices(ofCVWithId: id)
        }
    }

    /// The pause starts now, in place of the one a choice before it started. It ends at a moment fixed here, on the clock's
    /// own instants, however late the wait for it begins.
    private func startQuietPeriod(ofCVWithId id: UUID) {
        quietPeriods[id]?.cancel()
        let clock = self.clock
        let wait = Self.beginPause(Self.choicePause, on: clock)
        quietPeriods[id] = Task { try? await wait() }
    }

    private static func beginPause<C: Clock<Duration>>(_ length: Duration, on clock: C) -> @Sendable () async throws -> Void {
        let end = clock.now.advanced(by: length)
        return { try await clock.sleep(until: end, tolerance: nil) }
    }

    /// Stores what was chosen for a CV, once nothing has been chosen for the length of the pause and then one kind of
    /// choice at a time, until nothing is left. The row of the CV shows what was stored, and it is read again, for each.
    private func saveChoices(ofCVWithId id: UUID) async {
        while true {
            if let quiet = quietPeriods[id] {
                await quiet.value
                // A choice made meanwhile has put a later pause in its place, which is waited for in turn
                if quietPeriods[id] == quiet {
                    quietPeriods[id] = nil
                }
            } else if let choices = waitingChoices.removeValue(forKey: id) {
                storingChoices[id] = choices
                if let language = choices.documentLanguage {
                    await perform {
                        .replaced(try await self.storedCVChanges.setDocumentLanguage(language.value?.rawValue, of: id))
                    }
                }
                if let look = choices.look {
                    await perform {
                        try await self.storedCVChanges.setLook(look, of: id).map(CommittedChange.replaced)
                    }
                }
                storingChoices[id] = nil
            } else {
                // Nothing left, and nothing can be chosen between this check and the end of the save: it ends here
                savingChoices.remove(id)
                return
            }
        }
    }
    
    /// What a change that went through did, as far as the list is concerned.
    private enum CommittedChange {
        /// A copy of a CV. The store lists the CV saved last first, so it goes to the top.
        case added(CVModel)
        /// A CV saved with a change, such as a new name, which makes it the one saved last.
        case replaced(CVModel)
        case removed(UUID)
        case unreadableCVsAcknowledged
    }
    
    /// Runs a change of the stored CVs, once the editors that were left have stored what they showed, so that the change
    /// is made on that and does not undo it. A change that fails is reported as an action error and leaves the list
    /// alone, and so does one that changed nothing (nil). One that goes through is shown in the list at once, from what it
    /// returned, and the list is then read again, so that the user sees what happened even when that read fails.
    private func perform(_ change: () async throws -> CommittedChange?) async {
        guard let committed = await commit(change) else { return }
        await present(committed)
    }

    /// Runs a change of the stored CVs. Nil when it failed, which is reported, or when it changed nothing.
    private func commit(_ change: () async throws -> CommittedChange?) async -> CommittedChange? {
        await awaitLeftEditors()
        do {
            return try await change()
        } catch {
            actionError = Self.message(for: error)
            return nil
        }
    }

    /// Shows a change that went through, and reads the list again.
    private func present(_ committed: CommittedChange) async {
        apply(committed)
        await loadCVs()
    }
    
    /// Why a change failed, in words. A CV deleted meanwhile is not found, as the store says of one it has not got.
    private static func message(for error: Error) -> String {
        guard error as? StoredCVChangeError == .notFound else {
            return error.localizedAppErrorDescription
        }
        return AppError.notFound("error.subject.cv".localized).localizedDescription
    }
    
    private func apply(_ change: CommittedChange) {
        // What a read that started before this change found may be older than the change
        readSequence += 1
        hasUnconfirmedChange = true
        refreshPresentationDate()
        
        guard var shownCVs = viewState.data else { return }
        switch change {
        case .added(let cv):
            shownCVs.insert(cv, at: 0)
            lastSavedAt[cv.id] = now()
        case .replaced(let cv):
            shownCVs.removeAll { $0.id == cv.id }
            shownCVs.insert(cv, at: 0)
            lastSavedAt[cv.id] = now()
        case .removed(let id):
            shownCVs.removeAll { $0.id == id }
            lastSavedAt[id] = nil
        case .unreadableCVsAcknowledged:
            unreadableCount = 0
        }
        viewState = .loaded(shownCVs)
    }
    
    private func report(_ error: Error) {
        guard viewState.data != nil else {
            unreadableCount = 0
            viewState = .error(error.localizedAppErrorDescription)
            return
        }
        if hasUnconfirmedChange || isListStale {
            isListStale = true
        } else {
            actionError = error.localizedAppErrorDescription
        }
    }
    
    private func show(_ listing: CVListing) {
        unreadableCount = listing.unreadableCount
        lastSavedAt = listing.lastSavedAt
        refreshPresentationDate()
        hasUnconfirmedChange = false
        isListStale = false
        viewState = .loaded(listing.cvs)
    }
}
