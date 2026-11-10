import Foundation
import Observation
internal import PrestoCVApplication
internal import PrestoCVDomain
import PrestoCVWorkflowPorts

/// The editor of one CV: the person's text, stored by itself a pause after the last change and at once when the editor is
/// left, and given as it stands to the export sheet.
///
/// It presents; it decides nothing. What may be stored is the domain's verdict (`CV.saveCheck()`), when to write is the
/// `Autosave` of the application layer, and the store is the port it is given (ADR 0010).
@MainActor
@Observable
public final class EditorViewModel {

    /// The person's text. Every change goes to the store a pause later.
    public var content: EditorContent {
        get { form }
        set { edit(newValue) }
    }

    /// The row the person asked to remove, which waits for `confirmRemoval()` or `cancelRemoval()`.
    public internal(set) var pendingRemoval: RowRemoval?
    /// The row just added, which the view focuses and scrolls into view, then reports with `rowWasShown()`.
    public internal(set) var addedRow: RowID?

    public private(set) var opening: OpeningStatus = .opening
    /// Nothing is open yet: the store is being read.
    public internal(set) var saveStatus: SaveStatus = .saving

    /// The status the person is told of as it changes (VoiceOver), in words the view picks from the code: nil until the
    /// status settles somewhere other than where it stood when the CV opened. Typing and the autosave's writes
    /// (`pending`, `saving`) settle nowhere, so a save that went well tells nothing; a problem, a failure, and the save
    /// after one or the first save of a new CV, each change it.
    public private(set) var statusChange: SaveStatus?

    /// The problems the person has just met that the status does not tell: nil until one is. The status names only the
    /// first problem, so this holds every other one met at the same moment (a store attempt meets every problem at once),
    /// and one met while the status names another or the same status holds. Each problem met is told once, by one of them.
    public internal(set) var problemNotice: ProblemNotice?

    /// "Saved on this device": the store holds what the form shows, and nothing waits.
    public var isSavedOnThisDevice: Bool { saveStatus == .saved }

    /// The tag of the language the document is written in, or nil when the CV says none.
    public var documentLanguage: String? { held?.language?.tag }

    /// The look the CV keeps, or nil when it keeps none yet.
    public var look: EditorLook? { held?.design.map(EditorLook.init) }

    // MARK: - State

    let start: EditorStart
    let editing: any CVEditing
    let clock: any Clock<Duration>
    let pause: Duration
    let copyTitle: @MainActor (String) -> String
    let didStore: @MainActor () -> Void

    /// The form as typed.
    var form = EditorContent.empty {
        didSet { forgetProblemsThatRead() }
    }
    /// The problems the person has met (`problems`), kept until their text reads.
    var metProblems = Set<FieldProblem>()
    /// The ids of the form's rows: every row this editor made has one no other row has had.
    @ObservationIgnored var rowIDs = RowIDs()
    /// The CV the form stands on: its identity, the sections, and the look and the language it was opened with.
    var base: CV?
    /// The CV the writer gave back from the last change of the look or the language, nil when none was made since the form
    /// stood on `base`. Writes never carry its look and language: the writer keeps them.
    var restyled: CV?
    /// The CV the form stands on, with the look and the language chosen last: the one shown, exported and copied.
    var held: CV? { restyled ?? base }
    /// The CV this editor stores, nil while the store holds none of it: a draft has one after its first write, and after a
    /// copy is saved the copy is the CV it stores.
    var storedReference: CVReference? {
        guard let base, autosave?.isStored == true else { return nil }
        return CVReference(id: base.id)
    }
    @ObservationIgnored var autosave: Autosave<CV>?
    /// The writer of the CV the form stands on, which keeps its revision.
    @ObservationIgnored var writer: (any CVAutosaveWriting)?
    /// The content last given to the autosave.
    @ObservationIgnored var given: CV?
    /// The failure of the last write or of a reload or a copy, shown until a write succeeds.
    @ObservationIgnored var failure: SaveStatus?
    /// The failure of the last change of the look or the language, shown until a change succeeds. A write that succeeds
    /// does not clear it, and it never hides `failure`: a change that succeeds clears only this one.
    @ObservationIgnored var changeFailure: SaveStatus?
    /// A reload or a copy, which replaces the CV the form stands on. Edits made meanwhile wait for it, and are written
    /// after it.
    @ObservationIgnored var replacing: Task<Void, Never>?
    /// Counts the autosaves, so that one replaced cannot change the status any more.
    @ObservationIgnored var generation = 0
    /// The writes of the autosave the form stands on.
    @ObservationIgnored var writes = WritesInFlight()
    /// Counts the edits that changed the form, so that a replacement can tell whether the person typed meanwhile, even
    /// if the text is back to what it was.
    @ObservationIgnored var formEdits = 0
    /// Counts the edits that changed the title, for the same purpose.
    @ObservationIgnored var titleEdits = 0
    /// Where the status last settled (`statusChange`), nil until the CV opened.
    @ObservationIgnored var settled: SaveStatus?

