import Foundation
internal import PrestoCVDomain
import PrestoCVWorkflowPorts

extension EditorViewModel {

    /// Exports the form as it stands, stored or not, in the CV's document language. It leaves the save status and the
    /// store alone.
    /// - Returns: The PDF, or nil when `exportStatus` says why there is none.
    public func export() async -> ExportedDocument? {
        guard let held else { return nil }
        let snapshot = form.applied(to: held)
        guard let language = snapshot.language else {
            exportStatus = .languageNeeded
            return nil
        }
        exportStatus = .exporting
        do {
            let outcome = try await exporting.export(snapshot, language: language)
            exportStatus = outcome.truncated
                ? .truncated(pages: outcome.pageCount, required: outcome.requiredPages)
                : .done(pages: outcome.pageCount)
            return ExportedDocument(pdf: outcome.pdf, pages: outcome.pageCount)
        } catch let failure as ExportFailure {
            exportStatus = ExportStatus(failure)
        } catch is CancellationError {
            exportStatus = .idle
        } catch {
            exportStatus = .failed
        }
        return nil
    }
}
