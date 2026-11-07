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
    @ObservationIgnored private let clock: @MainActor () -> Date
    @ObservationIgnored private let editorsStored: @MainActor () async -> Void
    /// The CVs as the store listed them. A change reads its CV here, when the intent comes.
    @ObservationIgnored private var listed: [CV] = []
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var changedSinceLoad = false

    /// - Parameters:
    ///   - now: The time the view words "saved ... ago" from.
    ///   - editorsStored: Returns when the editors that were left have stored what they showed; the store is read after.
    public init(
        browsing: any CVBrowsing, editing: any CVEditing, now: @escaping @MainActor () -> Date,
        editorsStored: @escaping @MainActor () async -> Void
    ) {
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

    /// A character no title holds, which marks where the number of a title is: the view words the number (R13).
    private static let untitledMark = "\u{1}"

    private func showRows() {
        let titles = listed.map { (id: $0.id.raw.uuidString, title: Self.title(of: $0)) }
        let labels = CVTitle.labels(
            for: titles, untitled: Self.untitledMark, numbered: { "\($0)\(Self.untitledMark)\($1)" }
        )
        rows = zip(listed, titles).map { cv, entry in
            let own = entry.title.text(untitled: Self.untitledMark)
            let number = labels[entry.id].flatMap { label -> Int? in
                label == own ? nil : Int(label.dropFirst(own.count).filter(\.isNumber))
            }
            let role = cv.personal.professionalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return CVRow(
                reference: CVReference(id: cv.id), title: RowTitle(entry.title), number: number,
                subtitle: { if case .role = entry.title { "" } else { role } }(),
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
        do {
            replace(try await editing.rename(cv, to: title))
            await changed(reference)
        } catch {
            await failed(error, on: reference)
        }
    }

    /// Adds a copy of the CV of the row, under the title the view gives (R13).
    public func duplicate(_ reference: CVReference, title: String) async {
        guard let cv = cv(of: reference) else { return }
        do {
            let copy = try await editing.duplicate(cv, title: title)
            listed.insert(copy, at: 0)
            showRows()
            await changed(reference)
        } catch {
            await failed(error, on: reference)
        }
    }

    /// Deletes the CV of the row at the revision the list read; a CV saved elsewhere since is a conflict, and stays.
    public func delete(_ reference: CVReference) async {
        guard let cv = cv(of: reference) else { return }
        do {
            try await editing.delete(cv)
            listed.removeAll { $0.id == cv.id }
            showRows()
            await changed(reference)
        } catch {
            await failed(error, on: reference)
        }
    }

    /// Sets the language the document of the row is written in, by its tag; nil leaves it automatic. A tag that names no
    /// language changes nothing.
    public func setDocumentLanguage(_ reference: CVReference, to tag: String?) async {
        let language = tag.flatMap(DocumentLanguage.init)
        guard let cv = cv(of: reference), tag == nil || language != nil else { return }
        do {
            replace(try await editing.autosaveWriter(startingFrom: cv).setDocumentLanguage(language, of: cv))
            await changed(reference)
        } catch is CancellationError {
            return
        } catch {
            await failed(error as? EditFailure ?? .unavailable, on: reference)
        }
    }

    private func cv(of reference: CVReference) -> CV? { listed.first { $0.id == reference.id } }

    private func replace(_ cv: CV) {
        guard let index = listed.firstIndex(where: { $0.id == cv.id }) else { return }
        listed[index] = cv
        showRows()
    }

    /// A change worked: the list is read again, as the store may hold more than this change.
    private func changed(_ reference: CVReference) async {
        rowStatuses[reference] = nil
        changedSinceLoad = true
        await load()
    }

    /// A change did not work. A cancelled task is no failure. What the list shows is out of date after a conflict or a CV
    /// that is gone.
    private func failed(_ failure: EditFailure, on reference: CVReference) async {
        guard !Task.isCancelled else { return }
        let rowStatus = RowStatus(failure)
        rowStatuses[reference] = rowStatus
        switch rowStatus {
        case .conflict, .gone: await load()
        case .tooLarge, .failed: break
        }
    }
}
