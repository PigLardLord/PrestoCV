import Foundation
import PrestoCVDomain
import PrestoCVApplication

// Ports consumed by presentation (R3), separate from their implementations in PrestoCVIntegration.

public protocol CVEditing: Sendable {
    func newCV() -> CV
    func save(_ cv: CV) async throws(AuthoringError) -> CV
    func load(_ id: CVID) async throws(AuthoringError) -> CV
}

public struct ExportOutcome: Sendable, Equatable {
    public let pdf: Data, pageCount: Int, requiredPages: Int
    public var truncated: Bool { requiredPages > pageCount }
    public init(pdf: Data, pageCount: Int, requiredPages: Int) { self.pdf = pdf; self.pageCount = pageCount; self.requiredPages = requiredPages }
}

public enum ExportFailure: Error, Equatable, Sendable { case unsupportedLanguage, incomplete(missing: Int), renderingFailed }

/// Preview and export take the editor's current snapshot, saved or not; they never reload storage.
/// Untyped `throws`, so that `CancellationError` passes through unchanged (R7).
public protocol CVExporting: Sendable {
    func export(_ snapshot: CV, language: String) async throws -> ExportOutcome
}
