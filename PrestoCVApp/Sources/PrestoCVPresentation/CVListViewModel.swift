import Foundation
import Observation
internal import PrestoCVApplication
internal import PrestoCVDomain
import PrestoCVWorkflowPorts

/// The list of CVs, with the store's issues, and what the person does to a row: rename, duplicate, delete, the language of
/// the document. It presents; the title rule and the revision checks are the domain's and the store's (R6).
@MainActor
@Observable
public final class CVListViewModel {

    /// The CVs, most recent first, as the store listed them.
    public private(set) var rows: [CVRow] = []
    public private(set) var status: ListStatus = .loading
    /// A change succeeded and the list could not be read again: the rows may be out of date.
    public private(set) var isStale = false
    /// What the last change of a row did not do. A row is cleared by its next change.
    public private(set) var rowStatuses: [CVReference: RowStatus] = [:]
    /// The moment the view words "saved ... ago" from. It moves when the list is read or `refreshNow()` is called.
    public private(set) var now: Date

    /// The files the store could not read, until the person dismisses the notice (for this launch).
    public var notice: StoreNotice? { isNoticeDismissed || issues.isEmpty ? nil : StoreNotice(kinds: issues) }

    private var issues: [StoreIssueKind] = []
    private var isNoticeDismissed = false

    @ObservationIgnored private let browsing: any CVBrowsing
    @ObservationIgnored private let editing: any CVEditing
    @ObservationIgnored private let untitled: String
    @ObservationIgnored private let numbered: @MainActor (String, Int) -> String
    @ObservationIgnored private let clock: @MainActor () -> Date
    @ObservationIgnored private let editorsStored: @MainActor () async -> Void
    /// The CVs as the store listed them. A change reads its CV here, when the intent comes.
    @ObservationIgnored private var listed: [CV] = []
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var changedSinceLoad = false
    /// The latest change taken on each row. A change publishes its status and its result only while it is the latest.
    @ObservationIgnored private var intents: [CVReference: Int] = [:]

    /// - Parameters:
    ///   - untitled: The view's words for a CV with no title, as "Untitled CV" (R13).
    ///   - numbered: How the view numbers a title that reads like another row's, as "Backend (2)" (R13).
    ///   - now: The time the view words "saved ... ago" from.
    ///   - editorsStored: Returns when the editors that were left have stored what they showed; the store is read after.
    public init(
        browsing: any CVBrowsing, editing: any CVEditing, untitled: String,
        numbered: @escaping @MainActor (String, Int) -> String, now: @escaping @MainActor () -> Date,
        editorsStored: @escaping @MainActor () async -> Void
    ) {
        self.untitled = untitled
        self.numbered = numbered
        self.browsing = browsing
        self.editing = editing
        self.clock = now
        self.editorsStored = editorsStored
        self.now = now()
    }

    // MARK: - Reading

    /// Reads the store. The view calls it from its `.task`, and after anything that may have changed the store.
    public func load() async {
        await editorsStored()
        generation += 1
        let mine = generation
        if rows.isEmpty { status = .loading }
        do {
            let listing = try await browsing.list()
            guard mine == generation else { return }
            show(listing)
        } catch {
            guard mine == generation, !Task.isCancelled else { return }
            status = .failed
            isStale = changedSinceLoad
        }
    }

    public func refreshNow() { now = clock() }

    public func dismissNotice() { isNoticeDismissed = true }

    private func show(_ listing: CVListing) {
        listed = listing.cvs
        issues = listing.issues.map(StoreIssueKind.init)
        showRows()
        let present = Set(rows.map(\.reference))
        rowStatuses = rowStatuses.filter { present.contains($0.key) }
        status = .loaded
        isStale = false
        changedSinceLoad = false
        now = clock()
    }

    // MARK: - Rows

    private func showRows() {
        let titles = listed.map { (id: $0.id.raw.uuidString, title: Self.title(of: $0)) }
        let labels = CVTitle.labels(for: titles, untitled: untitled, numbered: numbered)
        rows = listed.map { cv in
            CVRow(
                reference: CVReference(id: cv.id), label: labels[cv.id.raw.uuidString] ?? untitled,
                subtitle: CVSubtitle.text(name: cv.title, person: cv.personal.fullName, role: cv.personal.professionalTitle) ?? "",
                lastSaved: cv.updatedAt ?? cv.createdAt, language: cv.language?.tag
            )
        }
    }

