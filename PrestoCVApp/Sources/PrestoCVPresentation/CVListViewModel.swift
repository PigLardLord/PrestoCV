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
    /// What the last change of a row did not do. A row is cleared by its next change, or when the person dismisses it. The
    /// status of a row that is no longer listed stays, so that the person is told, whatever removed the row.
    public private(set) var rowStatuses: [CVReference: RowStatus] = [:]
    /// The moment the view words "saved ... ago" from. It moves when the list is read or `refreshNow()` is called.
    public private(set) var now: Date

    /// The files the store could not read, until the person dismisses the notice (for this launch).
    public var notice: StoreNotice? { isNoticeDismissed || issues.isEmpty ? nil : StoreNotice(kinds: issues) }

    /// What shows in place of the rows: loading until the first read ends, the ways to start for a store with no CV.
    public var content: ListContent {
        guard rows.isEmpty else { return .rows }
        switch status {
        case .loading: return .loading
        case .loaded: return .empty
        case .failed: return .rows
        }
    }

    /// The notices above the rows: the store's state first, then the files it could not read, then one for each row whose
    /// last change did not work. Those are the listed rows in the list's order, by the label each shows now, and then the
    /// rows no longer listed (another action or a reload removed them), in the order the failures were found, by the label
    /// the row had when the change began. Each stays until the person dismisses it, whatever else fails or loads meanwhile.
    public var notices: [ListNotice] {
        var notices: [ListNotice] = []
        if status == .failed { notices.append(isStale ? .stale : .failed) }
        if let notice { notices.append(.unreadable(notice)) }
        notices += rowFailures.map(ListNotice.rowFailure)
        return notices
    }

    /// Every action of a row, in the order the menu offers them.
    public let rowActions: [RowAction] = [.duplicate, .rename, .delete]
    /// The swipe from the leading edge.
    public let leadingSwipeActions: [RowAction] = [.duplicate]
    /// The swipe from the trailing edge.
    public let trailingSwipeActions: [RowAction] = [.delete]

    private var issues: [StoreIssueKind] = []
    private var isNoticeDismissed = false
    /// The latest failure of each row, in the order they were found, with the label the row had. A failure of a row that is
    /// no longer listed is told from here.
    private var failedAlerts: [RowFailure] = []
    /// Numbers each failure recorded, so that a dismissal removes the failure it showed and not a newer one of the same row.
    private var failuresRecorded = 0
    /// The number of the latest failure of each row that has a status; it goes with the status.
    private var latestFailure: [CVReference: Int] = [:]

    @ObservationIgnored private let browsing: any CVBrowsing
    @ObservationIgnored private let editing: any CVEditing
    @ObservationIgnored private let untitled: String
    @ObservationIgnored private let barUntitled: String
    @ObservationIgnored private let barNewCV: String
    @ObservationIgnored private let numbered: @MainActor (String, Int) -> String
    @ObservationIgnored private let clock: @MainActor () -> Date
    @ObservationIgnored private let editorsStored: @MainActor () async -> Void
    /// The CVs as the store listed them. A change reads its CV here, when the intent comes.
    @ObservationIgnored private var listed: [CV] = []
    /// The label each listed CV shows in the editor's bar: the list's numbering with the bar's word for no title.
    @ObservationIgnored private var barLabels: [CVID: String] = [:]
    @ObservationIgnored private var generation = 0
    /// The reads that passed the wait for the editors and have not ended.
    @ObservationIgnored private var running = 0
    /// What the last published read or failure set; `.loading` before any read ends.
    @ObservationIgnored private var settled: ListStatus = .loading
    @ObservationIgnored private var changedSinceLoad = false
    /// The latest change taken on each row. A change publishes its status and its result only while it is the latest.
    @ObservationIgnored private var intents: [CVReference: Int] = [:]
    /// The label each row showed when its latest change began, until that change ends. A failure of the latest change names
    /// the row by it when the row is no longer listed.
    @ObservationIgnored private var labels: [CVReference: String] = [:]

    /// - Parameters:
    ///   - untitled: The view's words for a CV with no title, as "Untitled CV" (R13).
    ///   - numbered: How the view numbers a title that reads like another row's, as "Backend (2)" (R13).
    ///   - barUntitled: The view's words for a CV with no title in the editor's bar, which is narrower than the list (R13).
    ///   - barNewCV: The view's words for a CV not stored yet in the editor's bar (R13).
    ///   - now: The time the view words "saved ... ago" from.
    ///   - editorsStored: Returns when every open editor has stored what it showed at its turn; the store is read after.
    public init(
        browsing: any CVBrowsing, editing: any CVEditing, untitled: String,
        barUntitled: String, barNewCV: String,
        numbered: @escaping @MainActor (String, Int) -> String, now: @escaping @MainActor () -> Date,
        editorsStored: @escaping @MainActor () async -> Void
    ) {
        self.untitled = untitled
        self.barUntitled = barUntitled
        self.barNewCV = barNewCV
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
        // Taken before the wait: a change of the list made while the editors store invalidates this read, and so does a newer read
        generation += 1
        let mine = generation
        await editorsStored()
        guard mine == generation else { return }
        running += 1
        if rows.isEmpty { status = .loading }
        // `.loading` holds only while a read runs: when the last one ends without a status of its own, the settled one shows
        defer {
            running -= 1
            if running == 0, status == .loading { status = settled }
        }
        do {
            let listing = try await browsing.list()
            guard mine == generation else { return }
            show(listing)
        } catch {
            guard mine == generation, !Task.isCancelled else { return }
            settled = .failed
            status = .failed
            isStale = changedSinceLoad
        }
    }

    public func refreshNow() { now = clock() }

    /// The title the editor's bar shows for what the detail holds: the open CV's own words, numbered as the list numbers
    /// them but with the bar's word for a CV with no title; the bar's word for a CV not stored yet. `editorTitle` stands in
    /// when the open CV is not listed.
    public func barTitle(of detail: EditorStart?, selected: CVReference?, editorTitle: String) -> String {
        switch detail {
        case .stored?:
            selected.flatMap { barLabels[$0.id] } ?? editorTitle
        case .draft?, .blank?, nil:
            barNewCV
        }
    }

    public func dismissNotice() { isNoticeDismissed = true }

    /// The person dismissed a notice of a row's failure. It removes that failure only: a newer failure of the same row has
    /// another number, and stays.
    public func dismissRowFailure(_ failure: RowFailure) {
        guard latestFailure[failure.reference] == failure.number else { return }
        rowStatuses[failure.reference] = nil
        failedAlerts.removeAll { $0.reference == failure.reference }
        latestFailure[failure.reference] = nil
    }

    /// The failures to tell, in the order of `notices`.
    private var rowFailures: [RowFailure] {
        let listed = rows.compactMap { row in
            failure(of: row.reference, labelled: row.label)
        }
        let listedReferences = Set(rows.map(\.reference))
        let removed = failedAlerts.compactMap { found in
            listedReferences.contains(found.reference) ? nil : failure(of: found.reference, labelled: found.label)
        }
        return listed + removed
    }

    private func failure(of reference: CVReference, labelled label: String) -> RowFailure? {
        guard let status = rowStatuses[reference], let number = latestFailure[reference] else { return nil }
        return RowFailure(reference: reference, label: label, status: status, number: number)
    }

    private func show(_ listing: CVListing) {
        listed = listing.cvs
        issues = listing.issues.map(StoreIssueKind.init)
        showRows()
        let kept = Set(rows.map(\.reference)).union(failedAlerts.map(\.reference))
        rowStatuses = rowStatuses.filter { kept.contains($0.key) }
        latestFailure = latestFailure.filter { rowStatuses[$0.key] != nil }
        settled = .loaded
        status = .loaded
        isStale = false
        changedSinceLoad = false
        now = clock()
    }

    // MARK: - Rows

    private func showRows() {
        let labels = Self.labels(of: listed, untitled: untitled, numbered: numbered)
        barLabels = Self.labels(of: listed, untitled: barUntitled, numbered: numbered)
        rows = listed.map { cv in
            CVRow(
                reference: CVReference(id: cv.id), label: labels[cv.id] ?? untitled, title: cv.title,
                subtitle: CVSubtitle.text(name: cv.title, person: cv.personal.fullName, role: cv.personal.professionalTitle) ?? "",
                lastSaved: cv.updatedAt ?? cv.createdAt, language: cv.language?.tag
            )
        }
    }

    /// The label each CV of a listing shows in the list: no two alike (the domain's `CVTitle.labels`). The import report
    /// names the CVs with it too.
    static func labels(of cvs: [CV], untitled: String, numbered: @MainActor (String, Int) -> String) -> [CVID: String] {
        let titles = cvs.map { cv in
            (id: cv.id.raw.uuidString, title: CVTitle(name: cv.title, person: cv.personal.fullName, role: cv.personal.professionalTitle))
        }
        let labels = CVTitle.labels(for: titles, untitled: untitled, numbered: numbered)
        return Dictionary(cvs.map { ($0.id, labels[$0.id.raw.uuidString] ?? untitled) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: - Kept editors

    /// The notices of the editors the shell kept (#402, decisions 16 and 17). The editor of a listed CV shows under its
    /// row, named by the row's label; when a row has more than one, the one left last shows there and the others above the
    /// rows, so that none is hidden. A draft and a CV the list does not have show above the rows, named by the title their
    /// own text gives them. The notices above follow the order the editors were left in.
    public func keptNotices(_ kept: [KeptEditor]) -> KeptNotices {
        let labels = Dictionary(rows.map { ($0.reference, $0.label) }, uniquingKeysWith: { first, _ in first })
        var notices = KeptNotices(above: [], under: [:])
        for editor in kept.sorted(by: { $0.id < $1.id }) {
            let row = editor.reference.flatMap { reference in labels[reference].map { (reference: reference, label: $0) } }
            let notice = KeptNotice(
                id: editor.id, label: row?.label ?? editor.title.text(untitled: untitled), status: editor.status,
                canRetry: editor.canRetry
            )
            guard let row else {
                notices.above.append(notice)
                continue
            }
            if let earlier = notices.under.updateValue(notice, forKey: row.reference) { notices.above.append(earlier) }
        }
        notices.above.sort { $0.id < $1.id }
        return notices
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
            listChanged()
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
            await deleted(cv, reference, intent)
        } catch .deletedElsewhere {
            // Gone already is what the person asked for
            await deleted(cv, reference, intent)
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
            ended(reference, intent)
            return
        } catch {
            await failed(error as? EditFailure ?? .unavailable, on: reference, intent)
        }
    }

    private func deleted(_ cv: CV, _ reference: CVReference, _ intent: Int) async {
        listed.removeAll { $0.id == cv.id }
        listChanged()
        await changed(reference, intent)
    }

    private func begin(_ reference: CVReference) -> Int {
        let intent = (intents[reference] ?? 0) + 1
        intents[reference] = intent
        labels[reference] = rows.first { $0.reference == reference }?.label ?? untitled
        return intent
    }

    /// A change ended without leaving a status: its remembered label is no longer needed, unless a newer change took over.
    private func ended(_ reference: CVReference, _ intent: Int) {
        if isLatest(intent, on: reference) { labels[reference] = nil }
    }

    private func isLatest(_ intent: Int, on reference: CVReference) -> Bool { intents[reference] == intent }

    private func cv(of reference: CVReference) -> CV? { listed.first { $0.id == reference.id } }

    private func replace(_ cv: CV) {
        guard let index = listed.firstIndex(where: { $0.id == cv.id }) else { return }
        listed[index] = cv
        listChanged()
    }

    /// `listed` changed here: a read that started before holds an older list, and must not publish over this one.
    private func listChanged() {
        generation += 1
        showRows()
    }

    /// A change worked: the list is read again, as the store may hold more than this change. The row's status is cleared
    /// only if no newer change of the row was taken.
    private func changed(_ reference: CVReference, _ intent: Int) async {
        if isLatest(intent, on: reference) {
            rowStatuses[reference] = nil
            latestFailure[reference] = nil
            failedAlerts.removeAll { $0.reference == reference }
        }
        ended(reference, intent)
        changedSinceLoad = true
        await load()
    }

    /// A change did not work. A cancelled task is no failure. What the list shows is out of date after a conflict or a CV
    /// that is gone, so it is read again; the row shows the failure only if no newer change of the row was taken. The notice
    /// names the row by the label it shows now, else by the one it had when the change began: another action or a reload
    /// may have removed the row meanwhile.
    private func failed(_ failure: EditFailure, on reference: CVReference, _ intent: Int) async {
        guard !Task.isCancelled else { return ended(reference, intent) }
        let rowStatus = RowStatus(failure)
        if isLatest(intent, on: reference) {
            rowStatuses[reference] = rowStatus
            failuresRecorded += 1
            latestFailure[reference] = failuresRecorded
            let label = rows.first { $0.reference == reference }?.label ?? labels[reference] ?? untitled
            failedAlerts.removeAll { $0.reference == reference }
            failedAlerts.append(RowFailure(reference: reference, label: label, status: rowStatus, number: failuresRecorded))
        }
        ended(reference, intent)
        switch rowStatus {
        case .conflict, .gone: await load()
        case .tooLarge, .failed: break
        }
    }
}
