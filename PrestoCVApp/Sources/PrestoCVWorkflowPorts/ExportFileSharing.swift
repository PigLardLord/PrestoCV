import Foundation

/// The file written for one share of the export's PDF. The view model never asks the file system anything.
public struct SharedFile: Sendable, Hashable {
    /// Unique among the files an adapter wrote; the adapter chooses it.
    public let id: Int
    /// Where the file is, for the share sheet to read it.
    public let url: URL

    public init(id: Int, url: URL) {
        self.id = id
        self.url = url
    }
}

/// Writes the PDF of an export as a file for the system's share sheet, and removes it. The export sheet owns this port
/// (R3); its adapter is `ExportFileAdapter`, in `PrestoCVExportFiles`. Contents, layer and allowed imports:
/// docs/architecture/modules.md.
///
/// Each share has a file of its own, in a folder of its own, so two shares of one PDF never read or remove each other's
/// file.
public protocol ExportFileSharing: Sendable {
    /// Writes `pdf` as a file named `fileName`, in a folder of its own; throws when it cannot (R7). `fileName` is one
    /// name, not a path.
    func write(_ pdf: Data, named fileName: String) async throws -> SharedFile
    /// Removes the file and its folder. Called exactly once for each written file: when the share that reads it has
    /// ended, however it ended, or at once when no share will read it. A file that cannot be removed is logged, not
    /// thrown: the next launch clears what is left. It waits for the file system, so the sheet awaits it off the main
    /// actor (R19).
    func remove(_ file: SharedFile) async
}
