import Foundation
import Observation
internal import PrestoCVApplication
internal import PrestoCVDomain
import PrestoCVWorkflowPorts

/// The editor of one CV: the person's text, stored by itself a pause after the last change and at once when the editor is
/// left, and exported as it stands.
///
/// It presents; it decides nothing. What may be stored is the domain's verdict (`CV.saveCheck()`), when to write is the
/// `Autosave` of the application layer, and the store and the export are the ports it is given (ADR 0010).
@MainActor
@Observable
public final class EditorViewModel {

    /// The person's text. Every change goes to the store a pause later.
    public var content: EditorContent {
        get { form }
        set { edit(newValue) }
    }

    public private(set) var opening: OpeningStatus = .opening
    /// Nothing is open yet: the store is being read.
    public internal(set) var saveStatus: SaveStatus = .saving
    public internal(set) var exportStatus: ExportStatus = .idle

    /// "Saved on this device": the store holds what the form shows, and nothing waits.
    public var isSavedOnThisDevice: Bool { saveStatus == .saved }

    /// The tag of the language the document is written in, or nil when the CV says none.
    public var documentLanguage: String? { held?.language?.tag }

    /// The look the CV keeps, or nil when it keeps none yet.
    public var look: EditorLook? { held?.design.map(EditorLook.init) }

    // MARK: - State

    let start: EditorStart
    let editing: any CVEditing
    let exporting: any CVExporting
    let clock: any Clock<Duration>
    let pause: Duration
    let copyTitle: @MainActor (String) -> String

    /// The form as typed.
    var form = EditorContent.empty
    /// The CV the form stands on: its identity, the sections, and the look and the language it was opened with.
    var base: CV?
    /// The CV the writer gave back from the last change of the look or the language, nil when none was made since the form
    /// stood on `base`. Writes never carry its look and language: the writer keeps them.
    var restyled: CV?
    /// The CV the form stands on, with the look and the language chosen last: the one shown, exported and copied.
    var held: CV? { restyled ?? base }
    @ObservationIgnored var autosave: Autosave<CV>?
    /// The writer of the CV the form stands on, which keeps its revision.
    @ObservationIgnored var writer: (any CVAutosaveWriting)?
    /// The content last given to the autosave.
    @ObservationIgnored var given: CV?
    /// The failure of the last write or replacement, shown until a write succeeds.
    @ObservationIgnored var failure: SaveStatus?
    /// A reload or a copy, which replaces the CV the form stands on. Edits made meanwhile wait for it, and are written
    /// after it.
    @ObservationIgnored var replacing: Task<Void, Never>?
    /// Counts the autosaves, so that one replaced cannot change the status any more.
    @ObservationIgnored var generation = 0

    /// - Parameters:
    ///   - start: What to open. Nothing is read until `load()`.
    ///   - clock: The clock the pause is measured on.
    ///   - pause: How long after the last change the form is stored.
    ///   - copyTitle: The title of a copy of a CV with the given title, in the person's language (R13).
    public init(
        start: EditorStart, editing: any CVEditing, exporting: any CVExporting, clock: any Clock<Duration>,
        pause: Duration, copyTitle: @escaping @MainActor (String) -> String
    ) {
        self.start = start
        self.editing = editing
        self.exporting = exporting
        self.clock = clock
        self.pause = pause
        self.copyTitle = copyTitle
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
        form = EditorContent(cv)
        standOn(cv, unchangedFrom: unchanged, writer: editing.autosaveWriter(startingFrom: stored), isStored: stored != nil)
        opening = .open
    }

    // MARK: - Editing

    func edit(_ content: EditorContent) {
        form = content
        passOnTheForm()
        refreshSaveStatus()
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
        let autosave = Autosave<CV>(
            content: cv, unchangedFrom: unchanged, isStored: isStored, pause: pause,
            isWorthStoring: { $0.canBeSaved }, clock: self.clock,
            onWriteFailure: { [weak self] error in self?.writeFailed(error, generation: mine) },
            // Only the writer: a write that ends after the editor is gone still stores what it was given
            write: { content, _ in try await writer.write(content) }
        )
        autosave.onStatusChange = { [weak self] status in self?.autosaveChanged(to: status, generation: mine) }
        self.autosave = autosave
        self.writer = writer
        base = cv
        restyled = nil
        given = cv
        failure = nil
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

    func refreshSaveStatus() {
        let status = currentSaveStatus()
        if status != saveStatus { saveStatus = status }
    }

    private func currentSaveStatus() -> SaveStatus {
        if let failure { return failure }
        guard replacing == nil, let base, let autosave else { return .saving }
        if let field = form.unreadableFields.first { return .unreadable(field) }
        switch autosave.status {
        case .writing, .retrying:
            return .saving
        case .failed:
            return .failed
        case .pending, .upToDate:
            if autosave.isStored, autosave.storeHoldsTheContent { return .saved }
            return SaveStatus(waiting: form.applied(to: base).saveCheck())
        }
    }
}
