import Foundation
import PrestoCVDomain

// PrestoCVWorkflowPorts: the workflow ports the presentation layer depends on (#88)
// Contents, layer and allowed imports: docs/architecture/modules.md.

/// What a finished export holds. The PDF may be shorter than the CV needs: `truncated` says so, with both page counts.
public struct ExportOutcome: Sendable, Equatable {
    public let pdf: Data
    public let pageCount: Int
    public let requiredPages: Int
    public var truncated: Bool { requiredPages > pageCount }
    public init(pdf: Data, pageCount: Int, requiredPages: Int) {
        self.pdf = pdf; self.pageCount = pageCount; self.requiredPages = requiredPages
    }
}

public enum ExportFailure: Error, Equatable, Sendable {
    /// No heading table for the document language: the export never falls back to another language (R13).
    case unsupportedLanguage
    /// The CV lacks what `ExportReadiness` requires, the person's name.
    case notReady
    /// The CV maps to a document the exporter's validation refuses (a text too long, a control character).
    case invalidDocument
    /// The PDF lacks `missing` of the document's texts.
    case incomplete(missing: Int)
    /// The headings could not be read, or the PDF could not be read back.
    case renderingFailed
}

/// Preview and export take the editor's current snapshot, saved or not; they never reload storage.
/// Untyped `throws`, so that `CancellationError` passes through unchanged (R3, R7).
public protocol CVExporting: Sendable {
    func export(_ snapshot: CV, language: DocumentLanguage) async throws -> ExportOutcome
}
