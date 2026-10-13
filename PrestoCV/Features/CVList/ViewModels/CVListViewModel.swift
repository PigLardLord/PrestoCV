import SwiftUI
import PrestoCVCore

@MainActor
final class CVListViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var viewState: ViewState<[CVModel]> = .idle
    @Published private(set) var unreadableCount = 0
    /// Why the last action on a CV failed. It is shown on top of the list, which stays as it was.
    @Published var actionError: String?
    /// True when a change went through but the list could not be read again afterwards, so that the rows shown
    /// are what the app knows of the change, not what was read from storage.
    @Published private(set) var isListStale = false
    
    // MARK: - Private Properties
    private let cvManagementUseCase: CVManagementUseCaseProtocol
    /// Counts the reads that were started and the changes that went through. A read publishes what it found only if
    /// nothing was counted since it started: a newer read, and the rows that a change was applied to, win over a
    /// read that began earlier and was overtaken, whenever that one finishes.
    private var readSequence = 0
    /// A change went through and no read of the list has confirmed it yet.
    private var hasUnconfirmedChange = false
    
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
    init(cvManagementUseCase: CVManagementUseCaseProtocol) {
        self.cvManagementUseCase = cvManagementUseCase
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
    
    // MARK: - Private Methods
    
    /// What a change that went through did, as far as the list is concerned.
    private enum CommittedChange {
        /// A copy of a CV. The store lists the CV saved last first, so it goes to the top.
        case added(CVModel)
        /// A CV saved under a new name, which makes it the one saved last.
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
        
        guard var shownCVs = viewState.data else { return }
        switch change {
        case .added(let cv):
            shownCVs.insert(cv, at: 0)
        case .replaced(let cv):
            shownCVs.removeAll { $0.id == cv.id }
            shownCVs.insert(cv, at: 0)
        case .removed(let id):
            shownCVs.removeAll { $0.id == id }
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
        hasUnconfirmedChange = false
        isListStale = false
        viewState = .loaded(listing.cvs)
    }
}
