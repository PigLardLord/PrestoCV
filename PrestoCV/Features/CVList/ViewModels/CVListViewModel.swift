import SwiftUI
import PrestoCVCore

@MainActor
final class CVListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var viewState: ViewState<[CVModel]> = .idle
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
    
    // MARK: - Private Properties
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    private let now: () -> Date
    private let waitBetweenTicks: (Duration) async throws -> Void
    private let calendar: () -> Calendar
    /// Counts the reads that were started and the changes that went through. A read publishes what it found only if
    /// nothing was counted since it started: a newer read, and the rows that a change was applied to, win over a
    /// read that began earlier and was overtaken, whenever that one finishes.
    private var readSequence = 0
    /// A change went through and no read of the list has confirmed it yet.
    private var hasUnconfirmedChange = false
    /// The CVs whose document language is being saved.
    private var documentLanguageSaves: Set<UUID> = []
    /// The language last chosen for a CV and not yet being saved; nil is automatic.
    private var pendingDocumentLanguages: [UUID: DocumentLanguage?] = [:]
    
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
    ///   - now: The clock of the app.
    ///   - calendar: What counts as a day when a save is told in days. It is asked for each time a text is made, so
    ///     that a change of the time zone of the device moves the days with it.
    ///   - sleep: How the clock of the list waits between two ticks.
    init(
        cvManagementUseCase: CVManagementUseCaseProtocol,
        now: @escaping () -> Date = { Date() },
        calendar: @escaping () -> Calendar = { .autoupdatingCurrent },
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.cvManagementUseCase = cvManagementUseCase
        self.now = now
        self.waitBetweenTicks = sleep
        self.presentationDate = now()
        self.calendar = calendar
    }
    
    // MARK: - Row Text
    
    /// The person a CV is about, for the line under its name: the name of the person and the job title, or the one
    /// of them that is there. It tells apart CVs that have no name of their own. Nil when the CV has neither.
    func personLine(of cv: CVModel) -> String? {
        let parts = [cv.personalInfo.name, cv.personalInfo.title]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
    
    /// When a CV was last saved, in words, for its row. Nil while that is not known.
    func lastSavedLine(of cv: CVModel) -> String? {
        lastSavedAt[cv.id].map { LastSavedDescription(calendar: calendar()).text(for: $0, relativeTo: presentationDate) }
    }
    
    /// Moves the clock of the list to now, so that the times of the rows are told again. The list calls it when the
    /// app comes back to the foreground, which can be days after the rows were last drawn.
    func refreshPresentationDate() {
        presentationDate = now()
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
        readSequence += 1
        let thisRead = readSequence
        if viewState.data == nil {
            viewState = .loading
        }
        
        do {
            let listing = try await cvManagementUseCase.getCVListing()
            guard thisRead == readSequence else { return }
            show(listing)
        } catch {
            // A read that was overtaken has nothing to report, and neither has one that the screen cancelled
            guard thisRead == readSequence, !(error is CancellationError) else { return }
            report(error)
        }
    }
    
    /// The user has seen the notice about the CVs that could not be opened: record it, so that it goes away.
    func dismissUnreadableNotice() async {
        await perform {
            try await self.cvManagementUseCase.acknowledgeUnreadableCVs()
            return .unreadableCVsAcknowledged
        }
    }
    
    func deleteCV(withId id: UUID) async {
        await perform {
            try await self.cvManagementUseCase.deleteCV(id: id)
            return .removed(id)
        }
    }
    
    func duplicateCV(withId id: UUID) async {
        await perform {
            .added(try await self.cvManagementUseCase.duplicateCV(id: id))
        }
    }
    
    /// Gives a CV a new name. The name is trimmed and an empty one is refused. The CV is read again before it is
    /// saved, so that nothing but its name changes.
    func renameCV(id: UUID, to newName: String) async {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        await perform {
            guard var cv = try await self.cvManagementUseCase.getCV(by: id) else {
                throw AppError.notFound("error.subject.cv".localized)
            }
            cv.name = name
            return .replaced(try await self.cvManagementUseCase.updateCV(cv))
        }
    }

    /// Sets the language of a CV's PDF, as chosen in its export sheet; nil is automatic. The CV is read again before it
    /// is saved, so that nothing but its language changes.
    ///
    /// The saves of one CV run one after the other. A choice made while one is being saved waits, and replaces any
    /// choice still waiting, so that the latest choice is always the one stored last: the language the sheet shows.
    func setDocumentLanguage(_ language: DocumentLanguage?, ofCVWithId id: UUID) async {
        pendingDocumentLanguages.updateValue(language, forKey: id)
        // A save is under way: it saves this choice when it is done
        guard documentLanguageSaves.insert(id).inserted else { return }
        defer { documentLanguageSaves.remove(id) }

        while let wanted = pendingDocumentLanguages.removeValue(forKey: id) {
            await perform {
                guard var cv = try await self.cvManagementUseCase.getCV(by: id) else {
                    throw AppError.notFound("error.subject.cv".localized)
                }
                cv.documentLanguage = wanted?.rawValue
                return .replaced(try await self.cvManagementUseCase.updateCV(cv))
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// What a change that went through did, as far as the list is concerned.
    private enum CommittedChange {
        /// A copy of a CV. The store lists the CV saved last first, so it goes to the top.
        case added(CVModel)
        /// A CV saved with a change, such as a new name, which makes it the one saved last.
        case replaced(CVModel)
        case removed(UUID)
        case unreadableCVsAcknowledged
    }
    
    /// Runs a change of the stored CVs. A change that fails is reported as an action error and leaves the list
    /// alone. One that goes through is shown in the list at once, from what it returned, and the list is then read
    /// again, so that the user sees what happened even when that read fails.
    private func perform(_ change: () async throws -> CommittedChange) async {
        let committed: CommittedChange
        do {
            committed = try await change()
        } catch {
            actionError = error.localizedAppErrorDescription
            return
        }
        apply(committed)
        await loadCVs()
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
