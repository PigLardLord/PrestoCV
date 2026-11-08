import Foundation

/// Reads the PDF of a file the person chose, and lets the file go. The import screen owns this port (R3); its adapter
/// belongs to the composition. Contents, layer and allowed imports: docs/architecture/modules.md.
public protocol ImportFileReading: Sendable {
    /// The bytes of the PDF at `url`, read within the size bound of the import. It does not let the file go: `release`
    /// does. A file above the bound throws `ImportFailure.tooLarge`, one that cannot be read `ImportFailure.fileNotRead`;
    /// a cancelled task stays a `CancellationError` (R3, R7).
    func readPDF(fromFileAt url: URL) async throws -> Data
    /// Lets the file go, whether it was read or not: nothing of it is kept (ADR 0027). Called once for each file the
    /// person handed over.
    func release(_ url: URL)
}
