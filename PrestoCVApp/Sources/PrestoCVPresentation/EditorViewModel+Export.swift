import Foundation
internal import PrestoCVDomain
import PrestoCVWorkflowPorts

extension EditorViewModel {

    /// Exports the form as it stands, stored or not, in the CV's document language. It leaves the save status and the
    /// store alone.
    /// - Returns: The PDF, or nil when `exportStatus` says why there is none.
    public func export() async -> ExportedDocument? {
        guard let held else { return nil }
        exportGeneration += 1
        let mine = exportGeneration
        let snapshot = form.applied(to: held)
        guard let language = snapshot.language else {
            exportStatus = .languageNeeded
            return nil
        }
        exportStatus = .exporting
        let status: ExportStatus
        var document: ExportedDocument?
        do {
            let outcome = try await exporting.export(snapshot, language: language)
            status = outcome.truncated
                ? .truncated(pages: outcome.pageCount, required: outcome.requiredPages)
                : .done(pages: outcome.pageCount)
            document = ExportedDocument(pdf: outcome.pdf, pages: outcome.pageCount)
        } catch let failure as ExportFailure {
            status = ExportStatus(failure)
        } catch is CancellationError {
            status = .idle
        } catch {
            status = .failed
        }
        // A request superseded meanwhile returns its result and leaves the status to the newer one
        if mine == exportGeneration { exportStatus = status }
        return document
    }
}