    private static func title(of cv: CV) -> CVTitle {
        CVTitle(name: cv.title, person: cv.personal.fullName, role: cv.personal.professionalTitle)
    }

    // MARK: - Changes

    /// Renames the CV of the row; the store trims the title and keeps it to one line.
    public func rename(_ reference: CVReference, to title: String) async {
        guard let cv = cv(of: reference) else { return }
        let intent = begin(reference)
        do {
            let renamed = try await editing.rename(cv, to: title)
            if isLatest(intent, on: reference) { replace(renamed) }
            await changed(reference, intent)
        } catch {
            await failed(error, on: reference, intent)
        }
    }

    /// Adds a copy of the CV of the row, under the title the view gives (R13).
    public func duplicate(_ reference: CVReference, title: String) async {
        guard let cv = cv(of: reference) else { return }
        let intent = begin(reference)
        do {
            // The copy is a row of its own: a newer change of this row does not supersede it
            let copy = try await editing.duplicate(cv, title: title)
            listed.insert(copy, at: 0)
            showRows()
            await changed(reference, intent)
        } catch {
            await failed(error, on: reference, intent)
        }
    }

    /// Deletes the CV of the row at the revision the list read; a CV saved elsewhere since is a conflict, and stays.
    public func delete(_ reference: CVReference) async {
        guard let cv = cv(of: reference) else { return }
        let intent = begin(reference)
        do {
            // The CV is gone from the store whatever came after: the row goes
            try await editing.delete(cv)
            listed.removeAll { $0.id == cv.id }
            showRows()
            await changed(reference, intent)
        } catch {
            await failed(error, on: reference, intent)
        }
    }

    /// Sets the language the document of the row is written in, by its tag; nil leaves it automatic. A tag that names no
    /// language changes nothing.
    public func setDocumentLanguage(_ reference: CVReference, to tag: String?) async {
        let language = tag.flatMap(DocumentLanguage.init)
        guard let cv = cv(of: reference), tag == nil || language != nil else { return }
        let intent = begin(reference)
        do {
            let changedCV = try await editing.autosaveWriter(startingFrom: cv).setDocumentLanguage(language, of: cv)
            if isLatest(intent, on: reference) { replace(changedCV) }
            await changed(reference, intent)
        } catch is CancellationError {
            return
        } catch {
            await failed(error as? EditFailure ?? .unavailable, on: reference, intent)
        }
    }

    private func begin(_ reference: CVReference) -> Int {
        let intent = (intents[reference] ?? 0) + 1
        intents[reference] = intent
        return intent
    }

    private func isLatest(_ intent: Int, on reference: CVReference) -> Bool { intents[reference] == intent }

    private func cv(of reference: CVReference) -> CV? { listed.first { $0.id == reference.id } }

    private func replace(_ cv: CV) {
        guard let index = listed.firstIndex(where: { $0.id == cv.id }) else { return }
        listed[index] = cv
        showRows()
    }

    /// A change worked: the list is read again, as the store may hold more than this change. The row's status is cleared
    /// only if no newer change of the row was taken.
    private func changed(_ reference: CVReference, _ intent: Int) async {
        if isLatest(intent, on: reference) { rowStatuses[reference] = nil }
        changedSinceLoad = true
        await load()
    }

    /// A change did not work. A cancelled task is no failure. What the list shows is out of date after a conflict or a CV
    /// that is gone, so it is read again; the row shows the failure only if no newer change of the row was taken.
    private func failed(_ failure: EditFailure, on reference: CVReference, _ intent: Int) async {
        guard !Task.isCancelled else { return }
        let rowStatus = RowStatus(failure)
        if isLatest(intent, on: reference) { rowStatuses[reference] = rowStatus }
        switch rowStatus {
        case .conflict, .gone: await load()
        case .tooLarge, .failed: break
        }
    }
}