    /// - Parameters:
    ///   - start: What to open. Nothing is read until `load()`.
    ///   - clock: The clock the pause is measured on.
    ///   - pause: How long after the last change the form is stored.
    ///   - copyTitle: The title of a copy of a CV with the given title, in the person's language (R13).
    ///   - didStore: Called after each write the store took, never for one that failed, so that what shows the stored
    ///     CVs can read them again. It is called even when the editor is gone by then.
    public init(
        start: EditorStart, editing: any CVEditing, clock: any Clock<Duration>,
        pause: Duration, copyTitle: @escaping @MainActor (String) -> String, didStore: @escaping @MainActor () -> Void
    ) {
        self.start = start
        self.editing = editing
        self.clock = clock
        self.pause = pause
        self.copyTitle = copyTitle
        self.didStore = didStore
    }

    /// Opens the CV. The view calls it from its `.task`; once the CV is open, it does nothing.
    public func load() async {
        guard autosave == nil else { return }
        opening = .opening
        switch start {
        case .stored(let reference):
            do {
                let stored = try await editing.load(reference.id)
                open(stored, unchangedFrom: stored, stored: stored)
            } catch {
                if autosave == nil { opening = OpeningStatus(error) }
            }
        case .blank:
            let blank = editing.new()
            open(blank, unchangedFrom: blank, stored: nil)
        case .draft(let draft):
            open(draft.cv, unchangedFrom: nil, stored: nil)
        }
    }

    private func open(_ cv: CV, unchangedFrom unchanged: CV?, stored: CV?) {
        guard autosave == nil else { return }
        form = admit(EditorContent(cv, ids: &rowIDs))
        pendingRemoval = nil
        standOn(cv, unchangedFrom: unchanged, writer: editing.autosaveWriter(startingFrom: stored), isStored: stored != nil)
        opening = .open
    }

    // MARK: - Editing

    func edit(_ content: EditorContent) {
        let admitted = admit(content)
        if admitted != form { formEdits += 1 }
        if admitted.title != form.title { titleEdits += 1 }
        form = admitted
        passOnTheForm()
        refreshSaveStatus()
    }

    /// `content` with unique row ids, the one place every entry of rows into the form passes through. The row waiting for its
    /// removal is named by its id: if that id arrives on more than one row, or on none, the rows cannot be told apart, so the
    /// request is withdrawn and nothing is removed.
    func admit(_ content: EditorContent) -> EditorContent {
        if let request = pendingRemoval, content.rowCount(withID: request.row) != 1 { pendingRemoval = nil }
        return rowIDs.unique(content)
    }

    /// Gives the autosave the CV the form shows, unless a replacement runs: it is given once that ends.
    func passOnTheForm() {
        guard replacing == nil, let base, let autosave else { return }
        let current = form.applied(to: base)
        guard current != given else { return }
        given = current
        autosave.changed(to: current)
    }

    /// The form stands on `cv` from now on, with an autosave of its own: what the one before did can change nothing.
    func standOn(_ cv: CV, unchangedFrom unchanged: CV?, writer: any CVAutosaveWriting, isStored: Bool) {
        generation += 1
        let mine = generation
        writes.replace()
        let mineWrites = WritesInFlight()
        let didStore = self.didStore
        let autosave = Autosave<CV>(
            content: cv, unchangedFrom: unchanged, isStored: isStored, pause: pause,
            isWorthStoring: { $0.canBeSaved }, clock: self.clock,
            onWriteFailure: { [weak self] error in self?.writeFailed(error, generation: mine) },
            // Only the writer and the callback: a write that ends after the editor is gone still stores what it was given,
            // and still tells it
            write: { content, _ in
                try await mineWrites.run { try await writer.write(content) }
                didStore()
            }
        )
        autosave.onStatusChange = { [weak self] status in self?.autosaveChanged(to: status, generation: mine) }
        self.autosave = autosave
        self.writer = writer
        self.writes = mineWrites
        base = cv
        restyled = nil
        given = cv
        failure = nil
        changeFailure = nil
        refreshSaveStatus()
    }

    // MARK: - Status

    private func writeFailed(_ error: any Error, generation: Int) {
        guard generation == self.generation else { return }
        failure = (error as? EditFailure).map { SaveStatus($0) } ?? .failed
        refreshSaveStatus()
    }

    private func autosaveChanged(to status: Autosave<CV>.Status, generation: Int) {
        guard generation == self.generation else { return }
        if !status.hasUnresolvedFailure { failure = nil }
        refreshSaveStatus()
    }

    /// Brings the status up to date. Returns whether it set `statusChange`.
    @discardableResult
    func refreshSaveStatus() -> Bool {
        let status = currentSaveStatus()
        if status != saveStatus { saveStatus = status }
        guard status != .pending, status != .saving, status != settled else { return false }
        let told = settled != nil
        if told { statusChange = status }
        settled = status
        return told
    }

    private func currentSaveStatus() -> SaveStatus {
        if let failure { return failure }
        if let changeFailure { return changeFailure }
        guard replacing == nil, let base, let autosave else { return .saving }
        if let problem = problems.first { return .unreadable(problem.field) }
        switch autosave.status {
        case .writing, .retrying:
            return .saving
        case .failed:
            return .failed
        case .pending, .upToDate:
            // Text the person is still typing that cannot be read yet is not stored: it waits for them
            if autosave.isStored, autosave.storeHoldsTheContent { return form.unreadable.isEmpty ? .saved : .pending }
            return SaveStatus(waiting: form.applied(to: base).saveCheck())
        }
    }
}
