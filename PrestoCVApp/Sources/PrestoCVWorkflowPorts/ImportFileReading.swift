import Foundation

/// One URL handed to the import screen, as the adapter captured it when it came. Two received files may be the same
/// file: the adapter counts them and lets the file go when the last one of that file is released. The view model never
/// asks the file system anything.
public struct ReceivedFile: Sendable, Hashable {
    /// Unique among the files an adapter received; the adapter chooses it.
    public let id: Int
    /// The URL as it was handed over.
    public let url: URL

    public init(id: Int, url: URL) {
        self.id = id
        self.url = url
    }
}

/// Reads the PDF of a file the person chose, and lets the file go. The import screen owns this port (R3); its adapter
/// is `ImportFileAdapter`, in `PrestoCVImportFiles`. Contents, layer and allowed imports: docs/architecture/modules.md.
///
/// Each received file has its own start and its own stop, as security-scoped access has: `receive` starts, `release`
/// stops, once for each file.
public protocol ImportFileReading: Sendable {
    /// Called once for each URL handed to the screen, synchronously and before anything else. The adapter captures here,
    /// once, whatever identity of the file it needs.
    func receive(_ url: URL) -> ReceivedFile
    /// The bytes of the PDF of `file`, read within the size bound of the import. It does not let the file go: `release`
    /// does. A file above the bound throws `ImportFailure.tooLarge`, one that cannot be read `ImportFailure.fileNotRead`;
    /// a cancelled task stays a `CancellationError` (R3, R7).
    func readPDF(of file: ReceivedFile) async throws -> Data
    /// Called exactly once for each received file: after the import that reads it has ended, however it ended (success,
    /// failure, cancel, the screen gone), or at once when the screen does not read it (a second file while an import
    /// runs). Nothing of the file is kept (ADR 0027).
    func release(_ file: ReceivedFile)
}
