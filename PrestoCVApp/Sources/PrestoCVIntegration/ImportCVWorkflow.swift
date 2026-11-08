import Foundation
import PrestoCVApplication
import PrestoCVImporting
import PrestoCVWorkflowPorts

/// Reads a text or a PDF into an `ImportResult`. `ImportCV` is the real one; a test scripts its own.
public protocol CVTextImporting: Sendable {
    func importText(_ text: String) throws -> ImportResult
    func importPDF(_ data: Data) async throws -> ImportResult
}

extension ImportCV: CVTextImporting {}

/// Imports the CV a person already has: the text or the PDF is read by the import, and what it read becomes a new CV for
/// the person to review (ADR 0027). Nothing is stored: the CV has an id from the generator and revision 0, and saving it is the
/// caller's decision. A CV that cannot be saved, for its size, is returned all the same, since it is the person's text, with the reason in
/// `ImportOutcome.saving`: the CV's own `saveCheck()` verdict, such as `.cvTooLarge` or `.textTooLong(field)`.
/// Failures are `ImportFailure`; a cancelled task stays a `CancellationError` (R3, R7).
public struct ImportCVWorkflow: CVImporting {
    private let importer: any CVTextImporting
    private let ids: any IDGenerator
    private let mapper = ImportedCVMapper()

    public init(importer: any CVTextImporting, ids: any IDGenerator) {
        self.importer = importer; self.ids = ids
    }

    public func importCV(fromText text: String) async throws -> ImportOutcome {
        try await outcome { try importer.importText(text) }
    }

    /// The PDF is read with the layout of its words; what it gives goes the way of a text's result.
    public func importCV(fromPDF data: Data) async throws -> ImportOutcome {
        try await outcome { try await importer.importPDF(data) }
    }

    /// One way for both: the same errors and the same mapper, and an id only for a CV that was read.
    private func outcome(_ read: () async throws -> ImportResult) async throws -> ImportOutcome {
        let result: ImportResult
        do { result = try await read() } catch is CancellationError {
            throw CancellationError()                                  // ADR 0010: cancellation is not a failure
        } catch let error as ImportError {
            throw Self.failure(error)
        } catch { throw ImportFailure.unreadable }
        return mapper.map(result, id: ids.next())
    }

    private static func failure(_ error: ImportError) -> ImportFailure {
        switch error {
        case .empty: .empty
        case .tooLarge: .tooLarge
        case .tooManyPages: .tooManyPages
        case .encrypted: .encrypted
        case .unreadable: .unreadable
        case .noText: .noText
        }
    }
}
