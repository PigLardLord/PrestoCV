import Observation
internal import PrestoCVApplication
internal import PrestoCVDomain
import PrestoCVWorkflowPorts

public enum LookStatus: Hashable, Sendable {
    case loading
    /// The picker shows the look; nothing is waiting.
    case ready
    case applying
    /// The change is stored.
    case applied
    /// The CV is not in the store any more.
    case missing
    /// Someone saved the CV elsewhere since the picker read it; nothing was overwritten.
    case conflict
    case failed
}

/// The look picker of a CV: the design, palette and fonts it offers and the look the CV holds. A choice marks its part as
/// chosen; the choices made before the person applies them go to the writer of the CV as one change.
@MainActor
@Observable
public final class LookViewModel {

    public let choices: LookChoices
    /// The look the picker shows: the CV's, with the choices made, or the defaults for a CV that keeps none. An id the app
    /// does not know stays as the CV holds it until a choice replaces it.
    public private(set) var shown: EditorLook
    /// The parts the person chose and has not applied.
    public private(set) var chosen: Set<LookPart> = []
    public private(set) var status: LookStatus = .loading

    @ObservationIgnored private let reference: CVReference
    @ObservationIgnored private let editing: any CVEditing
    @ObservationIgnored private var stored: CV?
    @ObservationIgnored private var writer: (any CVAutosaveWriting)?
    /// The change being written, and the choices made while it is written. `pending` is both, in order.
    @ObservationIgnored private var submitted: LookChange?
    @ObservationIgnored private var unsent: LookChange?
    @ObservationIgnored private var loadGeneration = 0

    private var pending: LookChange? { submitted.map { first in unsent.map { first.followed(by: $0) } ?? first } ?? unsent }

    public init(reference: CVReference, editing: any CVEditing, options: any LookOptionsProviding) {
        let options = options.options()
        self.reference = reference
        self.editing = editing
        choices = LookChoices(options)
        shown = EditorLook(design: options.defaultDesign, palette: options.defaultPalette, fonts: options.defaultFonts)
    }

    /// Reads the CV. The view calls it from its `.task`. Only the latest read publishes; the choices made meanwhile stay on
    /// top of the look it read.
    public func load() async {
        loadGeneration += 1
        let mine = loadGeneration
        do {
            let cv = try await editing.load(reference.id)
            guard mine == loadGeneration else { return }
            stored = cv
            writer = editing.autosaveWriter(startingFrom: cv)
            show(over: cv.design)
            if status != .applying { status = .ready }
        } catch {
            guard mine == loadGeneration, !Task.isCancelled else { return }
            status = LookStatus(error)
        }
    }

    public func choose(design: String) { choose(.design, EditorLook(design: design, palette: shown.palette, fonts: shown.fonts)) }

    public func choose(palette: String?) { choose(.palette, EditorLook(design: shown.design, palette: palette, fonts: shown.fonts)) }

    public func choose(fonts: String?) { choose(.fonts, EditorLook(design: shown.design, palette: shown.palette, fonts: fonts)) }

    /// Sends the choices made so far as one change. The CV's text is not written by it. The choices made while it is written
    /// stay pending on top of the look it stored; if it fails, nothing the person chose is lost.
    public func apply() async {
        guard let writer, let stored, let change = pending, status != .applying else { return }
        submitted = change
        unsent = nil
        status = .applying
        do {
            let changed = try await writer.changeLook(change, of: stored)
            self.stored = changed
            submitted = nil
            show(over: changed.design)
            chosen = Set(unsent?.parts.map(LookPart.init) ?? [])
            status = unsent == nil ? .applied : .ready
        } catch {
            status = Task.isCancelled || error is CancellationError ? .ready : (error as? EditFailure).map(LookStatus.init) ?? .failed
        }
    }

    /// The look of the CV with the pending choices on top, or the defaults for a CV that keeps none.
    private func show(over design: DesignChoice?) {
        if let pending {
            shown = EditorLook(pending.applying(to: design))
        } else if let design {
            shown = EditorLook(design)
        }
    }

    private func choose(_ part: LookPart, _ look: EditorLook) {
        guard let step = LookChange(shown: look, parts: [part]) else { return }
        unsent = unsent.map { $0.followed(by: step) } ?? step
        guard let change = pending else { return }
        shown = EditorLook(change.shown)
        chosen = Set(change.parts.map(LookPart.init))
        if status == .applied { status = .ready }
    }
}

extension LookStatus {
    /// Why a CV could not be read or changed. Every failure of the store has its status (R7).
    init(_ failure: EditFailure) {
        switch failure {
        case .deletedElsewhere: self = .missing
        case .conflict: self = .conflict
        case .tooLarge, .notEnoughContent, .textTooLong, .tooManyEntries, .cvTooLarge, .unavailable: self = .failed
        }
    }
}

extension LookPart {
    init(_ part: LookChange.Part) {
        switch part {
        case .design: self = .design
        case .palette: self = .palette
        case .fonts: self = .fonts
        }
    }
}
