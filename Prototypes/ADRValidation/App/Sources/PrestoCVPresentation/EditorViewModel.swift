import Observation
import Foundation
internal import PrestoCVDomain          // no domain type may appear in this module's public API (R5)
internal import PrestoCVApplication
import PrestoCVWorkflowPorts

/// Presentation state only; the view turns statuses into text (R13).
public enum SaveStatus: Equatable, Sendable { case idle, saving, saved, needsName, conflict, deletedElsewhere, tooLarge, failed }
public enum ExportStatus: Equatable, Sendable { case idle, exporting, done(pages: Int), truncated(pages: Int, required: Int), unsupportedLanguage, incomplete, failed }

@Observable @MainActor
public final class EditorViewModel {
    public var fullName = ""                            // editor state; survives while a save is in flight
    public private(set) var saveStatus: SaveStatus = .idle
    public private(set) var exportStatus: ExportStatus = .idle
    public var isSaved: Bool { stored.revision > 0 }

    @ObservationIgnored private var stored: CV
    @ObservationIgnored private let editing: any CVEditing
    @ObservationIgnored private let exporting: any CVExporting
    @ObservationIgnored private var saveRequested = false
    @ObservationIgnored private var saveLoop: Task<Void, Never>?

    public init(editing: any CVEditing, exporting: any CVExporting) {
        self.editing = editing; self.exporting = exporting; stored = editing.newCV()
    }

    private var snapshot: CV { var cv = stored; cv.setPerson(fullName: fullName, email: cv.email); return cv }

    /// Saves are serialised and coalesced: a save requested while one runs becomes one more save with
    /// the latest edits, and every caller returns only once its edits are stored (or failed).
    public func save() async {
        saveRequested = true
        if let loop = saveLoop { await loop.value; return }
        let loop = Task { await runSaves() }
        saveLoop = loop
        await loop.value
    }

    /// The loop clears itself in the same main-actor turn as its last check, so a request that
    /// arrives later always starts a new loop instead of joining one that already finished.
    private func runSaves() async {
        defer { saveLoop = nil }
        while saveRequested {
            saveRequested = false
            saveStatus = .saving
            do { stored = try await editing.save(snapshot); saveStatus = .saved }
            catch .notEnoughContent { saveStatus = .needsName }
            catch .conflict { saveStatus = .conflict; saveRequested = false }
            catch .deletedElsewhere { saveStatus = .deletedElsewhere; saveRequested = false }
            catch .tooLarge { saveStatus = .tooLarge; saveRequested = false }
            catch { saveStatus = .failed; saveRequested = false }
        }
    }

    /// After a conflict: take the stored version (the user's unsaved name is discarded on purpose).
    public func reload() async {
        do { stored = try await editing.load(stored.id); fullName = stored.fullName; saveStatus = .idle }
        catch .deletedElsewhere { saveStatus = .deletedElsewhere } catch { saveStatus = .failed }
    }

    /// After a conflict or a deletion elsewhere: keep the edits as a new CV.
    public func saveAsCopy() async {
        var copy = editing.newCV()
        copy.setPerson(fullName: fullName, email: stored.email)
        stored = stored.duplicated(as: copy.id, title: stored.title)
        await save()
    }

    public func export(language: String) async {
        exportStatus = .exporting
        do {
            let outcome = try await exporting.export(snapshot, language: language)
            exportStatus = outcome.truncated ? .truncated(pages: outcome.pageCount, required: outcome.requiredPages) : .done(pages: outcome.pageCount)
        }
        catch is CancellationError { exportStatus = .idle }
        catch ExportFailure.unsupportedLanguage { exportStatus = .unsupportedLanguage }
        catch ExportFailure.incomplete { exportStatus = .incomplete }
        catch { exportStatus = .failed }
    }
}
